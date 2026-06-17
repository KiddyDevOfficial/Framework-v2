--!strict
--[=[
	@module Util.GuiButton
	Hover/press tweens and optional GUI sounds for `GuiButton`s tagged
	`"Button"`.

	Sounds route through `Util.Sound` by name. By default the helper looks for
	`SoundService.GuiSounds`; pass `soundPlayer` to share your own handler and
	volume groups.

	Studio setup:
	  - Tag any `GuiButton` with `Button` (CollectionService tag).
	  - Optional numeric `SizeFactor` attribute sets the hover scale.
	  - For the default handler, add a `SoundService.GuiSounds` folder with
	    `Click` and `Hover` `Sound` children.

	```lua
	local GuiButton = Framework.Util.GuiButton

	GuiButton.bind(shopButton)
	GuiButton.bindIn(playerGui:WaitForChild("HUD"))

	local SoundController = require(StarterPlayerScripts.Client.Controllers.SoundController)
	GuiButton.bindTagged({ soundPlayer = SoundController.Player, soundGroup = "UI" })
	```
]=]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Trove = require(script.Parent.Trove)
local Sound = require(script.Parent.Sound)

local BUTTON_TAG = "Button"
local SIZE_FACTOR_ATTRIBUTE = "SizeFactor"
local DEFAULT_SCALE_FACTOR = 1.08
local DEFAULT_CLICK_SOUND = "Click"
local DEFAULT_HOVER_SOUND = "Hover"
local DEFAULT_LIBRARY_NAME = "GuiSounds"
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PRESS_RELEASE_DELAY = 0.1

export type Options = {
	scaleFactor: number?,
	tweenInfo: TweenInfo?,
	soundPlayer: Sound.SoundPlayer?,
	clickSound: string?,
	hoverSound: string?,
	soundGroup: string?,
}

local GuiButtonUtil = {
	Tag = BUTTON_TAG,
}

pcall(function()
	CollectionService:RegisterTag(BUTTON_TAG)
end)

local activeTweens: { [GuiButton]: Tween } = {}

local defaultPlayer: Sound.SoundPlayer? = nil
local function getDefaultPlayer(): Sound.SoundPlayer
	local player: Sound.SoundPlayer = defaultPlayer or Sound.new()
	defaultPlayer = player
	if not player:hasLibrary() then
		local folder = SoundService:FindFirstChild(DEFAULT_LIBRARY_NAME)
		if folder then
			player:setLibrary(folder)
		end
	end
	return player
end

local function playNamed(player: Sound.SoundPlayer, name: string, group: string?)
	if not player:hasLibrary() then
		return
	end
	if not player:get(name) then
		return
	end
	player:play(name, if group then { group = group } else nil)
end

local function scaledSize(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		size.X.Offset * factor,
		size.Y.Scale * factor,
		size.Y.Offset * factor
	)
end

local function readScaleFactor(button: GuiButton, fallback: number): number
	local raw = button:GetAttribute(SIZE_FACTOR_ATTRIBUTE)
	if type(raw) == "number" and raw > 0 then
		return raw
	end
	return fallback
end

local function tweenSize(button: GuiButton, newSize: UDim2, tweenInfo: TweenInfo)
	local existing = activeTweens[button]
	if existing then
		existing:Cancel()
	end
	local tween = TweenService:Create(button, tweenInfo, { Size = newSize })
	activeTweens[button] = tween
	tween:Play()
	tween.Completed:Once(function()
		if activeTweens[button] == tween then
			activeTweens[button] = nil
		end
	end)
end

