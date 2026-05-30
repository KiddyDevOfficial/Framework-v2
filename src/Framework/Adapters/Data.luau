--!strict
--[=[
	@module Adapters.Data
	Framework-native bindings for the built-in DataService
	(`src/Framework/Data/`). Exposes two factories that return
	ready-to-register framework units:

	  * `Data.CreateService(options)`    - builds a `Framework.CreateService`
	    table that calls `DataService.server:init(...)` in its `Init` hook.
	  * `Data.CreateController(options)` - builds a `Framework.CreateController`
	    table that calls `DataService.client:init()` in its `Start` hook
	    (init yields until the server pushes the initial snapshot).

	Both definitions forward the underlying API as PascalCase methods so
	they read consistently with the rest of the framework:

	```lua
	-- src/server/Services/DataService.luau
	local Framework = require(ReplicatedStorage.Framework)
	local Template = require(ReplicatedStorage.Shared.DataTemplate)

	return Framework.CreateDataService({
	    Template = Template,
	    ProfileStoreIndex = "Production",
	})
	```

	```lua
	-- src/client/Controllers/DataController.luau
	local Framework = require(ReplicatedStorage.Framework)
	return Framework.CreateDataController()
	```
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local Controller = require(script.Parent.Parent.Modular.Controller)
local DataPackage = require(script.Parent.Parent.Data)

local Data = {}

export type ServerOptions = {
	Name: string?,
	Dependencies: { string }?,
	Template: { [string]: any },
	ProfileStoreIndex: string?,
	ProfileStoreDataPrefix: string?,
	UseMock: boolean?,
	ViewedUserId: number?,
	OverriddenUserId: number?,
	DontSave: boolean?,
	ResetData: boolean?,
	OnPlayerInit: ((self: any, player: Player, data: any) -> ())?,
}

export type ClientOptions = {
	Name: string?,
	Dependencies: { string }?,
}

--[=[
	Public API exposed by `Framework.CreateDataService(...)`. Cast the
	return of `Framework.GetService("DataService")` to this type to get
	autocomplete on every server-side DataService method.
]=]
export type ServerClass = {
	Server: (self: ServerClass) -> any,
	WaitForData: (self: ServerClass, player: Player) -> any,
	HasProfile: (self: ServerClass, player: Player) -> boolean,
	GetProfile: (self: ServerClass, player: Player) -> any,
	Get: (self: ServerClass, player: Player, path: any) -> any,
	Set: (self: ServerClass, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
	Update: (self: ServerClass, player: Player, path: any, callback: (any) -> any, dontReplicate: boolean?) -> any,
	ArrayInsert: (
		self: ServerClass,
		player: Player,
		path: any,
		value: any,
		index: number?,
		dontReplicate: boolean?
	) -> (),
	ArrayRemove: (self: ServerClass, player: Player, path: any, index: number, dontReplicate: boolean?) -> any,
	GetChangedSignal: (self: ServerClass, player: Player, path: any) -> any,
	GetIndexChangedSignal: (self: ServerClass, player: Player, path: any) -> any,
	GetArrayInsertedSignal: (self: ServerClass, player: Player, path: any) -> any,
	GetArrayRemovedSignal: (self: ServerClass, player: Player, path: any) -> any,
	AddGlobalCallback: (self: ServerClass, key: string, callback: (player: Player, data: { any }) -> boolean?) -> (),
	SendGlobalMessage: (self: ServerClass, key: string, userId: number | string, data: { any }) -> boolean,
	AddPlayerRemovingCallback: (self: ServerClass, fn: (player: Player, data: any) -> ()) -> () -> (),
	ResetData: (self: ServerClass, player: Player) -> (),
}

--[=[
	Public API exposed by `Framework.CreateDataController(...)`. Cast the
	return of `Framework.GetController("DataController")` to this type to
	get autocomplete on every client-side DataController method.
]=]
export type ClientClass = {
	Client: (self: ClientClass) -> any,
	WaitForData: (self: ClientClass) -> any,
	Get: (self: ClientClass, path: any?) -> any,
	Set: (self: ClientClass, path: any, value: any) -> (),
	Update: (self: ClientClass, path: any, callback: (any) -> any) -> any,
	ArrayInsert: (self: ClientClass, path: any, value: any, index: number?) -> (),
	ArrayRemove: (self: ClientClass, path: any, index: number) -> any,
	Fetch: (self: ClientClass, path: any?, dontSet: boolean?) -> any,
	GetChangedSignal: (self: ClientClass, path: any) -> any,
	GetIndexChangedSignal: (self: ClientClass, path: any) -> any,
	GetArrayInsertedSignal: (self: ClientClass, path: any) -> any,
	GetArrayRemovedSignal: (self: ClientClass, path: any) -> any,
}

--[=[
	Wraps the `DataService.server` singleton in a framework `Service`.
	Other services can depend on it via `Dependencies = { "DataService" }`
	(or whatever `Name` you choose) to be guaranteed of a live profile store
	before their own `Init` runs.
]=]
function Data.CreateService(options: ServerOptions): ServerClass
	assert(type(options) == "table", "Framework.CreateDataService: options table is required")
	assert(
		type(options.Template) == "table",
		"Framework.CreateDataService: `Template` (table) is required"
	)

	local name = options.Name or "DataService"

	local def: any = Service.Create({
		Name = name,
		Dependencies = options.Dependencies or {},
	})

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

	function def:Server(): any
		return self._server
	end

	function def:WaitForData(player: Player): any
		return self._server:waitForData(player)
	end

	function def:HasProfile(player: Player): boolean
		return self._server:hasProfile(player)
	end

	function def:GetProfile(player: Player): any
		return self._server:getProfile(player)
	end

	function def:Get(player: Player, path: any): any
		return self._server:get(player, path)
	end

	function def:Set(player: Player, path: any, value: any, dontReplicate: boolean?)
		return self._server:set(player, path, value, dontReplicate)
	end

	function def:Update(player: Player, path: any, callback: (any) -> any, dontReplicate: boolean?): any
		return self._server:update(player, path, callback, dontReplicate)
	end

	function def:ArrayInsert(player: Player, path: any, value: any, index: number?, dontReplicate: boolean?)
		return self._server:arrayInsert(player, path, value, index, dontReplicate)
	end

	function def:ArrayRemove(player: Player, path: any, index: number, dontReplicate: boolean?): any
		return self._server:arrayRemove(player, path, index, dontReplicate)
	end

	function def:GetChangedSignal(player: Player, path: any): any
		return self._server:getChangedSignal(player, path)
	end

	function def:GetIndexChangedSignal(player: Player, path: any): any
		return self._server:getIndexChangedSignal(player, path)
	end

	function def:GetArrayInsertedSignal(player: Player, path: any): any
		return self._server:getArrayInsertedSignal(player, path)
	end

	function def:GetArrayRemovedSignal(player: Player, path: any): any
		return self._server:getArrayRemovedSignal(player, path)
	end

	function def:AddGlobalCallback(key: string, callback: (player: Player, data: { any }) -> boolean?)
		return self._server:addGlobalCallback(key, callback)
	end

	function def:SendGlobalMessage(key: string, userId: number | string, data: { any }): boolean
		return self._server:sendGlobalMessage(key, userId, data)
	end

	function def:AddPlayerRemovingCallback(fn: (player: Player, data: any) -> ()): () -> ()
		return self._server:addPlayerRemovingCallback(fn)
	end

	function def:ResetData(player: Player)
		return self._server:resetData(player)
	end

	return def :: ServerClass
end

--[=[
	Wraps the `DataService.client` singleton in a framework `Controller`.
	`Init` assigns `_client` and calls `bind()` so replication listeners
	are live before any `Start` hook runs. `Start` calls `init()`, which
	yields until the snapshot arrives (via `Init` event or `Fetch` pull).

	Controllers that read data should:
	  1. List `Dependencies = { "DataController" }`.
	  2. Call `:WaitForData()` early in their own `Start` to be sure
	     the snapshot has arrived before they touch values.
]=]
function Data.CreateController(options: ClientOptions?): ClientClass
	local opts: ClientOptions = options or {}
	local name = opts.Name or "DataController"

	local def: any = Controller.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	})

	function def:Init()
		if not RunService:IsClient() then
			return
		end
		local client = DataPackage.client
		self._client = client
		-- Subscribe before `Start` so a server `Init` fired during boot is not lost.
		client:bind()
	end

	function def:Start()
		if not RunService:IsClient() then
			return
		end
		self._client:init()
	end

	function def:Client(): any
		return self._client
	end

	function def:WaitForData(): any
		return self._client:waitForData()
	end

	function def:Get(path: any?): any
		return self._client:get(path)
	end

	function def:Set(path: any, value: any)
		return self._client:set(path, value)
	end

	function def:Update(path: any, callback: (any) -> any): any
		return self._client:update(path, callback)
	end

	function def:ArrayInsert(path: any, value: any, index: number?)
		return self._client:arrayInsert(path, value, index)
	end

	function def:ArrayRemove(path: any, index: number): any
		return self._client:arrayRemove(path, index)
	end

	function def:Fetch(path: any?, dontSet: boolean?): any
		return self._client:fetch(path, dontSet)
	end

	function def:GetChangedSignal(path: any): any
		return self._client:getChangedSignal(path)
	end

	function def:GetIndexChangedSignal(path: any): any
		return self._client:getIndexChangedSignal(path)
	end

	function def:GetArrayInsertedSignal(path: any): any
		return self._client:getArrayInsertedSignal(path)
	end

	function def:GetArrayRemovedSignal(path: any): any
		return self._client:getArrayRemovedSignal(path)
	end

	return def :: ClientClass
end

return Data
