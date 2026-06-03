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

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

export type Class = Framework.FFlagsControllerClass

local FFlagsController: Class = Framework.CreateFFlagsController({
	Name = "FFlagsController",
})

return FFlagsController
