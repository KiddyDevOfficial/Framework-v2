--!strict
--[=[
	@controller ExampleFrame
	Starter per-frame GUI module for `PlayerGui/Frames/Example`. Return a
	plain table; the Loader registers it by its ModuleScript name. Delete or
	copy this file for each frame under `PlayerGui/Frames`.

	Studio:
	  PlayerGui/Frames/Example

	Button wiring (optional attributes on any `GuiButton`):
	  `FrameTarget = "Example"`, `FrameAction = "Toggle" | "Open" | "Close"`

	Hover/click tweens: CollectionService tag `Button` on buttons.
]=]

local Players = game:GetService("Players")

local FrameController = require(script.Parent.Parent.Controllers.FrameController)
local FrameUtil = require(script.Parent.Parent.Lib.FrameUtil)

local FRAME_NAME = ""

local ExampleFrame = {
	Dependencies = { "FrameController", "GuiButtonController" },
}

function ExampleFrame:Start()
	--[[ Run down the frame wiring.
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	FrameUtil.getFrame(playerGui, FRAME_NAME)
	FrameUtil.wireAttributed(playerGui, FrameController, FRAME_NAME)
	]]
end

return ExampleFrame
