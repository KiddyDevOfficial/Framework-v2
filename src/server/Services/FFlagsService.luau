--!nocheck
--[=[
	@service FFlagsService
	Boots global runtime flags and keeps live servers synchronized through
	`GlobalMessagingService`.

	Usage:
	```lua
	local FFlags = require(ServerScriptService.Server.Services.FFlagsService)

	if FFlags:Get("DoubleXP") == true then
	    -- award double XP
	end

	FFlags:Set("MaintenanceMode", true) -- propagates across live servers
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))
local Defaults = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FFlags"))

export type Class = Atlas.FFlagsServiceClass

local FFlagsService: Class = Atlas.CreateFFlagsService({
	Name = "FFlagsService",
	Defaults = Defaults,
})

return FFlagsService
