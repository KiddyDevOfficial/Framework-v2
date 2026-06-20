--!strict
--[=[
	@module Analytics
	Crash-proof wrapper around Roblox `AnalyticsService` for economy,
	progression, funnel, onboarding, and custom telemetry events. Server-only:
	`AnalyticsService` logging is rejected on the client.

	```lua
	local Analytics = require(ReplicatedStorage.Atlas).Analytics.server
	Analytics:init()

	Analytics:logEconomyEvent(player, {
	    flowType = "Sink",
	    currencyType = "Coins",
	    amount = 100,
	    endingBalance = 400,
	    transactionType = "Shop",
	    itemSku = "SwordOfTruth",
	})
	```

	Prefer the Atlas adapter when wiring it into the loader:

	```lua
	return Atlas.CreateAnalyticsService({ Name = "AnalyticsService" })
	```
]=]

local Server = require(script.Server)
local Types = require(script.Types)

export type Server = Types.ServerClass
export type ServerClass = Types.ServerClass
export type EconomyEvent = Types.EconomyEvent
export type ProgressionEvent = Types.ProgressionEvent
export type FunnelStep = Types.FunnelStep
export type OnboardingStep = Types.OnboardingStep
export type CustomEvent = Types.CustomEvent
export type EconomyFlow = Types.EconomyFlow
export type TransactionType = Types.TransactionType
export type ProgressionStatus = Types.ProgressionStatus
export type CustomFields = Types.CustomFields
export type InitOptions = Types.InitOptions

return {
	server = Server :: Types.ServerClass,
}
