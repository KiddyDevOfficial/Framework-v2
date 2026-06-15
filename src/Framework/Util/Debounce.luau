--!strict
--[=[
	@module Util.Debounce
	Rate-limit wrappers around any callable.
	  * `debounce(fn, wait)`  - coalesces calls; runs after `wait`s of
	    quiet (trailing edge). Returns `(wrapper, cancel)`.
	  * `throttle(fn, wait)`  - at most one call per `wait`s window
	    (leading edge). Returns `(wrapper, cancel)`.
	  * `lock(fn)`            - drops calls while the previous one's still
	    running. For non-reentrant work.
]=]

local Debounce = {}

--[=[
	Trailing-edge debounce. Each call resets the timer; `fn` runs once, `wait`s
	after the last call.
]=]
function Debounce.debounce<A...>(fn: (A...) -> (), wait: number): (((A...) -> ()), () -> ())
	local pending: thread?

	local function cancel()
		local t = pending
		pending = nil
		if t then
			task.cancel(t)
		end
	end

	local function wrapper(...: A...)
		cancel()
		local args = table.pack(...)
		pending = task.delay(wait, function()
			pending = nil
			fn(table.unpack(args, 1, args.n))
		end)
	end

	return wrapper, cancel
end

--[=[
	Leading-edge throttle. First call runs right away; later calls within `wait`
	seconds are dropped.
]=]
function Debounce.throttle<A...>(fn: (A...) -> (), wait: number): (((A...) -> ()), () -> ())
	local lastRun = -math.huge

	local function wrapper(...: A...)
		local now = os.clock()
		if now - lastRun < wait then
			return
		end
		lastRun = now
		fn(...)
	end

	local function reset()
		lastRun = -math.huge
	end

	return wrapper, reset
end

--[=[
	Drops re-entrant calls. While `fn` is running, further calls do nothing.
	Resets when it finishes, even if it errored.
]=]
function Debounce.lock<A...>(fn: (A...) -> ()): ((A...) -> ())
	local running = false
	return function(...: A...)
		if running then
			return
		end
		running = true
		local ok, err = pcall(fn, ...)
		running = false
		if not ok then
			error(err, 0)
		end
	end
end

return Debounce
