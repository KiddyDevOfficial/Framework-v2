--!strict
--[=[
	@module GlobalMessaging
	Cross-server messaging over Roblox [MessagingService] (server-only).
	https://create.roblox.com/docs/reference/engine/classes/MessagingService

	**Banks** (recommended — mirrors `Networking.Bank`):

	```lua
	-- src/shared/Messaging/ExampleGlobalNet.luau
	local GlobalMessaging = require(ReplicatedStorage.Framework).GlobalMessaging
	local Bank = GlobalMessaging.Bank("Example")

	return {
	    Gift = Bank:Event("Gift") :: GlobalMessaging.Topic<GiftPayload>,
	}
	```

	```lua
	local Net = require(ReplicatedStorage.Shared.Messaging.ExampleGlobalNet)
	Net.Gift:Subscribe(function(message)
	    print(message.Data, message.Sent)
	end)
	Net.Gift:Publish({ userId = 123, amount = 50 })
	```

	Low-level API (`GlobalMessaging.server`) remains available for ad-hoc topics.
]=]

local Server = require(script.Server)
local Bank = require(script.Bank)
local Topic = require(script.Topic)
local Types = require(script.Types)

export type Server = Types.ServerClass
export type ServerClass = Types.ServerClass
export type Message = Types.Message
export type MessageHandler = Types.MessageHandler
export type InitOptions = Types.InitOptions
export type Bank = Bank.Bank
export type Topic<Args> = Topic.Topic<Args>
export type TopicMessage<Args> = Topic.Message<Args>

local GlobalMessaging = {
	server = Server :: Types.ServerClass,
	Bank = Bank.new,
}

return GlobalMessaging
