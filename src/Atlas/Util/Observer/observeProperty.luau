--!strict
--[=[
	@module Util.Observer.observeProperty
	Observes `instance[property]`. Fires immediately with the current value,
	then on every change.
]=]

local Trove = require(script.Parent.Parent.Trove)
local Types = require(script.Parent.Types)

type Cleanup = Types.Cleanup
type Stop = Types.Stop
type ValueCallback = Types.ValueCallback

local function observeProperty(instance: Instance, property: string, callback: ValueCallback): Stop
	assert(typeof(instance) == "Instance", "[Observer.observeProperty] instance must be an Instance")
	assert(type(property) == "string", "[Observer.observeProperty] property must be a string")
	assert(type(callback) == "function", "[Observer.observeProperty] callback must be a function")

	local trove = Trove.new()
	local current: Cleanup? = nil

	local function onChanged()
		local cleanup = current
		current = nil
		if cleanup then
			cleanup()
		end
		current = callback((instance :: any)[property])
	end

	trove:connect(instance:GetPropertyChangedSignal(property), onChanged)
	onChanged()

	return function()
		local cleanup = current
		current = nil
		if cleanup then
			cleanup()
		end
		trove:destroy()
	end
end

return observeProperty
