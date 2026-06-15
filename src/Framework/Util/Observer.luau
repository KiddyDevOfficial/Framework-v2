--!strict
--[=[
	@module Util.Observer
	A typed observable value. Holds one value, fires when it changes, and
	can replay the current value to new subscribers on connect. Drop the
	returned connection into a `Trove` if you want it cleaned up for you.

	```lua
	local coins = Observer.new(0)

	-- Fires immediately with the current value, then on every change.
	local conn = coins:observe(function(new, old)
	    print(`coins: {old} -> {new}`)
	end)

	coins:set(100)               -- prints "coins: 0 -> 100"
	coins:update(function(c)     -- prints "coins: 100 -> 150"
	    return c + 50
	end)

	conn:disconnect()
	coins:destroy()
	```
]=]

local Signal = require(script.Parent.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>
type Connection = Signal.Connection

local Observer = {}
Observer.__index = Observer

export type Observer<T> = {
	-- Fires after the value changes -- (new, old)
	Changed: Signal<T, T>,
	get: (self: Observer<T>) -> T,
	set: (self: Observer<T>, value: T) -> boolean,
	update: (self: Observer<T>, transform: (current: T) -> T) -> boolean,
	-- Subscribe and fire callback(current, current) right away
	observe: (self: Observer<T>, callback: (new: T, old: T) -> ()) -> Connection,
	-- Subscribe without the immediate replay
	subscribe: (self: Observer<T>, callback: (new: T, old: T) -> ()) -> Connection,
	isDestroyed: (self: Observer<T>) -> boolean,
	destroy: (self: Observer<T>) -> (),
}

--[=[
	New observable seeded with `initialValue`. The optional `equals`
	predicate decides what counts as a change (defaults to `==`) -- pass
	one in when you're holding a table and want it compared by content.
]=]
function Observer.new<T>(initialValue: T, equals: ((a: T, b: T) -> boolean)?): Observer<T>
	local self = setmetatable({
		Changed = Signal.new(),
		_value = initialValue,
		_equals = equals,
		_destroyed = false,
	}, Observer)
	return self :: any
end

function Observer.get<T>(self: Observer<T>): T
	return (self :: any)._value
end

local function isEqual(s: any, a: any, b: any): boolean
	if s._equals then
		return s._equals(a, b)
	end
	return a == b
end

--[=[
	Assigns `value` and fires `Changed` if it actually differs from what
	was there. Returns `true` when a change went out.
]=]
function Observer.set<T>(self: Observer<T>, value: T): boolean
	local s: any = self
	assert(not s._destroyed, "[Observer] cannot set on destroyed observer")
	local old = s._value
	if isEqual(s, old, value) then
		return false
	end
	s._value = value
	s.Changed:fire(value, old)
	return true
end

--[=[
	Like `set`, but derives the next value from the current one.
]=]
function Observer.update<T>(self: Observer<T>, transform: (current: T) -> T): boolean
	local s: any = self
	return self:set(transform(s._value))
end

function Observer.observe<T>(self: Observer<T>, callback: (new: T, old: T) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, "[Observer] cannot observe a destroyed observer")
	local conn = s.Changed:connect(callback)
	-- Replay the current value now so the subscriber starts in sync
	callback(s._value, s._value)
	return conn
end

function Observer.subscribe<T>(self: Observer<T>, callback: (new: T, old: T) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, "[Observer] cannot subscribe to a destroyed observer")
	return s.Changed:connect(callback)
end

function Observer.isDestroyed<T>(self: Observer<T>): boolean
	return (self :: any)._destroyed
end

function Observer.destroy<T>(self: Observer<T>)
	local s: any = self
	if s._destroyed then
		return
	end
	s._destroyed = true
	s.Changed:destroy()
end

return Observer
