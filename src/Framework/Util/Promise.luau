--!strict
--[=[
	@module Util.Promise
	Small Promise (roughly A+) - covers the common case, doesn't try to clone the
	spec word for word. Resolutions chain on threads, so handlers never block the
	caller.

	```lua
	Promise.new(function(resolve, reject)
	    task.wait(1)
	    resolve("done")
	end):andThen(function(v)
	    print("got:", v)
	end):catch(function(err)
	    warn(err)
	end)
	```
]=]

local Promise = {}
Promise.__index = Promise

local STATE_PENDING = "pending"
local STATE_RESOLVED = "resolved"
local STATE_REJECTED = "rejected"

export type State = "pending" | "resolved" | "rejected"

export type Promise<T> = {
	getState: (self: Promise<T>) -> State,
	andThen: <R>(self: Promise<T>, onResolved: (T) -> R) -> Promise<R>,
	catch: (self: Promise<T>, onRejected: (string) -> ()) -> Promise<T>,
	finally: (self: Promise<T>, callback: () -> ()) -> Promise<T>,
	await: (self: Promise<T>) -> (boolean, T | string),
	expect: (self: Promise<T>) -> T,
}

local function new<T>(executor: ((T) -> (), (string) -> ()) -> ()): Promise<T>
	local self = setmetatable({
		_state = STATE_PENDING :: State,
		_value = nil :: any,
		_error = nil :: string?,
		_thens = {} :: { (any) -> () },
		_catches = {} :: { (string) -> () },
	}, Promise)

	local function resolve(value: any)
		if self._state ~= STATE_PENDING then
			return
		end
		self._state = STATE_RESOLVED
		self._value = value
		for _, cb in self._thens do
			task.spawn(cb, value)
		end
		self._thens = {}
		self._catches = {}
	end

	local function reject(err: any)
		if self._state ~= STATE_PENDING then
			return
		end
		self._state = STATE_REJECTED
		self._error = tostring(err)
		for _, cb in self._catches do
			task.spawn(cb, self._error)
		end
		self._thens = {}
		self._catches = {}
	end

	task.spawn(function()
		local ok, err = pcall(executor, resolve :: any, reject :: any)
		if not ok then
			reject(err)
		end
	end)

	return self :: any
end

Promise.new = new

function Promise.resolve<T>(value: T): Promise<T>
	return new(function(res)
		res(value)
	end)
end

function Promise.reject<T>(err: string): Promise<T>
	return new(function(_, rej)
		rej(err)
	end)
end

function Promise:getState(): State
	return (self :: any)._state
end

function Promise:andThen<R>(onResolved: (any) -> R): Promise<R>
	local s: any = self
	return new(function(res, rej)
		local function handle(value: any)
			local ok, result = pcall(onResolved, value)
			if ok then
				res(result :: any)
			else
				rej(tostring(result))
			end
		end

		if s._state == STATE_RESOLVED then
			task.spawn(handle, s._value)
		elseif s._state == STATE_REJECTED then
			rej(s._error)
		else
			table.insert(s._thens, handle)
			table.insert(s._catches, function(err)
				rej(err)
			end)
		end
	end)
end

function Promise:catch(onRejected: (string) -> ()): Promise<any>
	local s: any = self
	return new(function(res, rej)
		local function handle(err: string)
			local ok, result = pcall(onRejected, err)
			if ok then
				res(result :: any)
			else
				rej(tostring(result))
			end
		end

		if s._state == STATE_RESOLVED then
			res(s._value)
		elseif s._state == STATE_REJECTED then
			task.spawn(handle, s._error)
		else
			table.insert(s._thens, function(value)
				res(value)
			end)
			table.insert(s._catches, handle)
		end
	end)
end

function Promise:finally(callback: () -> ()): Promise<any>
	local s: any = self
	return new(function(res, rej)
		local function fire()
			pcall(callback)
		end
		if s._state == STATE_RESOLVED then
			fire()
			res(s._value)
		elseif s._state == STATE_REJECTED then
			fire()
			rej(s._error)
		else
			table.insert(s._thens, function(value)
				fire()
				res(value)
			end)
			table.insert(s._catches, function(err)
				fire()
				rej(err)
			end)
		end
	end)
end

--[=[
	Yields until the promise settles. Returns `(true, value)` on resolve,
	`(false, errMessage)` on reject.
]=]
function Promise:await(): (boolean, any)
	local s: any = self
	if s._state == STATE_RESOLVED then
		return true, s._value
	elseif s._state == STATE_REJECTED then
		return false, s._error
	end

	local thread = coroutine.running()
	table.insert(s._thens, function(value)
		task.spawn(thread, true, value)
	end)
	table.insert(s._catches, function(err)
		task.spawn(thread, false, err)
	end)
	return coroutine.yield()
end

function Promise:expect(): any
	local ok, value = self:await()
	if not ok then
		error(value, 2)
	end
	return value
end

--[=[
	Resolves with `{ value, ... }` once they all resolve. Rejects on the first
	rejection.
]=]
function Promise.all(promises: { Promise<any> }): Promise<{ any }>
	return new(function(res, rej)
		local results: { any } = {}
		local remaining = #promises
		if remaining == 0 then
			res(results)
			return
		end
		for i, p in promises do
			p:andThen(function(value)
				results[i] = value
				remaining -= 1
				if remaining == 0 then
					res(results)
				end
				return nil
			end):catch(function(err)
				rej(err)
			end)
		end
	end)
end

function Promise.race(promises: { Promise<any> }): Promise<any>
	return new(function(res, rej)
		for _, p in promises do
			p:andThen(function(value)
				res(value)
				return nil
			end):catch(function(err)
				rej(err)
			end)
		end
	end)
end

function Promise.delay(seconds: number): Promise<number>
	return new(function(res)
		task.delay(seconds, function()
			res(seconds)
		end)
	end)
end

return Promise
