--!strict
--[=[
	@module GlobalMessaging.Topic
	Typed cross-server topic (one MessagingService subscription). Declare as
	`GlobalMessaging.Topic<MyArgs>` on a bank packet for typed
	`:Publish` / `:Subscribe` / `:OnMessage`.
]=]

local RunService = game:GetService("RunService")

local Server = require(script.Parent.Server)
local Manager = require(script.Parent.Manager)
local Types = require(script.Parent.Types)

local function assertServer(api: string)
	assert(RunService:IsServer(), `[Framework.GlobalMessaging] {api} is server-only`)
end

local Topic = {}
Topic.__index = Topic

export type Message<Args> = {
	Data: Args,
	Sent: number,
}

export type Topic<Args> = {
	Name: string,
	Bank: string,
	_relativeTopic: string,
	ResolveTopic: (self: Topic<Args>) -> string,
	Publish: (self: Topic<Args>, args: Args) -> boolean,
	Subscribe: (self: Topic<Args>, handler: (message: Message<Args>) -> ()) -> () -> (),
	OnMessage: (self: Topic<Args>, handler: (message: Message<Args>) -> ()) -> () -> (),
	Unsubscribe: (self: Topic<Args>) -> (),
	IsSubscribed: (self: Topic<Args>) -> boolean,
}

function Topic.new<Args>(bankName: string, eventName: string): Topic<Args>
	local relative = Manager.buildRelativeTopic(bankName, eventName)
	Manager.resolveTopic(bankName, eventName)

	local self = setmetatable({
		Name = eventName,
		Bank = bankName,
		_relativeTopic = relative,
	}, Topic)
	return self :: any
end

function Topic.ResolveTopic<Args>(self: Topic<Args>): string
	return Manager.resolveTopic(self.Bank, self.Name)
end

local function wrapHandler<Args>(handler: (message: Message<Args>) -> ()): Types.MessageHandler
	return function(message: Types.Message)
		handler({
			Data = message.Data :: Args,
			Sent = message.Sent,
		})
	end
end

function Topic.Publish<Args>(self: Topic<Args>, args: Args): boolean
	assertServer("Topic:Publish")
	return Server:publish(self._relativeTopic, args)
end

function Topic.Subscribe<Args>(self: Topic<Args>, handler: (message: Message<Args>) -> ()): () -> ()
	assertServer("Topic:Subscribe")
	return Server:subscribe(self._relativeTopic, wrapHandler(handler))
end

function Topic.OnMessage<Args>(self: Topic<Args>, handler: (message: Message<Args>) -> ()): () -> ()
	return self:Subscribe(handler)
end

function Topic.Unsubscribe<Args>(self: Topic<Args>)
	Server:unsubscribe(self._relativeTopic)
end

function Topic.IsSubscribed<Args>(self: Topic<Args>): boolean
	return Server:isSubscribed(self._relativeTopic)
end

return Topic
