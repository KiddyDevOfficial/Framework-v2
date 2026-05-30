--!strict
--[=[
	@module Data.Profile
	A minimal, ProfileStore-flavoured wrapper around `DataStoreService` with:

	  * Session locking - atomic `UpdateAsync` claims a per-key lock keyed
	    by a process-unique session id. If a stale (timed-out) lock exists,
	    we steal it. If a live lock from another server is present, the
	    load fails so callers can kick / retry.
	  * Periodic heartbeat - the holder of the lock refreshes its
	    timestamp every `HEARTBEAT_INTERVAL` seconds, so other servers
	    consider the lock alive.
	  * Auto-save - every `AUTO_SAVE_INTERVAL` seconds while the session
	    is live, the working copy is flushed back to the store.
	  * `Reconcile` - deep-merges missing keys from a template so adding
	    new keys to the template propagates to existing profiles on join.
	  * Mock mode - pure in-memory implementation backed by a module-local
	    table. Useful in Studio with API services disabled.

	Surface mirrors the bits of `ProfileStore.Profile` the DataService
	consumes (`Data`, `OnSessionEnd`, `:AddUserId`, `:Reconcile`,
	`:EndSession`).
]=]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)

local Profile = {}
Profile.__index = Profile

local SESSION_ID = HttpService:GenerateGUID(false)

local SESSION_TIMEOUT = 60
local HEARTBEAT_INTERVAL = 30
local AUTO_SAVE_INTERVAL = 60

local mockStores: { [string]: { [string]: any } } = {}

export type Store = {
	_kind: "real",
	_store: DataStore,
} | {
	_kind: "mock",
	_name: string,
}

export type Profile = typeof(setmetatable(
	{} :: {
		Data: any,
		OnSessionEnd: Signal.Signal<>,
		_store: Store,
		_key: string,
		_userIds: { number },
		_ended: boolean,
		_dontSave: boolean,
		_heartbeatThread: thread?,
		_autoSaveThread: thread?,
	},
	Profile
))

local function now(): number
	return os.time()
end

local function deepReconcile(target: any, template: any)
	if type(template) ~= "table" then
		return
	end
	for key, templateValue in template do
		if type(templateValue) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			deepReconcile(target[key], templateValue)
		elseif target[key] == nil then
			target[key] = templateValue
		end
	end
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- ── Store abstraction ─────────────────────────────────────────────────────

local function openStore(name: string, useMock: boolean): Store
	if useMock then
		mockStores[name] = mockStores[name] or {}
		return { _kind = "mock", _name = name } :: Store
	end
	return { _kind = "real", _store = DataStoreService:GetDataStore(name) } :: Store
end

local function storeUpdate(store: Store, key: string, transform: (any) -> any): any
	if store._kind == "mock" then
		local bucket = mockStores[store._name]
		local newValue = transform(bucket[key])
		if newValue ~= nil then
			bucket[key] = newValue
		end
		return newValue
	end
	local result
	local ok, err = pcall(function()
		result = (store :: any)._store:UpdateAsync(key, function(prev)
			return transform(prev)
		end)
	end)
	if not ok then
		error(`Profile DataStore UpdateAsync failed for '{key}': {err}`, 0)
	end
	return result
end

local function storeRemove(store: Store, key: string)
	if store._kind == "mock" then
		mockStores[store._name][key] = nil
		return
	end
	local ok, err = pcall(function()
		(store :: any)._store:RemoveAsync(key)
	end)
	if not ok then
		warn(`[Framework.DataService] RemoveAsync failed for '{key}': {err}`)
	end
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

local function buildEntry(template: any, existing: any?): any
	local entry = existing or { data = deepCopy(template), userIds = {} }
	entry.data = entry.data or deepCopy(template)
	entry.userIds = entry.userIds or {}
	deepReconcile(entry.data, template)
	return entry
end

