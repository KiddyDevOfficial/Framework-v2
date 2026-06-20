--!strict
--[=[
	@service AnalyticsService
	Boots the Atlas `AnalyticsService` wrapper: a crash-proof layer over Roblox
	`AnalyticsService` for economy, progression, funnel, onboarding, and custom
	telemetry events. Every log call is wrapped in `pcall` and returns whether
	it landed, so telemetry failures never propagate into gameplay.

	Usage (typed via direct require):
	```lua
	local Analytics = require(ServerScriptService.Server.Services.AnalyticsService)

	Analytics:LogEconomyEvent(player, {
		flowType = "Sink",	-- or Enum.AnalyticsEconomyFlowType.Sink
		currencyType = "Coins",
		amount = 100,
		endingBalance = 400,
		transactionType = "Shop",     
		itemSku = "SwordOfTruth",
	})

	Analytics:LogProgressionEvent(player, {
		path = "Tutorial",
		status = "Complete",         
		level = 1,
	})
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))

export type Class = Atlas.AnalyticsServiceClass

local AnalyticsService: Class = Atlas.CreateAnalyticsService({
	Name = "AnalyticsService",
})

return AnalyticsService
