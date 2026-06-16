--!strict
--[=[
	@module Util.Input
	A device-agnostic action map. You bind named actions to one or more
	buttons (`Enum.KeyCode` for keyboard / gamepad, `Enum.UserInputType` for
	mouse buttons), then listen for the *action* instead of wiring raw
	`UserInputService` events everywhere. Rebinding is a one-liner, an action
	can have several bindings at once, and the map tracks the current input
	device so you can swap button prompts.

	Client-only in practice - it connects to `UserInputService`, which never
	fires on the server, so `Began` / `Ended` simply stay quiet there.

	```lua
	local Input = Framework.Input

	local map = Input.new()
	map:bind("Jump", { Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
	map:bind("Fire", { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 })

	map:onBegan("Jump", function()
	    character:jump()
	end)

	-- query state directly when you need it per-frame
	if map:isDown("Fire") then
	    weapon:tryShoot()
	end

	-- let players rebind, and react to controller / KBM swaps
	map:rebind("Jump", { Enum.KeyCode.W })
	map.DeviceChanged:connect(function(device)
	    hud:setPromptStyle(device)        -- "KeyboardMouse" | "Gamepad" | "Touch"
	end)

	map:destroy()
	```
]=]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(script.Parent.Parent.Signal)
local Trove = require(script.Parent.Trove)

type Signal<T...> = Signal.Signal<T...>
type Connection = Signal.Connection

local Input = {}
Input.__index = Input

-- Anything you can bind: keyboard / gamepad buttons are `KeyCode`s, mouse
-- buttons are `UserInputType`s.
export type Button = Enum.KeyCode | Enum.UserInputType

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"

export type Options = {
	-- Skip inputs the engine already consumed (e.g. typing in a TextBox).
	-- Defaults to true. Release (`Ended`) events are always processed so a
	-- held action can never get stuck "down".
	ignoreProcessed: boolean?,
}

export type InputMap = {
	-- (action, inputObject) when an action goes from up to down.
	Began: Signal<string, InputObject>,
	-- (action, inputObject) when an action's last held button releases.
	Ended: Signal<string, InputObject>,
	-- Fires when the active input device category changes.
	DeviceChanged: Signal<Device>,
	bind: (self: InputMap, action: string, buttons: { Button }) -> InputMap,
	rebind: (self: InputMap, action: string, buttons: { Button }) -> InputMap,
	unbind: (self: InputMap, action: string) -> (),
	getBindings: (self: InputMap, action: string) -> { Button },
	isDown: (self: InputMap, action: string) -> boolean,
	onBegan: (self: InputMap, action: string, callback: (input: InputObject) -> ()) -> Connection,
	onEnded: (self: InputMap, action: string, callback: (input: InputObject) -> ()) -> Connection,
	setEnabled: (self: InputMap, enabled: boolean) -> (),
	isEnabled: (self: InputMap) -> boolean,
	getDevice: (self: InputMap) -> Device,
	destroy: (self: InputMap) -> (),
}

local function matchesButton(input: InputObject, button: Button): boolean
	if typeof(button) ~= "EnumItem" then
		return false
	end
	if button.EnumType == Enum.KeyCode then
		return input.KeyCode == (button :: Enum.KeyCode)
	elseif button.EnumType == Enum.UserInputType then
		return input.UserInputType == (button :: Enum.UserInputType)
	end
	return false
end

local function deviceOf(inputType: Enum.UserInputType): Device
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(inputType.Name, "Gamepad") then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

