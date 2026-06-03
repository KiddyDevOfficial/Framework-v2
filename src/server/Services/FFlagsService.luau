--!nocheck
--[=[
	@service FFlagsService
	Boots global runtime flags and keeps live servers synchronized through
	`GlobalMessagingService`.

	Usage:
	```lua
	local FFlags = require(ServerScriptService.Server.Services.FFlagsService)

	if FFlags:GetBoolean("DoubleXP") then
	    -- award double XP
	end

	FFlags:Set("MaintenanceMode", true) -- propagates across live servers
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local Defaults = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FFlags"))

export type Class = Framework.FFlagsServiceClass

local FFlagsService: Class = Framework.CreateFFlagsService({
	Name = "FFlagsService",
	Defaults = Defaults,
})

return FFlagsService
