--!nocheck
--[=[
	@service GlobalMessagingService
	Boots framework cross-server messaging on the server. Other services can
	`Dependencies = { "GlobalMessagingService" }` and subscribe in their own
	`Init` after this service is live.

	Usage:
	```lua
	local GlobalMessaging = require(ServerScriptService.Server.Services.GlobalMessagingService)

	GlobalMessaging:Subscribe("announcement", function(message)
	    print(message.Data, message.Sent)
	end)

	GlobalMessaging:Publish("announcement", { text = "Hello from another server" })
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

export type Class = Framework.GlobalMessagingServiceClass

local GlobalMessagingService: Class = Framework.CreateGlobalMessagingService({
	Name = "GlobalMessagingService",
})

return GlobalMessagingService
