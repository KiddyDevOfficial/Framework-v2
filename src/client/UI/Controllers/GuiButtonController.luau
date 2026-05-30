--!strict
--[=[
	@controller GuiButtonController
	Auto-binds every `GuiButton` under `PlayerGui` tagged `Button` via
	CollectionService. New tagged buttons are picked up at runtime.

	Studio: add the `Button` tag to any `GuiButton`. Optional `SizeFactor`
	attribute (number) per button.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local GuiButton = Framework.Util.GuiButton

local GuiButtonController = {}

GuiButtonController._trove = nil :: Framework.Trove?

function GuiButtonController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	self._trove = GuiButton.bindIn(playerGui)
end

function GuiButtonController:Stop()
	if self._trove then
		self._trove:destroy()
		self._trove = nil
	end
end

return GuiButtonController
