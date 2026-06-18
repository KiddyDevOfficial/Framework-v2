--!strict
--[=[
	@module Util.Observer.observeAttribute
	Observes `instance` attribute `attribute`. Fires immediately with the
	current value, then on every change.
]=]

local Trove = require(script.Parent.Parent.Trove)
local Types = require(script.Parent.Types)

type Cleanup = Types.Cleanup
type Stop = Types.Stop
type ValueCallback = Types.ValueCallback

local function observeAttribute(instance: Instance, attribute: string, callback: ValueCallback): Stop
	assert(typeof(instance) == "Instance", "[Observer.observeAttribute] instance must be an Instance")
	assert(type(attribute) == "string", "[Observer.observeAttribute] attribute must be a string")
	assert(type(callback) == "function", "[Observer.observeAttribute] callback must be a function")

	local trove = Trove.new()
	local current: Cleanup? = nil

	local function onChanged()
		local cleanup = current
		current = nil
		if cleanup then
			cleanup()
		end
		current = callback(instance:GetAttribute(attribute))
	end

	trove:connect(instance:GetAttributeChangedSignal(attribute), onChanged)
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

return observeAttribute
