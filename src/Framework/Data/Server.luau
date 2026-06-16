--!strict
--[=[
	@module Data.Server
	Server side singleton. Gives every `Player` a `Profile` (persistence)
	and a `Data` (reactive tree), and pushes mutations back to the owning
	client over a single RemoteEvent.

	Public surface follows `leifstout/dataservice`'s server module
	(`:init`, `:get`, `:set`, `:update`, `:arrayInsert`, `:arrayRemove`,
	`:waitForData`, ...) so the framework adapter is just a pass-through.

	Method names are camelCase on purpose; the adapter calls them as
	`self._server:<method>`.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Data = require(script.Parent.Data)
local Profile = require(script.Parent.Profile)
local Networking = require(script.Parent.Networking)
local Migration = require(script.Parent.Migration)
local Utils = require(script.Parent.Utils)

if RunService:IsClient() then
	return {} :: any
end

type Path = Data.Path
type Profile = Profile.Profile

export type Options = {
	template: any,
	useMock: boolean?,
	viewedUserId: number?,
	overridenUserId: number?,
	dontSave: boolean?,
	resetData: boolean?,
	profileStoreIndex: string?,
	profileStoreDataPrefix: string?,
	migrations: { Migration.Migrator }?,
	dataVersionKey: string?,
}

local DEFAULT_INDEX = "PlayerData"
local DEFAULT_PREFIX = "PLAYER_"

type GlobalCallback = (player: Player, data: { any }) -> boolean?

local Server = {
	_profiles = {} :: { [Player]: Profile },
	_data = {} :: { [Player]: Data.Data },
	_waitSignals = {} :: { [Player]: Signal.Signal<> },
	_removalCallbacks = {} :: { (player: Player, data: any) -> () },
	_messageHandlers = {} :: { [string]: { GlobalCallback } },
	_initialized = false,
	_replicate = nil :: RemoteEvent?,
	_fetch = nil :: RemoteFunction?,
	_migration = nil :: Migration.Config?,
	options = (nil :: any) :: Options,
	store = nil :: Profile.Store?,
}

local function keyForUserId(self: any, userId: number | string): string
	local prefix = (self.options :: Options).profileStoreDataPrefix or DEFAULT_PREFIX
	return prefix .. tostring(userId)
end

-- Fan a ProfileStore message out to the matching `addGlobalCallback` handlers.
-- Messages are tagged `{ key = <callbackKey>, data = <payload> }` by
-- `sendGlobalMessage`. We drop the message from the queue once at least one
-- handler returns `true`.
local function dispatchGlobalMessage(self: any, player: Player, message: any, processed: () -> ())
	if type(message) ~= "table" or type(message.key) ~= "string" then
		processed()
		return
	end
	local handlers = self._messageHandlers[message.key]
	if not handlers then
		return
	end
	local consumed = false
	for _, callback in handlers do
		local ok, result = pcall(callback, player, message.data)
		if not ok then
			warn(`[Framework.DataService] global callback '{message.key}' errored: {result}`)
		elseif result == true then
			consumed = true
		end
	end
	if consumed then
		processed()
	end
end

-- Per-player setup
local function attachPlayer(self: any, player: Player)
	local opts: Options = self.options
	local userId = opts.overridenUserId or opts.viewedUserId or player.UserId
	local key = keyForUserId(self, userId)

	if opts.resetData and not opts.viewedUserId then
		Profile.removeKey(self.store, key)
	end

	local mode: "session" | "view" = if opts.viewedUserId or opts.dontSave then "view" else "session"
	-- Bail on the session attempt if the player leaves while we're waiting out
	-- a session conflict from another server.
	local cancel = function()
		return not player:IsDescendantOf(Players)
	end
	local profile = Profile.load(self.store, key, opts.template, mode, opts.dontSave, cancel)
	if not profile then
		player:Kick("Profile load failed (please rejoin)")
		return
	end

	profile:AddUserId(userId)

	-- Upgrade the saved schema before reconcile fills template defaults. A
	-- brand-new profile (empty Data) skips migration and starts stamped at the
	-- target version; existing data runs the outstanding migrators.
	local migration = self._migration
	if migration then
		local data = profile.Data
		if next(data) == nil then
			data[Migration.keyOf(migration)] = Migration.targetVersion(migration)
		else
			local ok, err = pcall(Migration.run, data, migration)
			if not ok then
				warn(`[Framework.DataService] data migration failed for {player.Name}: {err}`)
			end
		end
	end

	profile:Reconcile()

	-- Pipe ProfileStore's cross-server queue into addGlobalCallback.
	profile:setMessageHandler(function(message: any, processed: () -> ())
		dispatchGlobalMessage(self, player, message, processed)
	end)

	profile.OnSessionEnd:connect(function()
		self._profiles[player] = nil
		if player:IsDescendantOf(Players) then
			player:Kick("Profile session ended - please rejoin")
		end
	end)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile

	local data = Data.new(profile.Data)
	self._data[player] = data

	if type(self.onPlayerInit) == "function" then
		local ok, err = pcall(self.onPlayerInit, self, player, profile.Data)
		if not ok then
			warn(`[Framework.DataService] onPlayerInit errored for {player.Name}: {err}`)
		end
	end

	(self._replicate :: RemoteEvent):FireClient(player, Utils.Action.Init, profile.Data)

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:fire()
		waitSignal:destroy()
		self._waitSignals[player] = nil
	end
end

local function detachPlayer(self: any, player: Player)
	local profile = self._profiles[player]
	if not profile then
		return
	end

	for _, cb in self._removalCallbacks do
		local ok, err = pcall(cb, player, profile.Data)
		if not ok then
			warn(`[Framework.DataService] removal callback errored for {player.Name}: {err}`)
		end
	end

	profile:EndSession()
	self._profiles[player] = nil

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:destroy()
		self._waitSignals[player] = nil
	end

	local data = self._data[player]
	if data then
		data:destroy()
		self._data[player] = nil
	end
end

--[=[
	One-shot bootstrap. Opens the DataStore (or the mock), sets up the
	network plumbing, and hooks `PlayerAdded` / `PlayerRemoving` plus a
	`BindToClose` flush. Call this once.
]=]
function Server.init(self: any, options: Options)
	assert(RunService:IsServer(), "DataService.Server can only be initialised on the server")
	assert(not self._initialized, "DataService.Server: already initialised")
	assert(type(options) == "table", "DataService.Server.init: options table required")
	assert(type(options.template) == "table", "DataService.Server.init: options.template is required")

	self._initialized = true
	self.options = options

	-- Bind schema migrations and stamp the template so fresh profiles start at
	-- the target version. Done before openStore since ProfileStore captures the
	-- template at store creation.
	if options.migrations and #options.migrations > 0 then
		local config: Migration.Config = {
			migrations = options.migrations,
			versionKey = options.dataVersionKey,
		}
		self._migration = config
		Migration.stampTemplate(options.template, config)
	end

	self.store = Profile.openStore(
		options.profileStoreIndex or DEFAULT_INDEX,
		options.useMock == true,
		options.template
	)

	local replicate, fetch = Networking.buildServer()
	self._replicate = replicate
	self._fetch = fetch

	fetch.OnServerInvoke = function(player: Player, path: any?)
		local data = self._data[player]
		if not data then
			return nil
		end
		return data:get(path)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(attachPlayer, self, player)
	end
	Players.PlayerAdded:Connect(function(player)
		attachPlayer(self, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		detachPlayer(self, player)
	end)

	game:BindToClose(function()
		for player in self._profiles do
			task.spawn(detachPlayer, self, player)
		end
		task.wait(1)
	end)
end

--[=[
	Overridable hook. Runs right after a player's profile loads but before
	the initial snapshot goes out to their client. Set it before `:init`
	(or just override `Server.onPlayerInit` directly).
]=]
function Server.onPlayerInit(_self: any, _player: Player, _data: any) end

function Server.hasProfile(self: any, player: Player): boolean
	return self._profiles[player] ~= nil
end

function Server.getProfile(self: any, player: Player): Profile
	local profile = self._profiles[player]
	assert(profile, `DataService.Server: no profile for {player.Name}`)
	return profile
end

function Server.waitForData(self: any, player: Player): Data.Data
	local data = self._data[player]
	if data then
		return data
	end
	local waitSignal = self._waitSignals[player]
	if not waitSignal then
		waitSignal = Signal.new()
		self._waitSignals[player] = waitSignal
	end
	waitSignal:wait()
	return self._data[player]
end

function Server.get(self: any, player: Player, path: Path?): any
	return self._data[player]:get(path)
end

function Server.set(self: any, player: Player, path: Path, value: any, dontReplicate: boolean?)
	if not dontReplicate then
		(self._replicate :: RemoteEvent):FireClient(player, Utils.Action.Set, path, value)
	end
	self._data[player]:set(path, value)
end

function Server.update(self: any, player: Player, path: Path, callback: (any) -> any, dontReplicate: boolean?): any
	local value = self._data[player]:update(path, callback)
	if not dontReplicate then
		(self._replicate :: RemoteEvent):FireClient(player, Utils.Action.Set, path, value)
	end
	return value
end

function Server.arrayInsert(
	self: any,
	player: Player,
	path: Path,
	value: any,
	index: number?,
	dontReplicate: boolean?
)
	if not dontReplicate then
		(self._replicate :: RemoteEvent):FireClient(player, Utils.Action.ArrayInsert, path, value, index)
	end
	self._data[player]:arrayInsert(path, value, index)
end

function Server.arrayRemove(
	self: any,
	player: Player,
	path: Path,
	index: number,
	dontReplicate: boolean?
): any
	local value = self._data[player]:arrayRemove(path, index)
	if not dontReplicate then
		(self._replicate :: RemoteEvent):FireClient(player, Utils.Action.ArrayRemove, path, index)
	end
	return value
end

function Server.getChangedSignal(self: any, player: Player, path: Path)
	return self._data[player]:getChangedSignal(path)
end

function Server.getIndexChangedSignal(self: any, player: Player, path: Path)
	return self._data[player]:getIndexChangedSignal(path)
end

function Server.getArrayInsertedSignal(self: any, player: Player, path: Path)
	return self._data[player]:getArrayInsertedSignal(path)
end

function Server.getArrayRemovedSignal(self: any, player: Player, path: Path)
	return self._data[player]:getArrayRemovedSignal(path)
end

function Server.addPlayerRemovingCallback(self: any, fn: (player: Player, data: any) -> ()): () -> ()
	table.insert(self._removalCallbacks, fn)
	return function()
		local idx = table.find(self._removalCallbacks, fn)
		if idx then
			table.remove(self._removalCallbacks, idx)
		end
	end
end

function Server.resetData(self: any, player: Player)
	local key = keyForUserId(self, player.UserId)
	local profile = self._profiles[player]
	if profile then
		-- End the session first (flushes + releases the lock), then wipe the
		-- key once it's fully ended - otherwise the final save can race the
		-- removal and re-create the data.
		profile.OnSessionEnd:connect(function()
			Profile.removeKey(self.store, key)
		end)
		profile:EndSession()
	else
		Profile.removeKey(self.store, key)
	end
	player:Kick("Your data has been reset - please rejoin.")
end

----- Cross-server messaging (backed by ProfileStore's message queue) -----

--[=[
	Registers a handler for global messages sent to a player's profile under
	`key`. Return `true` once you've processed the message so ProfileStore
	drops it from the queue. Handlers fire both for messages that land while
	the player is in this server and for ones queued while they were offline
	(those get delivered on their next session).
]=]
function Server.addGlobalCallback(self: any, key: string, callback: GlobalCallback)
	assert(type(key) == "string", "DataService.Server.addGlobalCallback: key must be a string")
	assert(type(callback) == "function", "DataService.Server.addGlobalCallback: callback must be a function")
	local list = self._messageHandlers[key]
	if not list then
		list = {}
		self._messageHandlers[key] = list
	end
	table.insert(list, callback)
end

--[=[
	Posts a global message to the profile owned by `userId`, no matter which
	server (if any) has it loaded right now. Returns whether the message got
	queued.
]=]
function Server.sendGlobalMessage(self: any, key: string, userId: number | string, data: { any }): boolean
	return Profile.sendMessage(self.store, keyForUserId(self, userId), { key = key, data = data })
end

return Server
