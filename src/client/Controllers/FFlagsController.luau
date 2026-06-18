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

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))

export type Class = Weave.FFlagsControllerClass

local FFlagsController: Class = Weave.CreateFFlagsController({
	Name = "FFlagsController",
})

return FFlagsController