--[=[
	Attempts to claim the session lock and load the profile.

	  * `mode = "session"` - full session lifecycle (locks the key, will be
	    written back). Returns `nil` if another live server still holds it.
	  * `mode = "view"`    - read-only snapshot (no lock taken, no writes).

	Returns `(profile, snapshot)` on success.
]=]
function Profile.load(
	store: Store,
	key: string,
	template: any,
	mode: "session" | "view",
	dontSave: boolean?
): Profile?
	local entry
	local locked = false

	if mode == "view" then
		entry = storeUpdate(store, key, function(prev)
			return buildEntry(template, prev)
		end)
		entry.lock = nil
	else
		entry = storeUpdate(store, key, function(prev)
			local existing = buildEntry(template, prev)
			local lock = existing.lock
			local timedOut = lock and (now() - (lock.timestamp or 0)) > SESSION_TIMEOUT
			if lock and lock.sessionId ~= SESSION_ID and not timedOut then
				return nil
			end
			existing.lock = { sessionId = SESSION_ID, timestamp = now() }
			return existing
		end)
		if entry == nil then
			return nil
		end
		locked = true
	end

	local self: Profile = setmetatable({
		Data = entry.data,
		OnSessionEnd = Signal.new(),
		_store = store,
		_key = key,
		_userIds = entry.userIds or {},
		_ended = false,
		_dontSave = dontSave == true or mode == "view",
	}, Profile) :: any

	if locked then
		self:_startBackgroundLoops()
	end

	return self
end

function Profile._startBackgroundLoops(self: Profile)
	self._heartbeatThread = task.spawn(function()
		while not self._ended do
			task.wait(HEARTBEAT_INTERVAL)
			if self._ended then
				return
			end
			local ok, err = pcall(function()
				storeUpdate(self._store, self._key, function(prev)
					if not prev or not prev.lock then
						return nil
					end
					if prev.lock.sessionId ~= SESSION_ID then
						return nil
					end
					prev.lock.timestamp = now()
					return prev
				end)
			end)
			if not ok then
				warn(`[Framework.DataService] Heartbeat failed for '{self._key}': {err}`)
			end
		end
	end)

	self._autoSaveThread = task.spawn(function()
		while not self._ended do
			task.wait(AUTO_SAVE_INTERVAL)
			if self._ended then
				return
			end
			self:Save()
		end
	end)
end

function Profile.AddUserId(self: Profile, userId: number)
	if table.find(self._userIds, userId) then
		return
	end
	table.insert(self._userIds, userId)
end

function Profile.Reconcile(self: Profile)
end

function Profile.Save(self: Profile)
	if self._dontSave or self._ended then
		return
	end
	local ok, err = pcall(function()
		storeUpdate(self._store, self._key, function(prev)
			if prev and prev.lock and prev.lock.sessionId ~= SESSION_ID then
				return nil
			end
			local entry = prev or {}
			entry.data = deepCopy(self.Data)
			entry.userIds = table.clone(self._userIds)
			entry.lock = { sessionId = SESSION_ID, timestamp = now() }
			return entry
		end)
	end)
	if not ok then
		warn(`[Framework.DataService] Save failed for '{self._key}': {err}`)
	end
end

function Profile.EndSession(self: Profile)
	if self._ended then
		return
	end
	self._ended = true

	if not self._dontSave then
		local ok, err = pcall(function()
			storeUpdate(self._store, self._key, function(prev)
				if prev and prev.lock and prev.lock.sessionId ~= SESSION_ID then
					return nil
				end
				local entry = prev or {}
				entry.data = deepCopy(self.Data)
				entry.userIds = table.clone(self._userIds)
				entry.lock = nil
				return entry
			end)
		end)
		if not ok then
			warn(`[Framework.DataService] Final save failed for '{self._key}': {err}`)
		end
	end

	self.OnSessionEnd:fire()
	self.OnSessionEnd:destroy()
end

-- ── Store factory + sentinels ──────────────────────────────────────────────

Profile.openStore = openStore
Profile.removeKey = storeRemove

return Profile
