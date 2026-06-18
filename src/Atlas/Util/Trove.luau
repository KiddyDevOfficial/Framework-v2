--!strict
--[=[
	@module Util.Trove
	Collects cleanup work: connections, Instances, threads, functions, signals,
	and tables with common cleanup methods. Call `:clean()` or `:destroy()` to
	dispose everything in one pass.

	```lua
	local trove = Trove.new()
	trove:add(player.CharacterAdded:Connect(onChar))
	trove:add(model)
	trove:add(task.delay(5, foo))
	trove:add(function() doManualCleanup() end)

	trove:destroy()
	```
]=]

local RunService = game:GetService("RunService")

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
	connect: (self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()) -> RBXScriptConnection,
	bindToRenderStep: (self: Trove, name: string, priority: number, callback: (number) -> ()) -> (),
	remove: (self: Trove, object: any) -> boolean,
	extend: (self: Trove) -> Trove,
	clean: (self: Trove) -> (),
	destroy: (self: Trove) -> (),
	attachToInstance: (self: Trove, instance: Instance) -> (),
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
		_instance = nil :: Instance?,
	}, Trove) :: any
end

function Trove.add<T>(self: Trove, object: T): T
	local s: any = self
	assert(not s._destroyed, "[Trove] cannot add to destroyed trove")
	table.insert(s._objects, object)
	return object
end

function Trove.connect(self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()): RBXScriptConnection
	return self:add(signal:Connect(callback))
end

function Trove.bindToRenderStep(self: Trove, name: string, priority: number, callback: (number) -> ())
	RunService:BindToRenderStep(name, priority, callback)
	self:add(function()
		RunService:UnbindFromRenderStep(name)
	end)
end

function Trove.attachToInstance(self: Trove, instance: Instance)
	local s: any = self
	if s._destroyed then
		error("[Trove] Cannot attach destroyed Trove to instance")
	end
	if s._instance then
		if s._instance == instance then
			return
		else
			error("[Trove] Trove already attached to another instance")
		end
	end
	s._instance = instance
	instance.Destroying:Once(function()
		self:destroy()
	end)
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