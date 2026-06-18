--!strict
--[=[ @module Signal 
	Generic signal module for connecting and firing events.

	```lua
	local Signal = require(Weave.Signal)

	local signal = Signal.new()
	signal:connect(function(value)
		print(value)
	end)
	signal:fire(1)
	```
]=]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable(
	{} :: {
		connected: boolean,
		_signal: any,
		_handler: (...any) -> (),
	},
	Connection
))

function Connection.disconnect(self: Connection)
	if not self.connected then
		return
	end
	self.connected = false
	local signal = self._signal
	local handlers = signal._handlers
	local idx = table.find(handlers, self._handler)
	if idx then
		table.remove(handlers, idx)
	end
end

export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_handlers: { (T...) -> () },
		_destroyed: boolean,
	},
	Signal
))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_handlers = {},
		_destroyed = false,
	}, Signal) :: any
end

function Signal.connect<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	assert(not self._destroyed, "cannot connect to destroyed signal")
	table.insert(self._handlers, handler)
	return setmetatable({
		connected = true,
		_signal = self,
		_handler = handler,
	}, Connection) :: any
end

function Signal.once<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	local conn: Connection
	local wrapped = function(...)
		conn:disconnect()
		handler(...)
	end
	conn = self:connect(wrapped :: any)
	return conn
end

function Signal.fire<T...>(self: Signal<T...>, ...: T...)
	if self._destroyed then
		return
	end
	local snapshot = table.clone(self._handlers)
	for _, handler in snapshot do
		task.spawn(handler, ...)
	end
end

function Signal.wait<T...>(self: Signal<T...>): ...any
	local thread = coroutine.running()
	self:once(function(...)
		task.spawn(thread, ...)
	end :: any)
	return coroutine.yield()
end

function Signal.destroy<T...>(self: Signal<T...>)
	self._destroyed = true
	table.clear(self._handlers)
end

function Signal.handlerCount<T...>(self: Signal<T...>): number
	return #self._handlers
end

return Signal
