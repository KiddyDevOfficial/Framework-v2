--!strict
--[=[
	@module ExampleGlobalNet
	Starter shared GlobalMessaging bank — one place defines cross-server
	topics; every server requires this module for typed handles. Copy or
	delete when you add your own banks.

	Requires `GlobalMessagingService` (or `GlobalMessaging.server:init()`) to
	be live before `:Publish` / `:Subscribe`.

	```lua
	local Net = require(ReplicatedStorage.Shared.Messaging.ExampleGlobalNet)
	Net.Gift:Publish({ userId = 123, amount = 100 })
	Net.Gift:Subscribe(function(message) ... end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local GlobalMessaging = Framework.GlobalMessaging

local Bank = GlobalMessaging.Bank("Example")

export type GiftPayload = {
	userId: number,
	amount: number,
}

export type AnnouncementPayload = {
	text: string,
	fromJobId: string?,
}

return {
	Gift = Bank:Event("Gift") :: Framework.GlobalMessageTopic<GiftPayload>,
	Announcement = Bank:Event("Announcement") :: Framework.GlobalMessageTopic<AnnouncementPayload>,
}
