--!strict
--[=[
	@controller InputController
	Singleton wrapper around `Framework.Util.Input` - one shared action map for
	the whole client. Bind actions here and any controller can reach them by
	depending on `"InputController"` (or just requiring this module).

	The map is built at require time, so it's ready before any controller's
	`Init` - bind in `Init`, react in `Start`.

	```lua
	-- some other controller
	local InputController = require(script.Parent.InputController)

	local MovementController = {
	    Dependencies = { "InputController" },
	}

	function MovementController:Init()
	    InputController:bind("Jump", { Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
	end

	function MovementController:Start()
	    InputController:onBegan("Jump", function()
	        -- jump
	    end)
	end

	return MovementController
	```

	For anything the proxy below doesn't cover, reach the map directly via
	`InputController.Map`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local Input = Framework.Util.Input

type InputMap = Framework.InputMap
type Button = Framework.InputButton
type Device = Framework.InputDevice
type Connection = Framework.Connection

local map = Input.new()

local InputController = {
	Map = map,
	Began = map.Began,
	Ended = map.Ended,
	DeviceChanged = map.DeviceChanged,
}

function InputController:bind(action: string, buttons: { Button }): InputMap
	return map:bind(action, buttons)
end

function InputController:rebind(action: string, buttons: { Button }): InputMap
	return map:rebind(action, buttons)
end

function InputController:unbind(action: string)
	map:unbind(action)
end

function InputController:getBindings(action: string): { Button }
	return map:getBindings(action)
end

function InputController:isDown(action: string): boolean
	return map:isDown(action)
end

function InputController:onBegan(action: string, callback: (input: InputObject) -> ()): Connection
	return map:onBegan(action, callback)
end

function InputController:onEnded(action: string, callback: (input: InputObject) -> ()): Connection
	return map:onEnded(action, callback)
end

function InputController:setEnabled(enabled: boolean)
	map:setEnabled(enabled)
end

function InputController:isEnabled(): boolean
	return map:isEnabled()
end

function InputController:getDevice(): Device
	return map:getDevice()
end

function InputController:Stop()
	map:destroy()
end

return InputController
