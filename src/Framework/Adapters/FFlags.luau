--!strict
--[=[
	@module Adapters.FFlags
	Framework service binding for global runtime flags synchronized through
	`GlobalMessaging`.
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local Controller = require(script.Parent.Parent.Modular.Controller)
local FFlagsPackage = require(script.Parent.Parent.FFlags)
local FFlagsTypes = require(script.Parent.Parent.FFlags.Types)

local FFlagsAdapter = {}

export type ServerOptions = {
	Name: string?,
	Dependencies: { string }?,
	Defaults: { [string]: FFlagsTypes.FlagValue }?,
}

export type ClientOptions = {
	Name: string?,
	Dependencies: { string }?,
}

export type ServiceClass = {
	Server: (self: ServiceClass) -> FFlagsTypes.ServerClass,
	Get: (self: ServiceClass, name: string, defaultValue: FFlagsTypes.FlagValue?) -> FFlagsTypes.FlagValue?,
	GetAll: (self: ServiceClass) -> { [string]: FFlagsTypes.FlagValue },
	Set: (self: ServiceClass, name: string, value: FFlagsTypes.FlagValue) -> boolean,
	SetLocal: (self: ServiceClass, name: string, value: FFlagsTypes.FlagValue) -> (),
	Remove: (self: ServiceClass, name: string) -> boolean,
	RemoveLocal: (self: ServiceClass, name: string) -> (),
	Observe: (self: ServiceClass, name: string, handler: FFlagsTypes.ChangeHandler) -> () -> (),
	Changed: any,
}

export type ControllerClass = {
	Client: (self: ControllerClass) -> FFlagsTypes.ClientClass,
	WaitForReady: (self: ControllerClass) -> (),
	IsReady: (self: ControllerClass) -> boolean,
	Get: (self: ControllerClass, name: string, defaultValue: FFlagsTypes.FlagValue?) -> FFlagsTypes.FlagValue?,
	GetAll: (self: ControllerClass) -> { [string]: FFlagsTypes.FlagValue },
	Observe: (self: ControllerClass, name: string, handler: FFlagsTypes.ChangeHandler) -> () -> (),
	Changed: any,
}

function FFlagsAdapter.CreateService(options: ServerOptions?): ServiceClass
	local opts: ServerOptions = options or {}
	local name = opts.Name or "FFlagsService"
	local dependencies = opts.Dependencies or { "GlobalMessagingService" }

	local def: any = Service.Create({
		Name = name,
		Dependencies = dependencies,
	})

	function def:Init()
		if not RunService:IsServer() then
			return
		end

		local server = FFlagsPackage.server
		server:init({
			Defaults = opts.Defaults,
		})
		self._server = server
		self.Changed = server.Changed
	end

	function def:Stop()
		if self._server then
			self._server:destroy()
			self._server = nil
		end
	end

	function def:Server(): FFlagsTypes.ServerClass
		return self._server
	end

	function def:Get(name: string, defaultValue: FFlagsTypes.FlagValue?): FFlagsTypes.FlagValue?
		return self._server:get(name, defaultValue)
	end

	function def:GetAll(): { [string]: FFlagsTypes.FlagValue }
		return self._server:getAll()
	end

	function def:Set(name: string, value: FFlagsTypes.FlagValue): boolean
		return self._server:set(name, value)
	end

	function def:SetLocal(name: string, value: FFlagsTypes.FlagValue)
		return self._server:setLocal(name, value, "local")
	end

	function def:Remove(name: string): boolean
		return self._server:remove(name)
	end

	function def:RemoveLocal(name: string)
		return self._server:removeLocal(name, "local")
	end

	function def:Observe(name: string, handler: FFlagsTypes.ChangeHandler): () -> ()
		return self._server:observe(name, handler)
	end

	return def :: ServiceClass
end

function FFlagsAdapter.CreateController(options: ClientOptions?): ControllerClass
	local opts: ClientOptions = options or {}
	local name = opts.Name or "FFlagsController"

	local def: any = Controller.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	})

	function def:Init()
		if not RunService:IsClient() then
			return
		end
		self._client = FFlagsPackage.client
		self.Changed = self._client.Changed
	end

	function def:Start()
		if not RunService:IsClient() then
			return
		end
		self._client:init()
	end

	function def:Stop()
		if self._client then
			self._client:destroy()
			self._client = nil
		end
	end

	function def:Client(): FFlagsTypes.ClientClass
		return self._client
	end

	function def:WaitForReady()
		return self._client:waitForReady()
	end

	function def:IsReady(): boolean
		return self._client:isReady()
	end

	function def:Get(name: string, defaultValue: FFlagsTypes.FlagValue?): FFlagsTypes.FlagValue?
		return self._client:get(name, defaultValue)
	end

	function def:GetAll(): { [string]: FFlagsTypes.FlagValue }
		return self._client:getAll()
	end

	function def:Observe(name: string, handler: FFlagsTypes.ChangeHandler): () -> ()
		return self._client:observe(name, handler)
	end

	return def :: ControllerClass
end

return FFlagsAdapter
