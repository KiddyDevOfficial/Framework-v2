--!strict
--[=[
	@module Util.Observer.observeChildren
	Observes direct children of `parent`, including those already present.
]=]

local Trove = require(script.Parent.Parent.Trove)
local Types = require(script.Parent.Types)

type Cleanup = Types.Cleanup
type Stop = Types.Stop
type ChildCallback = Types.ChildCallback

local function observeChildren(parent: Instance, callback: ChildCallback): Stop
	assert(typeof(parent) == "Instance", "[Observer.observeChildren] parent must be an Instance")
	assert(type(callback) == "function", "[Observer.observeChildren] callback must be a function")

	local trove = Trove.new()
	local cleanups: { [Instance]: Cleanup } = {}

	local function onAdded(child: Instance)
		if cleanups[child] then
			return
		end
		cleanups[child] = callback(child) or function() end
	end

	local function onRemoved(child: Instance)
		local cleanup = cleanups[child]
		if cleanup then
			cleanups[child] = nil
			cleanup()
		end
	end

	trove:connect(parent.ChildAdded, onAdded)
	trove:connect(parent.ChildRemoved, onRemoved)

	for _, child in parent:GetChildren() do
		onAdded(child)
	end

	return function()
		for child in cleanups do
			onRemoved(child)
		end
		trove:destroy()
	end
end

return observeChildren
