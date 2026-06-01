--!strict
--[=[
	@module Data.Profile
	Persistence adapter that backs the framework DataService with MadStudio's
	[ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (vendored
	beside this file as `ProfileStore.luau`).

	`Data.Server` only ever touches a tiny persistence surface, so this module
	maps that surface onto ProfileStore sessions and the rest of the data layer
	(`Server` / `Client` / `Data` / `Networking` / `Adapters`) is unchanged:

	  * `Profile.openStore(name, useMock, template) -> Store`
	  * `Profile.load(store, key, template, mode, dontSave?, cancel?) -> Profile?`
	  * `Profile.removeKey(store, key)`
	  * `Profile.sendMessage(store, key, message) -> boolean`

	Each returned profile exposes the same members the old hand-rolled wrapper
	did - `Data`, `OnSessionEnd` (a framework `Signal`), `:AddUserId`,
	`:Reconcile`, `:EndSession` - plus `:setMessageHandler` so the server can
	bridge ProfileStore's cross-server message queue to `addGlobalCallback`.

	ProfileStore handles session locking, periodic auto-save, reconciliation
	against the template, and the `BindToClose` flush for us.
]=]

local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)

local Profile = {}
Profile.__index = Profile

export type Mode = "session" | "view"

export type Store = {
	_ps: any,
	_useMock: boolean,
}

export type Profile = typeof(setmetatable(
	{} :: {
		Data: any,
		OnSessionEnd: Signal.Signal<>,
		_profile: any,
		_isView: boolean,
		_ended: boolean,
	},
	Profile
))

-- ProfileStore is server-only and self-initialises a Heartbeat/BindToClose
-- loop on require, so pull it in lazily from the server-only `openStore`.
local ProfileStore: any = nil

local function requireProfileStore(): any
	if not ProfileStore then
		ProfileStore = require(script.Parent.ProfileStore) :: any
	end
	return ProfileStore
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

-- `ProfileStore.Mock` mirrors every store method against an in-memory
-- DataStore, which is what we want when `useMock` is set (Studio with API
-- services disabled). Note its `StartSessionAsync` ignores the params table,
-- but mock sessions never conflict so the `Cancel` guard is real-store only.
local function realmOf(store: Store): any
	return if store._useMock then store._ps.Mock else store._ps
end

local function wrap(psProfile: any, isView: boolean, template: any): Profile
	local data = if psProfile ~= nil then psProfile.Data else deepCopy(template)

	local self: Profile = setmetatable({
		Data = data,
		OnSessionEnd = Signal.new(),
		_profile = psProfile,
		_isView = isView,
		_ended = false,
	}, Profile) :: any

	if psProfile ~= nil and not isView then
		psProfile.OnSessionEnd:Connect(function()
			if self._ended then
				return
			end
			self._ended = true
			self.OnSessionEnd:fire()
		end)
	end

	return self
end

--[=[
	Builds a ProfileStore for `name`. The template is bound at store-creation
	time because ProfileStore reconciles `Profile.Data` against it.
]=]
function Profile.openStore(name: string, useMock: boolean, template: any): Store
	assert(RunService:IsServer(), "DataService.Profile can only open a store on the server")
	assert(type(template) == "table", "DataService.Profile.openStore: template table is required")
	local PS = requireProfileStore()
	return {
		_ps = PS.New(name, template),
		_useMock = useMock == true,
	}
end

--[=[
	Starts a ProfileStore session (`mode == "session"`) or loads a read-only
	snapshot (`mode == "view"`).

	  * Session mode returns `nil` only when the session could not be started
	    (e.g. the `cancel` guard fired because the player already left).
	  * View mode never blocks another server and never saves; if the key has
	    no saved data yet it hands back an in-memory, template-shaped snapshot
	    so callers still get a usable (but non-persistent) `Data` table.
]=]
function Profile.load(
	store: Store,
	key: string,
	template: any,
	mode: Mode,
	_dontSave: boolean?,
	cancel: (() -> boolean)?
): Profile?
	local realm = realmOf(store)

	if mode == "view" then
		local psProfile = realm:GetAsync(key)
		return wrap(psProfile, true, template)
	end

	local psProfile
	if store._useMock then
		psProfile = realm:StartSessionAsync(key)
	else
		psProfile = realm:StartSessionAsync(key, { Cancel = cancel })
	end

	if psProfile == nil then
		return nil
	end

	return wrap(psProfile, false, template)
end

function Profile.removeKey(store: Store, key: string)
	local realm = realmOf(store)
	local ok, err = pcall(function()
		realm:RemoveAsync(key)
	end)
	if not ok then
		warn(`[Framework.DataService] RemoveAsync failed for '{key}': {err}`)
	end
end

--[=[
	Posts a message to the profile under `key` via ProfileStore's cross-server
	message queue. Delivered to handlers registered with `:setMessageHandler`.
]=]
function Profile.sendMessage(store: Store, key: string, message: any): boolean
	local realm = realmOf(store)
	local ok, result = pcall(function()
		return realm:MessageAsync(key, message)
	end)
	if not ok then
		warn(`[Framework.DataService] MessageAsync failed for '{key}': {result}`)
		return false
	end
	return result == true
end

-- ── Per-profile surface consumed by Data.Server ────────────────────────────

function Profile.AddUserId(self: Profile, userId: number)
	if self._profile then
		self._profile:AddUserId(userId)
	end
end

function Profile.Reconcile(self: Profile)
	if self._profile then
		self._profile:Reconcile()
		-- Reconcile mutates Data in place; refresh our cached reference anyway.
		self.Data = self._profile.Data
	end
end

function Profile.EndSession(self: Profile)
	if self._isView or self._ended or not self._profile then
		return
	end
	self._profile:EndSession()
end

--[=[
	Registers a ProfileStore message handler. `fn(message, processed)` is
	called for each queued/incoming message; call `processed()` to consume it.
]=]
function Profile.setMessageHandler(self: Profile, fn: (message: any, processed: () -> ()) -> ())
	if self._isView or not self._profile then
		return
	end
	self._profile:MessageHandler(fn)
end

return Profile
