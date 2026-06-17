--!strict
--[=[
	@module FrameController
	Opens and closes frames under `PlayerGui/Frames`. Animation presets live in
	`UI/Lib/FrameStyles`; per-frame interaction can live in `UI/Frames/*`.
	Only one frame stays open at a time.

	```lua
	local Frames = require(StarterPlayerScripts.Client.UI.Controllers.FrameController)
	Frames:Open("Example")
	```
]=]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Framework = require(ReplicatedStorage.Framework)
local Signal = Framework.Signal
local FrameStyles = require(script.Parent.Parent.Lib.FrameStyles)

local MENU_FOV_ATTR = "_MenuFOVActive"
local STYLE_ATTRIBUTE = "AnimateStyle"
local DEFAULT_STYLE = "default"

local FrameController = {
	Dependencies = {} :: { string },

	_frames = {} :: { [string]: GuiObject },
	_restSizes = {} :: { [string]: UDim2 },
	_restPositions = {} :: { [string]: UDim2 },
	_styles = {} :: { [string]: string },
	_tweens = {} :: { [GuiObject]: { Tween } },
	_targets = {} :: { [string]: boolean },
	_openName = nil :: string?,
	_blur = nil :: BlurEffect?,
	_camera = nil :: Camera?,
	_defaultFov = 70,

	Opened = Signal.new() :: Framework.Signal<string>,
	Closed = Signal.new() :: Framework.Signal<string>,
}

export type Class = {
	Opened: Framework.Signal<string>,
	Closed: Framework.Signal<string>,
	Get: (self: Class, name: string) -> GuiObject?,
	IsOpen: (self: Class, name: string) -> boolean,
	Open: (self: Class, name: string) -> (),
	Close: (self: Class, name: string) -> (),
	Toggle: (self: Class, name: string) -> (),
	CloseAll: (self: Class, except: string?) -> (),
}

function FrameController:_cancelTweens(frame: GuiObject?)
	if frame then
		local existing = self._tweens[frame]
		if existing then
			for _, tween in existing do
				tween:Cancel()
			end
			self._tweens[frame] = nil
		end
		return
	end

	for _, tweens in self._tweens do
		for _, tween in tweens do
			tween:Cancel()
		end
	end
	table.clear(self._tweens)
end

-- One open/close can start motion and effects tweens separately; keep them grouped.
function FrameController:_trackTweens(frame: GuiObject, tweens: { Tween }, onComplete: ((Enum.PlaybackState) -> ())?)
	local list = self._tweens[frame]
	if not list then
		list = {}
		self._tweens[frame] = list
	end
	for _, tween in tweens do
		table.insert(list, tween)
		tween:Play()
	end
	if onComplete and #tweens > 0 then
		tweens[1].Completed:Once(onComplete)
	end
end

function FrameController:_snapClosed(name: string)
	local frame = self._frames[name]
	if not frame then
		return
	end

	self:_cancelTweens(frame)
	self._targets[name] = false
	if self._openName == name then
		self._openName = nil
	end

	frame.Position = self._restPositions[name]
	frame.Size = self._restSizes[name]
	frame.Visible = false
end

function FrameController:_closeOthersForOpen(name: string)
	for other, frame in self._frames do
		if other == name then
			continue
		end
		if self._targets[other] or frame.Visible then
			self:_snapClosed(other)
			self.Closed:fire(other)
		end
	end
end

function FrameController:_setMenuEffects(active: boolean)
	if self._camera then
		self._camera:SetAttribute(MENU_FOV_ATTR, active)
	end
end

function FrameController:_resetEffects()
	if self._camera then
		self._camera.FieldOfView = self._defaultFov
	end
	if self._blur then
		self._blur.Size = 0
	end
	self:_setMenuEffects(false)
end

function FrameController:_readStyle(frame: GuiObject): string
	local raw = frame:GetAttribute(STYLE_ATTRIBUTE)
	if type(raw) == "string" and raw ~= "" then
		return raw
	end
	return DEFAULT_STYLE
end

