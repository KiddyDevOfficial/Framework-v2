--!strict
--[=[
	@module Util.Queue
	FIFO queue with amortized O(1) `push` / `pop`. It keeps moving indices
	instead of shifting the backing array, so it works well for ordered jobs,
	networking backpressure, or turn queues.

	```lua
	local Queue = Weave.Queue

	local jobs = Queue.new()
	jobs:push("a")
	jobs:push("b")

	print(jobs:size())   -- 2
	print(jobs:pop())    -- "a"
	print(jobs:peek())   -- "b"

	while not jobs:isEmpty() do
	    process(jobs:pop())
	end
	```
]=]

local Queue = {}
Queue.__index = Queue

export type Queue<T> = {
	push: (self: Queue<T>, value: T) -> (),
	pop: (self: Queue<T>) -> T?,
	peek: (self: Queue<T>) -> T?,
	size: (self: Queue<T>) -> number,
	isEmpty: (self: Queue<T>) -> boolean,
	clear: (self: Queue<T>) -> (),
	toArray: (self: Queue<T>) -> { T },
}

function Queue.new<T>(initial: { T }?): Queue<T>
	local items: { [number]: T } = {}
	local first = 1
	local last = 0
	if initial then
		for _, value in initial do
			last += 1
			items[last] = value
		end
	end

	local self = setmetatable({
		_items = items,
		_first = first,
		_last = last,
	}, Queue)
	return self :: any
end

function Queue.push<T>(self: Queue<T>, value: T)
	local s: any = self
	s._last += 1
	s._items[s._last] = value
end

function Queue.pop<T>(self: Queue<T>): T?
	local s: any = self
	if s._first > s._last then
		return nil
	end
	local value = s._items[s._first]
	s._items[s._first] = nil
	s._first += 1
	-- Reset after draining so sparse indices do not drift forever.
	if s._first > s._last then
		s._first = 1
		s._last = 0
	end
	return value
end

function Queue.peek<T>(self: Queue<T>): T?
	local s: any = self
	if s._first > s._last then
		return nil
	end
	return s._items[s._first]
end

function Queue.size<T>(self: Queue<T>): number
	local s: any = self
	return s._last - s._first + 1
end

function Queue.isEmpty<T>(self: Queue<T>): boolean
	local s: any = self
	return s._first > s._last
end

function Queue.clear<T>(self: Queue<T>)
	local s: any = self
	table.clear(s._items)
	s._first = 1
	s._last = 0
end

function Queue.toArray<T>(self: Queue<T>): { T }
	local s: any = self
	local out: { T } = {}
	for i = s._first, s._last do
		out[#out + 1] = s._items[i]
	end
	return out
end

return Queue