--[=[
	Binds hover and click feedback to one `GuiButton`.
]=]
function GuiButtonUtil.bind(button: GuiButton, options: Options?): Trove.Trove
	local opts: Options = options or {}
	local scaleFactor = opts.scaleFactor or readScaleFactor(button, DEFAULT_SCALE_FACTOR)
	local tweenInfo = opts.tweenInfo or TWEEN_INFO
	local player = opts.soundPlayer or getDefaultPlayer()
	local clickSound = opts.clickSound or DEFAULT_CLICK_SOUND
	local hoverSound = opts.hoverSound or DEFAULT_HOVER_SOUND
	local soundGroup = opts.soundGroup

	local defaultSize = button.Size
	local hoverSize = scaledSize(defaultSize, scaleFactor)
	local hovering = false
	local trove = Trove.new()

	trove:add(button.MouseEnter:Connect(function()
		hovering = true
		playNamed(player, hoverSound, soundGroup)
		tweenSize(button, hoverSize, tweenInfo)
	end))

	trove:add(button.MouseLeave:Connect(function()
		hovering = false
		tweenSize(button, defaultSize, tweenInfo)
	end))

	trove:add(button.MouseButton1Down:Connect(function()
		playNamed(player, clickSound, soundGroup)
		tweenSize(button, defaultSize, tweenInfo)
		task.delay(PRESS_RELEASE_DELAY, function()
			if not button.Parent then
				return
			end
			tweenSize(button, if hovering then hoverSize else defaultSize, tweenInfo)
		end)
	end))

	trove:add(function()
		local tween = activeTweens[button]
		if tween then
			tween:Cancel()
			activeTweens[button] = nil
		end
		button.Size = defaultSize
	end)

	trove:add(button.Destroying:Connect(function()
		trove:destroy()
	end))

	return trove
end

local function shouldBind(instance: Instance): boolean
	return instance:IsA("GuiButton") and CollectionService:HasTag(instance, BUTTON_TAG)
end

local function resolveContainerScaleFactor(root: Instance, fallback: number): number
	local raw = root:GetAttribute(SIZE_FACTOR_ATTRIBUTE)
	if type(raw) == "number" and raw > 0 then
		return raw
	end
	return fallback
end

local function watchTagged(
	root: Instance?,
	options: Options?
): Trove.Trove
	local opts: Options = options or {}
	local fallbackFactor = opts.scaleFactor
		or (if root then resolveContainerScaleFactor(root, DEFAULT_SCALE_FACTOR) else DEFAULT_SCALE_FACTOR)
	local master = Trove.new()
	local buttonTroves: { [GuiButton]: Trove.Trove } = {}

	local function unbindButton(button: GuiButton)
		local trove = buttonTroves[button]
		if not trove then
			return
		end
		buttonTroves[button] = nil
		trove:destroy()
	end

	local function tryBind(instance: Instance)
		if not shouldBind(instance) then
			return
		end
		if root and not instance:IsDescendantOf(root) then
			return
		end
		local button = instance :: GuiButton
		if buttonTroves[button] then
			return
		end
		local factor = readScaleFactor(button, fallbackFactor)
		local trove = GuiButtonUtil.bind(button, {
			scaleFactor = factor,
			tweenInfo = opts.tweenInfo,
			soundPlayer = opts.soundPlayer,
			clickSound = opts.clickSound,
			hoverSound = opts.hoverSound,
			soundGroup = opts.soundGroup,
		})
		buttonTroves[button] = trove
		master:add(trove)
	end

	for _, instance in CollectionService:GetTagged(BUTTON_TAG) do
		tryBind(instance)
	end

	master:add(CollectionService:GetInstanceAddedSignal(BUTTON_TAG):Connect(tryBind))
	master:add(CollectionService:GetInstanceRemovedSignal(BUTTON_TAG):Connect(function(instance)
		if instance:IsA("GuiButton") then
			unbindButton(instance)
		end
	end))

	return master
end

--[=[
	Binds tagged `GuiButton`s under `root`.
]=]
function GuiButtonUtil.bindIn(root: Instance, options: Options?): Trove.Trove
	return watchTagged(root, options)
end

function GuiButtonUtil.bindTagged(options: Options?): Trove.Trove
	return watchTagged(nil, options)
end

--[=[
	Binds a button, a container's tagged descendants, or a list of instances.
]=]
function GuiButtonUtil.bindAny(target: GuiButton | Instance | { Instance }, options: Options?): Trove.Trove?
	if typeof(target) == "Instance" then
		if target:IsA("GuiButton") then
			if not shouldBind(target) then
				return nil
			end
			return GuiButtonUtil.bind(target, options)
		end
		return GuiButtonUtil.bindIn(target, options)
	end

	if type(target) == "table" then
		local master = Trove.new()
		for _, instance in target do
			if typeof(instance) ~= "Instance" then
				continue
			end
			if shouldBind(instance) then
				master:add(GuiButtonUtil.bind(instance :: GuiButton, options))
			end
		end
		return master
	end

	return nil
end

function GuiButtonUtil.isBindable(button: GuiButton): boolean
	return shouldBind(button)
end

function GuiButtonUtil.hasTag(instance: Instance): boolean
	return CollectionService:HasTag(instance, BUTTON_TAG)
end

return GuiButtonUtil
