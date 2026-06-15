--!strict
--[=[
	@module Adapters.GlobalMessaging
	Wires the cross-server [MessagingService] package into a framework service.
	https://create.roblox.com/docs/reference/engine/classes/MessagingService

	```lua
	return Framework.CreateGlobalMessagingService({ Name = "GlobalMessagingService" })
	```
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local GlobalMessagingPackage = require(script.Parent.Parent.GlobalMessaging)
local GlobalMessagingTypes = require(script.Parent.Parent.GlobalMessaging.Types)

local GlobalMessagingAdapter = {}

export type ServerOptions = {
	Name: string?,
	Dependencies: { string }?,
	TopicPrefix: string?,
}


export type ServiceClass = {
	Server: (self: ServiceClass) -> GlobalMessagingTypes.ServerClass,
	Subscribe: (self: ServiceClass, topic: string, handler: GlobalMessagingTypes.MessageHandler) -> () -> (),
	Unsubscribe: (self: ServiceClass, topic: string) -> (),
	Publish: (self: ServiceClass, topic: string, data: any) -> boolean,
	ResolveTopic: (self: ServiceClass, topic: string) -> string,
	IsSubscribed: (self: ServiceClass, topic: string) -> boolean,
}

function GlobalMessagingAdapter.CreateService(options: ServerOptions?): ServiceClass
	local opts: ServerOptions = options or {}
	local name = opts.Name or "GlobalMessagingService"

	local def: any = Service.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	})

	function def:Init()
		if not RunService:IsServer() then
			return
		end

		local server = GlobalMessagingPackage.server
		server:init({
			TopicPrefix = opts.TopicPrefix,
		})
		self._server = server
	end

	function def:Stop()
		if self._server then
			self._server:destroy()
			self._server = nil
		end
	end

	function def:Server(): GlobalMessagingTypes.ServerClass
		return self._server
	end

	function def:Subscribe(topic: string, handler: GlobalMessagingTypes.MessageHandler): () -> ()
		return self._server:subscribe(topic, handler)
	end

	function def:Unsubscribe(topic: string)
		return self._server:unsubscribe(topic)
	end

	function def:Publish(topic: string, data: any): boolean
		return self._server:publish(topic, data)
	end

	function def:ResolveTopic(topic: string): string
		return self._server:resolveTopic(topic)
	end

	function def:IsSubscribed(topic: string): boolean
		return self._server:isSubscribed(topic)
	end

	return def :: ServiceClass
end

return GlobalMessagingAdapter
