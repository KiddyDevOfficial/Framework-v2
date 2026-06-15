--!strict
--[=[
	@module Adapters.Data
	Framework-native bindings for the built-in DataService
	(`src/Framework/Data/`). Two factories that hand back ready-to-register
	framework units:

	  * `Data.CreateService(options)`    - a `Framework.CreateService` table
	    that calls `DataService.server:init(...)` in its `Init` hook.
	  * `Data.CreateController(options)` - a `Framework.CreateController` table
	    that calls `DataService.client:init()` in its `Start` hook (init yields
	    until the server pushes the initial snapshot).

	Both forward the underlying API as PascalCase methods so they read like
	the rest of the framework.

	`CreateDataService<T>` / `CreateDataController<T>` take a template type
	`T` (usually `DataTemplate.DataTemplate`) so `:Get` / `:Update` path
	arguments autocomplete off your schema.
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local Controller = require(script.Parent.Parent.Modular.Controller)
local DataPackage = require(script.Parent.Parent.Data)
local Paths = require(script.Parent.Parent.Data.Paths)

local Data = {}

export type AnyPath = Paths.Path
export type AnyArrayPath = Paths.ArrayPath

export type ServerOptions<T = { [string]: any }> = {
	Name: string?,
	Dependencies: { string }?,
	Template: T,
	ProfileStoreIndex: string?,
	ProfileStoreDataPrefix: string?,
	UseMock: boolean?,
	ViewedUserId: number?,
	OverriddenUserId: number?,
	DontSave: boolean?,
	ResetData: boolean?,
	OnPlayerInit: ((self: any, player: Player, data: T) -> ())?,
}

export type ClientOptions<T = { [string]: any }> = {
	Name: string?,
	Dependencies: { string }?,
	Template: T?,
}

--[=[
	Public API for `Framework.CreateDataService<T>(...)`. For full path
	autocomplete, require your game `DataService` module (the one that sets
	`T` from `DataTemplate`); don't go through `Framework.GetService("DataService")`.
]=]
export type ServerClass<T = { [string]: any }, TPath = AnyPath, TArrayPath = AnyArrayPath> = {
	Server: (self: ServerClass<T, TPath, TArrayPath>) -> any,
	WaitForData: (self: ServerClass<T, TPath, TArrayPath>, player: Player) -> any,
	HasProfile: (self: ServerClass<T, TPath, TArrayPath>, player: Player) -> boolean,
	GetProfile: (self: ServerClass<T, TPath, TArrayPath>, player: Player) -> any,
	Get: (self: ServerClass<T, TPath, TArrayPath>, player: Player, path: TPath?) -> any,
	Set: (
		self: ServerClass<T, TPath, TArrayPath>,
		player: Player,
		path: TPath,
		value: any,
		dontReplicate: boolean?
	) -> (),
	Update: (
		self: ServerClass<T, TPath, TArrayPath>,
		player: Player,
		path: TPath,
		callback: (prev: any) -> any,
		dontReplicate: boolean?
	) -> any,
	ArrayInsert: (
		self: ServerClass<T, TPath, TArrayPath>,
		player: Player,
		path: TArrayPath,
		value: any,
		index: number?,
		dontReplicate: boolean?
	) -> (),
	ArrayRemove: (
		self: ServerClass<T, TPath, TArrayPath>,
		player: Player,
		path: TArrayPath,
		index: number,
		dontReplicate: boolean?
	) -> any,
	GetChangedSignal: (self: ServerClass<T, TPath, TArrayPath>, player: Player, path: TPath) -> any,
	GetIndexChangedSignal: (self: ServerClass<T, TPath, TArrayPath>, player: Player, path: TPath) -> any,
	GetArrayInsertedSignal: (self: ServerClass<T, TPath, TArrayPath>, player: Player, path: TArrayPath) -> any,
	GetArrayRemovedSignal: (self: ServerClass<T, TPath, TArrayPath>, player: Player, path: TArrayPath) -> any,
	AddGlobalCallback: (self: ServerClass<T, TPath, TArrayPath>, key: string, callback: (player: Player, data: { any }) -> boolean?) -> (),
	SendGlobalMessage: (self: ServerClass<T, TPath, TArrayPath>, key: string, userId: number | string, data: { any }) -> boolean,
	AddPlayerRemovingCallback: (self: ServerClass<T, TPath, TArrayPath>, fn: (player: Player, data: T) -> ()) -> () -> (),
	ResetData: (self: ServerClass<T, TPath, TArrayPath>, player: Player) -> (),
}

export type ClientClass<T = { [string]: any }, TPath = AnyPath, TArrayPath = AnyArrayPath> = {
	Client: (self: ClientClass<T, TPath, TArrayPath>) -> any,
	WaitForData: (self: ClientClass<T, TPath, TArrayPath>) -> any,
	Get: (self: ClientClass<T, TPath, TArrayPath>, path: TPath?) -> any,
	Set: (self: ClientClass<T, TPath, TArrayPath>, path: TPath, value: any) -> (),
	Update: (
		self: ClientClass<T, TPath, TArrayPath>,
		path: TPath,
		callback: (prev: any) -> any
	) -> any,
	ArrayInsert: (
		self: ClientClass<T, TPath, TArrayPath>,
		path: TArrayPath,
		value: any,
		index: number?
	) -> (),
	ArrayRemove: (self: ClientClass<T, TPath, TArrayPath>, path: TArrayPath, index: number) -> any,
	Fetch: (self: ClientClass<T, TPath, TArrayPath>, path: TPath?, dontSet: boolean?) -> any,
	GetChangedSignal: (self: ClientClass<T, TPath, TArrayPath>, path: TPath) -> any,
	GetIndexChangedSignal: (self: ClientClass<T, TPath, TArrayPath>, path: TPath) -> any,
	GetArrayInsertedSignal: (self: ClientClass<T, TPath, TArrayPath>, path: TArrayPath) -> any,
	GetArrayRemovedSignal: (self: ClientClass<T, TPath, TArrayPath>, path: TArrayPath) -> any,
}

type ServerBackend = typeof(DataPackage.server)

function Data.CreateService<T, TPath, TArrayPath>(options: ServerOptions<T>): ServerClass<T, TPath, TArrayPath>
	assert(type(options) == "table", "Framework.CreateDataService: options table is required")
	assert(
		type(options.Template) == "table",
		"Framework.CreateDataService: `Template` (table) is required"
	)

	local name = options.Name or "DataService"

	local def = Service.Create({
		Name = name,
		Dependencies = options.Dependencies or {},
	}) :: ServerClass<T, TPath, TArrayPath> & { _server: ServerBackend? }

	function def:Init()
		if not RunService:IsServer() then
			return
		end

		local server = DataPackage.server
		self._server = server

		if options.OnPlayerInit then
			(server :: any).onPlayerInit = function(_self, player, data)
				options.OnPlayerInit(self, player, data)
			end
		end

		server:init({
			template = options.Template,
			useMock = options.UseMock,
			viewedUserId = options.ViewedUserId,
			overridenUserId = options.OverriddenUserId,
			dontSave = options.DontSave,
			resetData = options.ResetData,
			profileStoreIndex = options.ProfileStoreIndex,
			profileStoreDataPrefix = options.ProfileStoreDataPrefix,
		})
	end

	function def:Server(): ServerBackend
		return self._server :: ServerBackend
	end

	function def:WaitForData(player: Player): any
		return (self._server :: ServerBackend):waitForData(player)
	end

	function def:HasProfile(player: Player): boolean
		return (self._server :: ServerBackend):hasProfile(player)
	end

	function def:GetProfile(player: Player): any
		return (self._server :: ServerBackend):getProfile(player)
	end

	function def:Get(player: Player, path: TPath?): any
		return (self._server :: ServerBackend):get(player, path :: any)
	end

	function def:Set(player: Player, path: TPath, value: any, dontReplicate: boolean?)
		return (self._server :: ServerBackend):set(player, path :: any, value, dontReplicate)
	end

	function def:Update(
		player: Player,
		path: TPath,
		callback: (prev: any) -> any,
		dontReplicate: boolean?
	): any
		return (self._server :: ServerBackend):update(player, path :: any, callback :: any, dontReplicate)
	end

	function def:ArrayInsert(
		player: Player,
		path: TArrayPath,
		value: any,
		index: number?,
		dontReplicate: boolean?
	)
		return (self._server :: ServerBackend):arrayInsert(player, path :: any, value, index, dontReplicate)
	end

	function def:ArrayRemove(
		player: Player,
		path: TArrayPath,
		index: number,
		dontReplicate: boolean?
	): any
		return (self._server :: ServerBackend):arrayRemove(player, path :: any, index, dontReplicate)
	end

	function def:GetChangedSignal(player: Player, path: TPath)
		return (self._server :: ServerBackend):getChangedSignal(player, path :: any)
	end

	function def:GetIndexChangedSignal(player: Player, path: TPath)
		return (self._server :: ServerBackend):getIndexChangedSignal(player, path :: any)
	end

	function def:GetArrayInsertedSignal(player: Player, path: TArrayPath)
		return (self._server :: ServerBackend):getArrayInsertedSignal(player, path :: any)
	end

	function def:GetArrayRemovedSignal(player: Player, path: TArrayPath)
		return (self._server :: ServerBackend):getArrayRemovedSignal(player, path :: any)
	end

	function def:AddGlobalCallback(key: string, callback: (player: Player, data: { any }) -> boolean?)
		return (self._server :: ServerBackend):addGlobalCallback(key, callback)
	end

	function def:SendGlobalMessage(key: string, userId: number | string, data: { any }): boolean
		return (self._server :: ServerBackend):sendGlobalMessage(key, userId, data)
	end

	function def:AddPlayerRemovingCallback(fn: (player: Player, data: T) -> ()): () -> ()
		return (self._server :: ServerBackend):addPlayerRemovingCallback(fn)
	end

	function def:ResetData(player: Player)
		return (self._server :: ServerBackend):resetData(player)
	end

	return def :: ServerClass<T, TPath, TArrayPath>
end

function Data.CreateController<T, TPath, TArrayPath>(options: ClientOptions<T>?): ClientClass<T, TPath, TArrayPath>
	local opts: ClientOptions<T> = options or {}
	local name = opts.Name or "DataController"

	local def = Controller.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	}) :: ClientClass<T, TPath, TArrayPath> & { _client: any }

	function def:Init()
		if not RunService:IsClient() then
			return
		end
		local client = DataPackage.client
		self._client = client
		client:bind()
	end

	function def:Start()
		if not RunService:IsClient() then
			return
		end
		(self._client :: any):init()
	end

	function def:Client(): any
		return self._client
	end

	function def:WaitForData(): any
		return (self._client :: any):waitForData()
	end

	function def:Get(path: TPath?): any
		return (self._client :: any):get(path :: any)
	end

	function def:Set(path: TPath, value: any)
		return (self._client :: any):set(path :: any, value)
	end

	function def:Update(path: TPath, callback: (prev: any) -> any): any
		return (self._client :: any):update(path :: any, callback :: any)
	end

	function def:ArrayInsert(path: TArrayPath, value: any, index: number?)
		return (self._client :: any):arrayInsert(path :: any, value, index)
	end

	function def:ArrayRemove(path: TArrayPath, index: number): any
		return (self._client :: any):arrayRemove(path :: any, index)
	end

	function def:Fetch(path: TPath?, dontSet: boolean?): any
		return (self._client :: any):fetch(path :: any, dontSet)
	end

	function def:GetChangedSignal(path: TPath)
		return (self._client :: any):getChangedSignal(path :: any)
	end

	function def:GetIndexChangedSignal(path: TPath)
		return (self._client :: any):getIndexChangedSignal(path :: any)
	end

	function def:GetArrayInsertedSignal(path: TArrayPath)
		return (self._client :: any):getArrayInsertedSignal(path :: any)
	end

	function def:GetArrayRemovedSignal(path: TArrayPath)
		return (self._client :: any):getArrayRemovedSignal(path :: any)
	end

	return def :: ClientClass<T, TPath, TArrayPath>
end

return Data
