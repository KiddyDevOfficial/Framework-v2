--!strict
--[=[
	@controller GuiButtonController
	Auto-binds tagged `GuiButton`s under `PlayerGui`. New tagged buttons are
	picked up at runtime.

	Button hover/click sounds are resolved by name from `SoundService.GuiSounds`
	through a shared `Weave.Util.Sound` handler.

	Studio setup: tag buttons with `Button`, optionally set `SizeFactor`, and
	put `Click` / `Hover` sounds under `SoundService.GuiSounds`.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local GuiButton = Weave.Util.GuiButton
local Sound = Weave.Util.Sound

local GUI_SOUNDS_FOLDER = "GuiSounds"

local GuiButtonController = {}

GuiButtonController._trove = nil :: Weave.Trove?
GuiButtonController.Sounds = nil :: Weave.SoundPlayer?

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
