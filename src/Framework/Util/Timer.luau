--!strict
--[=[
	@module Util.Timer
	Interval timer with `Tick` Signal and start/stop/destroy. Designed
	to be stored in a Trove for automatic cleanup.

	```lua
	local timer = Timer.new(1)
	timer.Tick:connect(function() print("tick") end)
	timer:start()
	```
]=]

local Signal = require(script.Parent.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>

local RunService = game:GetService("RunService")

local Timer = {}
Timer.__index = Timer

export type Timer = {
	Interval: number,
	Tick: Signal<()>,
	IsRunning: boolean,
	start: (self: Timer) -> (),
	stop: (self: Timer) -> (),
	setInterval: (self: Timer, interval: number) -> (),
	destroy: (self: Timer) -> (),
}

function Timer.new(interval: number): Timer
	assert(interval > 0, "[Timer] interval must be > 0")
	local self = setmetatable({
		Interval = interval,
		Tick = Signal.new(),
		IsRunning = false,
		_accumulator = 0,
		_conn = nil :: RBXScriptConnection?,
	}, Timer)
	return self :: any
end

function Timer.start(self: Timer)
	local s: any = self
	if s.IsRunning then
		return
	end
	s.IsRunning = true
	s._accumulator = 0
	s._conn = RunService.Heartbeat:Connect(function(dt: number)
		s._accumulator += dt
		while s._accumulator >= s.Interval do
			s._accumulator -= s.Interval
			s.Tick:fire()
		end
	end)
end

function Timer.stop(self: Timer)
	local s: any = self
	if not s.IsRunning then
		return
	end
	s.IsRunning = false
	if s._conn then
		s._conn:Disconnect()
		s._conn = nil
	end
end

function Timer.setInterval(self: Timer, interval: number)
	assert(interval > 0, "[Timer] interval must be > 0")
	local s: any = self
	s.Interval = interval
	s._accumulator = 0
end

function Timer.destroy(self: Timer)
	local s: any = self
	self:stop()
	s.Tick:destroy()
end

return Timer
