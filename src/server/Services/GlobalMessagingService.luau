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

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))

export type Class = Atlas.GlobalMessagingServiceClass

local GlobalMessagingService: Class = Atlas.CreateGlobalMessagingService({
	Name = "GlobalMessagingService",
})

return GlobalMessagingService
