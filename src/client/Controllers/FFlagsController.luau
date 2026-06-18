--!strict
--[=[
	@controller FFlagsController
	Read-only client cache for server-owned FFlags.

	Usage:
	```lua
	local FFlags = require(StarterPlayerScripts.Client.Controllers.FFlagsController)

	FFlags:WaitForReady()
	if FFlags:Get("DoubleXP") == true then
	    -- update UI
	end
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))

export type Class = Atlas.FFlagsControllerClass

local FFlagsController: Class = Atlas.CreateFFlagsController({
	Name = "FFlagsController",
})

return FFlagsController
