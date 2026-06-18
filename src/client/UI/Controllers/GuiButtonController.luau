--!strict
--[=[
	@controller GuiButtonController
	Auto-binds tagged `GuiButton`s under `PlayerGui`. New tagged buttons are
	picked up at runtime.

	Button hover/click sounds are resolved by name from `SoundService.GuiSounds`
	through a shared `Atlas.Util.Sound` handler.

	Studio setup: tag buttons with `Button`, optionally set `SizeFactor`, and
	put `Click` / `Hover` sounds under `SoundService.GuiSounds`.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))
local GuiButton = Atlas.Util.GuiButton
local Sound = Atlas.Util.Sound

local GUI_SOUNDS_FOLDER = "GuiSounds"

local GuiButtonController = {}

GuiButtonController._trove = nil :: Atlas.Trove?
GuiButtonController.Sounds = nil :: Atlas.SoundPlayer?

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
