--!strict
--[=[
	@module Util.DebugOverlay
	A small client debug HUD for frame timing and remote traffic. The GUI is
	built when it is first shown, and `Networking.Stats` is only enabled while
	the overlay needs it.

	Gate it behind an FFlag when you want to turn it on in a live session:

	```lua
	local DebugOverlay = Framework.DebugOverlay

	local overlay = DebugOverlay.new()
	overlay:bindFFlag(Framework.FFlags.client, "ShowDebugOverlay")
	-- Or drive it yourself, e.g. from Framework.Input:
	-- overlay:toggle()

	overlay:destroy()
	```

	## Data tree

	Attach a provider to show a scrollable tree for a JSON-shaped table, such
	as the local replicated profile data. It refreshes on the overlay interval.

	```lua
	overlay:attachData(function()
		return DataController:Get()
	end)
	overlay:toggleData()
	```
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Stats = require(script.Parent.Parent.Networking.Stats)
local Trove = require(script.Parent.Trove)

local IS_STUDIO = RunService:IsStudio()

local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

local KEY_COLOR = "#9CDCFE"
local STRING_COLOR = "#CE9178"
local NUMBER_COLOR = "#B5CEA8"
local BOOLEAN_COLOR = "#569CD6"
local MUTED_COLOR = "#808080"
local PUNCT_COLOR = "#6A737D"

export type DataProvider = () -> any

export type Options = {
	refreshInterval: number?,
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
	attachData: (self: Overlay, provider: DataProvider) -> (),
	detachData: (self: Overlay) -> (),
	setDataVisible: (self: Overlay, visible: boolean) -> (),
	toggleData: (self: Overlay) -> (),
	isDataVisible: (self: Overlay) -> boolean,
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
		_container = nil :: Frame?,
		_label = nil :: TextLabel?,
		_frames = 0,
		_accum = 0,
		_worstDt = 0,
		_enabledStats = false,
		_dataProvider = nil :: DataProvider?,
		_dataVisible = true,
		_dataPanel = nil :: Frame?,
		_treeLabel = nil :: TextLabel?,
		_lastTreeText = nil :: string?,
		_trove = Trove.new(),
		_runtime = Trove.new(),
	}, DebugOverlay)
	return self :: any
end

local function paint(hex: string, text: string): string
	return `<font color="{hex}">{text}</font>`
end

local function escapeRich(s: string): string
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function formatScalar(value: any): string
	local t = typeof(value)
	if t == "string" then
		return paint(STRING_COLOR, '"' .. escapeRich(value) .. '"')
	elseif t == "number" then
		return paint(NUMBER_COLOR, tostring(value))
	elseif t == "boolean" then
		return paint(BOOLEAN_COLOR, tostring(value))
	elseif t == "nil" then
		return paint(MUTED_COLOR, "nil")
	end
	return paint(MUTED_COLOR, escapeRich(tostring(value)))
end

local function countEntries(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function isArrayLike(t: { [any]: any }): boolean
	local len = #t
	if len == 0 then
		return false
	end
	return countEntries(t) == len
end

local function sortedKeys(t: { [any]: any }): { any }
	local numeric: { number } = {}
	local other: { any } = {}
	for k in t do
		if type(k) == "number" then
			table.insert(numeric, k)
		else
			table.insert(other, k)
		end
	end
	table.sort(numeric)
	table.sort(other, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local keys: { any } = {}
	for _, k in numeric do
		keys[#keys + 1] = k
	end
	for _, k in other do
		keys[#keys + 1] = k
	end
	return keys
end

local function appendTree(lines: { string }, value: { [any]: any }, indent: number, seen: { [any]: boolean })
	local pad = string.rep("    ", indent)
	for _, key in sortedKeys(value) do
		local v = value[key]
		local keyText = paint(KEY_COLOR, escapeRich(tostring(key)))
		local colon = paint(PUNCT_COLOR, ":")

		if type(v) == "table" then
			if seen[v] then
				lines[#lines + 1] = pad .. keyText .. colon .. " " .. paint(MUTED_COLOR, "<cycle>")
			else
				seen[v] = true
				local n = countEntries(v)
				local brace = if isArrayLike(v) then "[" .. n .. "]" else "{" .. n .. "}"
				lines[#lines + 1] = pad .. keyText .. colon .. " " .. paint(PUNCT_COLOR, brace)
				appendTree(lines, v, indent + 1, seen)
				seen[v] = nil
			end
		else
			lines[#lines + 1] = pad .. keyText .. colon .. " " .. formatScalar(v)
		end
	end
end

local function renderTree(root: any): string
	if type(root) ~= "table" then
		return paint(MUTED_COLOR, "waiting for data…")
	end
	local lines: { string } = {}
	appendTree(lines, root, 0, {})
	if #lines == 0 then
		return paint(MUTED_COLOR, "(empty)")
	end
	return table.concat(lines, "\n")
end

local function styleBox(frame: Frame)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame
end

local function ensureDataPanel(self: any)
	if not IS_STUDIO then
		return
	end
	if self._dataPanel or not self._dataProvider or not self._container then
		return
	end

	local panel = Instance.new("Frame")
	panel.Name = "Data"
	panel.LayoutOrder = 2
	panel.Size = UDim2.fromOffset(320, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = self._dataVisible
	styleBox(panel)
	panel.Parent = self._container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.LayoutOrder = 1
	header.BackgroundTransparency = 1
	header.AutomaticSize = Enum.AutomaticSize.X
	header.Size = UDim2.fromOffset(0, 14)
	header.FontFace = Font.fromEnum(Enum.Font.Code)
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(180, 180, 180)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "PROFILE DATA"
	header.Parent = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tree"
	scroll.LayoutOrder = 2
	scroll.Size = UDim2.new(1, 0, 0, 320)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageTransparency = 0.4
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.Parent = panel

	local tree = Instance.new("TextLabel")
	tree.Name = "TreeText"
	tree.BackgroundTransparency = 1
	tree.AutomaticSize = Enum.AutomaticSize.XY
	tree.Size = UDim2.fromOffset(0, 0)
	tree.RichText = true
	tree.TextWrapped = false
	tree.FontFace = Font.fromEnum(Enum.Font.Code)
	tree.TextSize = 13
	tree.TextColor3 = Color3.new(1, 1, 1)
	tree.TextXAlignment = Enum.TextXAlignment.Left
	tree.TextYAlignment = Enum.TextYAlignment.Top
	tree.Text = paint(MUTED_COLOR, "waiting for data…")
	tree.Parent = scroll

	self._dataPanel = panel
	self._treeLabel = tree
	self._lastTreeText = nil
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

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.zero
	container.Position = self._position
	container.Size = UDim2.fromOffset(0, 0)
	container.AutomaticSize = Enum.AutomaticSize.XY
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = gui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = container

	local frame = Instance.new("Frame")
	frame.Name = "Stats"
	frame.LayoutOrder = 1
	frame.AnchorPoint = Vector2.zero
	frame.Size = UDim2.fromOffset(220, 44)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	styleBox(frame)
	frame.Parent = container

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
	self._container = container
	self._label = label
	self._trove:add(gui)

	ensureDataPanel(self)
end

local function updateDataPanel(self: any)
	local label: TextLabel? = self._treeLabel
	if not label or not self._dataProvider or not self._dataVisible then
		return
	end

	local ok, root = pcall(self._dataProvider)
	local text = if ok then renderTree(root) else paint(MUTED_COLOR, "data unavailable")
	-- Avoid resetting scroll when the tree has not changed.
	if text ~= self._lastTreeText then
		self._lastTreeText = text
		label.Text = text
	end
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

	-- Keep provider work off the render thread; data may still be loading.
	if self._dataProvider and self._treeLabel and self._dataVisible then
		task.spawn(updateDataPanel, self)
	end
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
		s._lastTreeText = nil
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
	Shows the overlay while a boolean FFlag is true. `fflags` can be either
	side of `Framework.FFlags`, or anything else with `observe(name, handler)`.
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

--[=[
	Attach a JSON-shaped snapshot provider. It is safe to call before or after
	`:show()`, and replacing the provider updates the existing tree.

	Studio only. The provider is never stored or invoked in a published session.
]=]
function DebugOverlay.attachData(self: Overlay, provider: DataProvider)
	if not IS_STUDIO then
		return
	end
	local s: any = self
	s._dataProvider = provider
	s._lastTreeText = nil
	ensureDataPanel(s)
	if s._visible then
		task.spawn(updateDataPanel, s)
	end
end

function DebugOverlay.detachData(self: Overlay)
	local s: any = self
	s._dataProvider = nil
	s._lastTreeText = nil
	if s._dataPanel then
		s._dataPanel:Destroy()
		s._dataPanel = nil
		s._treeLabel = nil
	end
end

function DebugOverlay.setDataVisible(self: Overlay, visible: boolean)
	local s: any = self
	s._dataVisible = visible
	if s._dataPanel then
		s._dataPanel.Visible = visible
	end
	if visible and s._visible then
		s._lastTreeText = nil
		task.spawn(updateDataPanel, s)
	end
end

function DebugOverlay.toggleData(self: Overlay)
	self:setDataVisible(not (self :: any)._dataVisible)
end

function DebugOverlay.isDataVisible(self: Overlay): boolean
	return (self :: any)._dataVisible
end

function DebugOverlay.destroy(self: Overlay)
	local s: any = self
	self:setVisible(false)
	s._runtime:destroy()
	s._trove:destroy()
	s._gui = nil
	s._container = nil
	s._label = nil
	s._dataPanel = nil
	s._treeLabel = nil
	s._dataProvider = nil
end

return DebugOverlay
