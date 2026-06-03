--!strict
--[=[
	@module FFlags
	Default global runtime flags. These are loaded locally on every server by
	`FFlagsService`; runtime changes propagate across live servers through
	`GlobalMessaging`.
]=]

local FFlags = {
	DoubleXP = false,
	MaintenanceMode = false,
	EventMultiplier = 1,
	MessageOfTheDay = "",
}

export type FFlags = typeof(FFlags)

return FFlags
