--!strict
--[=[
	@module Util.Trove
	Collects anything that needs cleaning up - connections, Instances, threads,
	functions, signals, tables with `:destroy` / `:Destroy`. Throw it all in one
	trove and call `:clean()` (or `:destroy()`) to dispose it in one go.

	```lua
	local trove = Trove.new()
	trove:add(player.CharacterAdded:Connect(onChar))
	trove:add(model)
	trove:add(task.delay(5, foo))
	trove:add(function() doManualCleanup() end)

	-- later
	trove:destroy()
	```
]=]

local Trove = {}
Trove.__index = Trove

export type Cleanable =
	RBXScriptConnection
	| Instance
	| thread
	| () -> ()
	| { destroy: (any) -> () }
	| { Destroy: (any) -> () }
	| { disconnect: (any) -> () }
	| { Disconnect: (any) -> () }

export type Trove = {
	add: <T>(self: Trove, object: T) -> T,
	remove: (self: Trove, object: any) -> boolean,
	extend: (self: Trove) -> Trove,
	clean: (self: Trove) -> (),
	destroy: (self: Trove) -> (),
	isDestroyed: (self: Trove) -> boolean,
}

local function dispose(object: any)
	local kind = typeof(object)
	if kind == "RBXScriptConnection" then
		(object :: RBXScriptConnection):Disconnect()
	elseif kind == "Instance" then
		(object :: Instance):Destroy()
	elseif kind == "thread" then
		pcall(task.cancel, object)
	elseif kind == "function" then
		(object :: () -> ())()
	elseif kind == "table" then
		if type(object.destroy) == "function" then
			object:destroy()
		elseif type(object.Destroy) == "function" then
			object:Destroy()
		elseif type(object.disconnect) == "function" then
			object:disconnect()
		elseif type(object.Disconnect) == "function" then
			object:Disconnect()
		end
	end
end

function Trove.new(): Trove
	return setmetatable({
		_objects = {},
		_destroyed = false,
	}, Trove) :: any
end

function Trove.add<T>(self: Trove, object: T): T
	local s: any = self
	assert(not s._destroyed, "[Trove] cannot add to destroyed trove")
	table.insert(s._objects, object)
	return object
end

function Trove.remove(self: Trove, object: any): boolean
	local s: any = self
	local idx = table.find(s._objects, object)
	if not idx then
		return false
	end
	table.remove(s._objects, idx)
	dispose(object)
	return true
end

--[=[
	A child trove. Cleaning the parent cleans children too.
]=]
function Trove.extend(self: Trove): Trove
	local child = Trove.new()
	self:add(child)
	return child
end

function Trove.clean(self: Trove)
	local s: any = self
	local objects = s._objects
	s._objects = {}
	for i = #objects, 1, -1 do
		dispose(objects[i])
	end
end

function Trove.destroy(self: Trove)
	local s: any = self
	if s._destroyed then
		return
	end
	s._destroyed = true
	self:clean()
end

function Trove.isDestroyed(self: Trove): boolean
	return (self :: any)._destroyed
end

return Trove
