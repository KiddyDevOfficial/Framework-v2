--!strict
--[=[
	@controller GuiButtonController
	Auto-binds every `GuiButton` under `PlayerGui` tagged `Button` via
	CollectionService. New tagged buttons are picked up at runtime.

	Owns a `Framework.Util.Sound` handler pointed at `SoundService.GuiSounds`
	and routes every button's hover / click through it (resolved by name -
	`Hover` / `Click`), so presses clone instead of cutting themselves off and
	UI audio can be volume-controlled / muted via `GuiButtonController.Sounds`.

	Studio: add the `Button` tag to any `GuiButton`. Optional `SizeFactor`
	attribute (number) per button. Put `Click` / `Hover` `Sound`s under a
	`SoundService.GuiSounds` folder.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local GuiButton = Framework.Util.GuiButton
local Sound = Framework.Util.Sound

local GUI_SOUNDS_FOLDER = "GuiSounds"

local GuiButtonController = {}

GuiButtonController._trove = nil :: Framework.Trove?
-- The sound handler UI buttons play through; assign volume / mute on it.
GuiButtonController.Sounds = nil :: Framework.SoundPlayer?

function GuiButtonController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local sounds = Sound.new()
	local guiSounds = SoundService:FindFirstChild(GUI_SOUNDS_FOLDER)
	if guiSounds then
		sounds:setLibrary(guiSounds)
	end
	self.Sounds = sounds

	self._trove = GuiButton.bindIn(playerGui, { soundPlayer = sounds })
end

function GuiButtonController:Stop()
	if self._trove then
		self._trove:destroy()
		self._trove = nil
	end
	if self.Sounds then
		self.Sounds:destroy()
		self.Sounds = nil
	end
end

return GuiButtonController