function FrameController:_makeContext(
	frame: GuiObject,
	name: string,
	applyEffects: boolean,
	onComplete: ((Enum.PlaybackState) -> ())?
): FrameStyles.AnimContext
	-- Post-close hide belongs to the frame tween, not the shorter effects tweens.
	local completeUsed = false
	local play = function(tweens: { Tween }, complete: ((Enum.PlaybackState) -> ())?)
		local cb = complete
		if not cb and onComplete and not completeUsed then
			cb = onComplete
			completeUsed = true
		end
		self:_trackTweens(frame, tweens, cb)
	end

	return {
		frame = frame,
		defaultSize = self._restSizes[name],
		defaultPos = self._restPositions[name],
		camera = self._camera :: Camera,
		blur = self._blur :: BlurEffect,
		defaultFov = self._defaultFov,
		applyEffects = applyEffects,
		play = play,
	}
end

function FrameController:_register(frame: GuiObject)
	local name = frame.Name
	if self._frames[name] then
		return
	end

	self._frames[name] = frame
	self._restSizes[name] = frame.Size
	self._restPositions[name] = frame.Position
	self._styles[name] = self:_readStyle(frame)
	self._targets[name] = false
	frame.Visible = false
end

function FrameController:Get(name: string): GuiObject?
	return self._frames[name]
end

function FrameController:IsOpen(name: string): boolean
	return self._targets[name] == true
end

function FrameController:Open(name: string)
	local frame = self._frames[name]
	if not frame then
		warn(`[FrameController] Open: no frame named '{name}' under PlayerGui/Frames`)
		return
	end

	self:_closeOthersForOpen(name)

	if self._targets[name] then
		return
	end

	self._targets[name] = true
	self._openName = name
	self:_cancelTweens(frame)

	frame.Visible = true
	self:_setMenuEffects(true)

	local style = FrameStyles.get(self._styles[name])
	style.OnPop(self:_makeContext(frame, name, true, nil))

	self.Opened:fire(name)
end

function FrameController:Close(name: string, keepEffects: boolean?)
	local frame = self._frames[name]
	if not frame or not self._targets[name] then
		return
	end

	self._targets[name] = false
	if self._openName == name then
		self._openName = nil
	end

	self:_cancelTweens(frame)

	local style = FrameStyles.get(self._styles[name])
	style.UnPop(self:_makeContext(frame, name, keepEffects ~= true, function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end
		if self._targets[name] or self._openName ~= nil then
			return
		end
		frame.Visible = false
	end))

	if keepEffects ~= true and self._openName == nil then
		self:_setMenuEffects(false)
	end

	self.Closed:fire(name)
end

function FrameController:Toggle(name: string)
	if self:IsOpen(name) then
		self:Close(name)
	else
		self:Open(name)
	end
end

function FrameController:CloseAll(except: string?)
	for frameName, isOpen in self._targets do
		if isOpen and frameName ~= except then
			self:Close(frameName)
		end
	end
end

function FrameController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local framesRoot = playerGui:WaitForChild("Frames")

	self._camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera
	self._defaultFov = self._camera.FieldOfView

	local blur = Lighting:FindFirstChild("_FrameworkMenuBlur")
	if blur and blur:IsA("BlurEffect") then
		self._blur = blur
	else
		local created = Instance.new("BlurEffect")
		created.Name = "_FrameworkMenuBlur"
		created.Size = 0
		created.Parent = Lighting
		self._blur = created
	end

	for _, child in framesRoot:GetChildren() do
		if child:IsA("GuiObject") then
			self:_register(child)
		end
	end

	framesRoot.ChildAdded:Connect(function(child)
		if child:IsA("GuiObject") then
			self:_register(child)
		end
	end)

	framesRoot.ChildRemoved:Connect(function(child)
		local frameName = child.Name
		if self._frames[frameName] == child then
			self._frames[frameName] = nil
			self._restSizes[frameName] = nil
			self._restPositions[frameName] = nil
			self._styles[frameName] = nil
			self._targets[frameName] = nil
			if self._openName == frameName then
				self._openName = nil
				self:_cancelTweens()
				self:_resetEffects()
			end
		end
	end)
end

function FrameController:Stop()
	self:_cancelTweens()
	self:_resetEffects()
	self.Opened:destroy()
	self.Closed:destroy()
end

return FrameController :: Class
