--!strict
--[=[
	@module Data.Server
	Server-side singleton that pairs every `Player` with a `Profile`
	(persistence) and a `Data` (reactive tree), and replicates mutations
	back to the owning client over a single RemoteEvent.

	Mirrors the public surface of `leifstout/dataservice`'s server module
	(`:init`, `:get`, `:set`, `:update`, `:arrayInsert`, `:arrayRemove`,
	`:waitForData`, ...) so the framework adapter is a thin pass-through.

	Method names are intentionally camelCase to match the adapter's
	`self._server:<method>` call sites.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Data = require(script.Parent.Data)
local Profile = require(script.Parent.Profile)
local Networking = require(script.Parent.Networking)
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
}

local DEFAULT_INDEX = "PlayerData"
local DEFAULT_PREFIX = "PLAYER_"

local Server = {
	_profiles = {} :: { [Player]: Profile },
	_data = {} :: { [Player]: Data.Data },
	_waitSignals = {} :: { [Player]: Signal.Signal<> },
	_removalCallbacks = {} :: { (player: Player, data: any) -> () },
	_initialized = false,
	_replicate = nil :: RemoteEvent?,
	_fetch = nil :: RemoteFunction?,
	options = (nil :: any) :: Options,
	store = nil :: Profile.Store?,
}

local function keyForUserId(self: any, userId: number | string): string
	local prefix = (self.options :: Options).profileStoreDataPrefix or DEFAULT_PREFIX
	return prefix .. tostring(userId)
end

-- Hook the per-player setup pipeline.
local function attachPlayer(self: any, player: Player)
	local opts: Options = self.options
	local userId = opts.overridenUserId or opts.viewedUserId or player.UserId
	local key = keyForUserId(self, userId)

	if opts.resetData and not opts.viewedUserId then
		Profile.removeKey(self.store, key)
	end

	local mode: "session" | "view" = if opts.viewedUserId or opts.dontSave then "view" else "session"
	local profile = Profile.load(self.store, key, opts.template, mode, opts.dontSave)
	if not profile then
		player:Kick("Profile load failed (session locked) - please rejoin")
		return
	end

	profile:AddUserId(userId)
	profile:Reconcile()
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
	One-shot bootstrap. Opens the DataStore (or its mock equivalent),
	stands up the network plumbing, and binds to `PlayerAdded` /
	`PlayerRemoving` plus a `BindToClose` flush. Safe to call exactly once.
]=]
function Server.init(self: any, options: Options)
	assert(RunService:IsServer(), "DataService.Server can only be initialised on the server")
	assert(not self._initialized, "DataService.Server: already initialised")
	assert(type(options) == "table", "DataService.Server.init: options table required")
	assert(type(options.template) == "table", "DataService.Server.init: options.template is required")

	self._initialized = true
	self.options = options
	self.store = Profile.openStore(options.profileStoreIndex or DEFAULT_INDEX, options.useMock == true)

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
	Overridable hook called immediately after a player's profile loads but
	before the initial snapshot is sent to their client. Set this *before*
	`:init` (or just override `Server.onPlayerInit` directly).
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
	local profile = self._profiles[player]
	if profile then
		(profile :: any)._dontSave = true
		profile:EndSession()
	end
	Profile.removeKey(self.store, keyForUserId(self, player.UserId))
	player:Kick("Your data has been reset - please rejoin.")
end

-- ── No-op stubs for upstream parity ────────────────────────────────────────
-- The original DataService also surfaces `addGlobalCallback` /
-- `sendGlobalMessage` (ProfileStore message handlers). They have no
-- equivalent in raw DataStores, so we expose stubs that throw clearly
-- if called, rather than silently dropping messages.

function Server.addGlobalCallback(_self: any, _key: string, _cb: (player: Player, data: { any }) -> boolean?)
	error("DataService.Server.addGlobalCallback is not supported by the framework's built-in DataService", 2)
end

function Server.sendGlobalMessage(_self: any, _key: string, _userId: number | string, _data: { any }): boolean
	error("DataService.Server.sendGlobalMessage is not supported by the framework's built-in DataService", 2)
end

return Server