--[=[
	New, empty action map. Pass `{ ignoreProcessed = false }` to also act on
	inputs Roblox already consumed (UI clicks, chat typing).
]=]
function Input.new(options: Options?): InputMap
	local opts: Options = options or {}
	local self = setmetatable({
		Began = Signal.new(),
		Ended = Signal.new(),
		DeviceChanged = Signal.new(),
		_bindings = {} :: { [string]: { Button } },
		_pressed = {} :: { [string]: { [Button]: boolean } },
		_enabled = true,
		_ignoreProcessed = opts.ignoreProcessed ~= false,
		_device = "KeyboardMouse" :: Device,
		_trove = Trove.new(),
	}, Input)

	if RunService:IsClient() then
		local s: any = self
		s._trove:add(UserInputService.InputBegan:Connect(function(input, processed)
			Input._handleBegan(self :: any, input, processed)
		end))
		s._trove:add(UserInputService.InputEnded:Connect(function(input)
			Input._handleEnded(self :: any, input)
		end))
		s._trove:add(UserInputService.LastInputTypeChanged:Connect(function(inputType)
			local device = deviceOf(inputType)
			if device ~= s._device then
				s._device = device
				s.DeviceChanged:fire(device)
			end
		end))
	end

	return self :: any
end

function Input._handleBegan(self: InputMap, input: InputObject, processed: boolean)
	local s: any = self
	if not s._enabled then
		return
	end
	if s._ignoreProcessed and processed then
		return
	end
	for action, buttons in s._bindings do
		for _, button in buttons do
			if matchesButton(input, button) then
				local held = s._pressed[action]
				if not held then
					held = {}
					s._pressed[action] = held
				end
				local wasUp = next(held) == nil
				held[button] = true
				if wasUp then
					s.Began:fire(action, input)
				end
				break
			end
		end
	end
end

function Input._handleEnded(self: InputMap, input: InputObject)
	local s: any = self
	for action, buttons in s._bindings do
		for _, button in buttons do
			if matchesButton(input, button) then
				local held = s._pressed[action]
				if held and held[button] then
					held[button] = nil
					if next(held) == nil then
						s._pressed[action] = nil
						s.Ended:fire(action, input)
					end
				end
				break
			end
		end
	end
end

function Input.bind(self: InputMap, action: string, buttons: { Button }): InputMap
	assert(type(action) == "string" and #action > 0, "[Input] action must be a non-empty string")
	local s: any = self
	local existing = s._bindings[action]
	if not existing then
		existing = {}
		s._bindings[action] = existing
	end
	for _, button in buttons do
		if not table.find(existing, button) then
			table.insert(existing, button)
		end
	end
	return self
end

function Input.rebind(self: InputMap, action: string, buttons: { Button }): InputMap
	local s: any = self
	s._bindings[action] = nil
	s._pressed[action] = nil
	return self:bind(action, buttons)
end

function Input.unbind(self: InputMap, action: string)
	local s: any = self
	s._bindings[action] = nil
	s._pressed[action] = nil
end

function Input.getBindings(self: InputMap, action: string): { Button }
	local existing = (self :: any)._bindings[action]
	return if existing then table.clone(existing) else {}
end

function Input.isDown(self: InputMap, action: string): boolean
	return (self :: any)._pressed[action] ~= nil
end

function Input.onBegan(self: InputMap, action: string, callback: (input: InputObject) -> ()): Connection
	return self.Began:connect(function(firedAction, input)
		if firedAction == action then
			callback(input)
		end
	end)
end

function Input.onEnded(self: InputMap, action: string, callback: (input: InputObject) -> ()): Connection
	return self.Ended:connect(function(firedAction, input)
		if firedAction == action then
			callback(input)
		end
	end)
end

function Input.setEnabled(self: InputMap, enabled: boolean)
	local s: any = self
	if s._enabled == enabled then
		return
	end
	s._enabled = enabled
	if not enabled then
		for action in s._pressed do
			s._pressed[action] = nil
			s.Ended:fire(action, nil :: any)
		end
	end
end

function Input.isEnabled(self: InputMap): boolean
	return (self :: any)._enabled
end

function Input.getDevice(self: InputMap): Device
	return (self :: any)._device
end

function Input.destroy(self: InputMap)
	local s: any = self
	s._trove:destroy()
	table.clear(s._bindings)
	table.clear(s._pressed)
	s.Began:destroy()
	s.Ended:destroy()
	s.DeviceChanged:destroy()
end

return Input
