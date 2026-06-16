--!strict
--[=[
	@module Util.DebugOverlay
	A tiny on-screen debug HUD: frame rate / frame time (with the window's worst
	frame) and remote-traffic rate pulled from `Networking.Stats`. Client-only;
	the GUI is built lazily the first time it's shown. While visible it enables
	`Networking.Stats` (and turns it back off on hide if it switched it on), so
	you only pay for counting when you're looking.

	Gate it behind an FFlag so you can flip the overlay on for a live session
	without shipping a build:

	```lua
	local DebugOverlay = Framework.DebugOverlay

	local overlay = DebugOverlay.new()
	overlay:bindFFlag(Framework.FFlags.client, "ShowDebugOverlay")
	-- ...or drive it yourself:
	-- overlay:toggle()  (e.g. bound to F3 through Framework.Input)

	overlay:destroy()
	```
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Stats = require(script.Parent.Parent.Networking.Stats)
local Trove = require(script.Parent.Trove)

local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

export type Options = {
	-- Seconds between label refreshes (and the network-rate window). Default 0.5.
	refreshInterval: number?,
	-- Where the panel sits. Default top-left under the inset.
	position: UDim2?,
}

export type Overlay = {
	show: (self: Overlay) -> (),
	hide: (self: Overlay) -> (),
	toggle: (self: Overlay) -> (),
	setVisible: (self: Overlay, visible: boolean) -> (),
	isVisible: (self: Overlay) -> boolean,
	bindFFlag: (
		self: Overlay,
		fflags: { observe: (any, string, (...any) -> ()) -> () -> () },
		flagName: string
	) -> () -> (),
	destroy: (self: Overlay) -> (),
}

--[=[
	New overlay. Nothing is drawn until `:show()` / `:setVisible(true)`.
]=]
function DebugOverlay.new(options: Options?): Overlay
	local opts: Options = options or {}
	local self = setmetatable({
		_interval = opts.refreshInterval or 0.5,
		_position = opts.position or UDim2.fromOffset(8, 8),
		_visible = false,
		_gui = nil :: ScreenGui?,
		_label = nil :: TextLabel?,
		_frames = 0,
		_accum = 0,
		_worstDt = 0,
		_enabledStats = false,
		_trove = Trove.new(),
		_runtime = Trove.new(),
	}, DebugOverlay)
	return self :: any
end

local function ensureGui(self: any)
	if self._gui then
		return
	end
	if not RunService:IsClient() then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "_FrameworkDebugOverlay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1_000_000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.zero
	frame.Position = self._position
	frame.Size = UDim2.fromOffset(220, 44)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.FontFace = Font.fromEnum(Enum.Font.Code)
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "…"
	label.Parent = frame

	self._gui = gui
	self._label = label
	self._trove:add(gui)
end

local function refresh(self: any, elapsed: number)
	local label: TextLabel = self._label
	if not label then
		return
	end
	local fps = self._frames / elapsed
	local avgMs = (elapsed / self._frames) * 1000
	local worstMs = self._worstDt * 1000

	local snap = Stats.snapshot()
	local outPerSec = snap.outgoing / elapsed
	local inPerSec = snap.incoming / elapsed
	Stats.reset()

	label.Text = string.format(
		"FPS %d  (%.1f ms, peak %.1f)\nNet  up %d/s   down %d/s",
		math.floor(fps + 0.5),
		avgMs,
		worstMs,
		math.floor(outPerSec + 0.5),
		math.floor(inPerSec + 0.5)
	)

	self._frames = 0
	self._accum = 0
	self._worstDt = 0
end

function DebugOverlay.setVisible(self: Overlay, visible: boolean)
	local s: any = self
	if s._visible == visible then
		return
	end
	s._visible = visible

	if visible then
		ensureGui(s)
		if s._gui then
			s._gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		end
		if not Stats.isEnabled() then
			Stats.setEnabled(true)
			s._enabledStats = true
		end
		Stats.reset()
		s._frames = 0
		s._accum = 0
		s._worstDt = 0
		s._runtime:add(RunService.RenderStepped:Connect(function(dt: number)
			s._frames += 1
			s._accum += dt
			if dt > s._worstDt then
				s._worstDt = dt
			end
			if s._accum >= s._interval then
				refresh(s, s._accum)
			end
		end))
	else
		s._runtime:clean()
		if s._gui then
			s._gui.Parent = nil
		end
		if s._enabledStats then
			Stats.setEnabled(false)
			s._enabledStats = false
		end
	end
end

function DebugOverlay.show(self: Overlay)
	self:setVisible(true)
end

function DebugOverlay.hide(self: Overlay)
	self:setVisible(false)
end

function DebugOverlay.toggle(self: Overlay)
	self:setVisible(not (self :: any)._visible)
end

function DebugOverlay.isVisible(self: Overlay): boolean
	return (self :: any)._visible
end

--[=[
	Shows / hides the overlay from a boolean FFlag. `fflags` is anything with
	`observe(name, handler)` (either side of `Framework.FFlags`). Returns the
	unsubscribe function.
]=]
function DebugOverlay.bindFFlag(
	self: Overlay,
	fflags: { observe: (any, string, (...any) -> ()) -> () -> () },
	flagName: string
): () -> ()
	return fflags:observe(flagName, function(value: any)
		self:setVisible(value == true)
	end)
end

function DebugOverlay.destroy(self: Overlay)
	local s: any = self
	self:setVisible(false)
	s._runtime:destroy()
	s._trove:destroy()
	s._gui = nil
	s._label = nil
end

return DebugOverlay
