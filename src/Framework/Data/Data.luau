--!strict
--[=[
	@module Data.Data
	Per-player reactive data tree. Wraps a plain JSON-compatible Luau
	table and exposes path-based read/write operations plus four
	families of signals fired when the underlying data mutates:

	  * `changed`         - fires when the exact value at a path changes.
	  * `indexChanged`    - fires when any direct child of a path changes.
	  * `arrayInserted`   - fires when a value is `arrayInsert`-ed.
	  * `arrayRemoved`    - fires when a value is `arrayRemove`-d.

	Paths can be supplied either as a flat string (`"currency"`) or as a
	`{ string | number }` array (`{ "tutorial", "step" }`). The latter
	form supports nested access and array indexing.
  
	All signals are built from `Framework.Signal`, so listeners use the
	framework's lowercase API:

	```lua
	data:getChangedSignal("currency"):connect(function(new, old) ... end)
	```
]=]

local Signal = require(script.Parent.Parent.Signal)

local Data = {}
Data.__index = Data

export type Path = string | { string | number }

type ChangedSignal = Signal.Signal<any, any>
type IndexChangedSignal = Signal.Signal<any, any, any>
type ArraySignal = Signal.Signal<number, any>

type SignalStore = {
	changed: { [string]: ChangedSignal },
	indexChanged: { [string]: IndexChangedSignal },
	arrayInserted: { [string]: ArraySignal },
	arrayRemoved: { [string]: ArraySignal },
}

export type Data = typeof(setmetatable(
	{} :: {
		_data: any,
		_signals: SignalStore,
		_destroyed: boolean,
	},
	Data
))

function Data.new(data: any): Data
	return setmetatable({
		_data = data,
		_signals = {
			changed = {},
			indexChanged = {},
			arrayInserted = {},
			arrayRemoved = {},
		},
		_destroyed = false,
	}, Data) :: any
end

local function pathToString(path: Path): string
	if type(path) == "string" then
		return path
	end

	local maxIndex = #path
	local buf = table.create(maxIndex * 2)
	for i, key in path do
		if i > 1 then
			table.insert(buf, ".")
		end
		if type(key) == "number" then
			table.insert(buf, "#")
		end
		table.insert(buf, tostring(key))
	end
	return table.concat(buf)
end

function Data.get(self: Data, path: Path?): any
	if path == nil then
		return self._data
	end

	local node: any = self._data
	if type(path) == "string" then
		return node[path]
	end

	for _, key in path do
		if node == nil then
			return nil
		end
		node = node[key]
	end
	return node
end

function Data.set(self: Data, path: Path, value: any)
	local node: any = self._data
	if type(path) == "string" then
		local prev = node[path]
		node[path] = value
		self:_firePathChangedSignals(path, prev)
		return
	end

	for i = 1, #path - 1 do
		node = node[path[i]]
	end

	local last = path[#path]
	local prev = node[last]
	node[last] = value
	self:_firePathChangedSignals(path, prev)
end

function Data.update(self: Data, path: Path, callback: (any) -> any): any
	local old = self:get(path)
	local new = callback(old)
	self:set(path, new)
	return new
end

function Data.arrayInsert(self: Data, path: Path, value: any, index: number?)
	local array = self:get(path)
	assert(type(array) == "table", `Data: value at path '{pathToString(path)}' is not an array`)

	if index then
		table.insert(array, index, value)
	else
		table.insert(array, value)
	end

	local pathString = self:_firePathChangedSignals(path)
	local signal = self._signals.arrayInserted[pathString]
	if signal then
		signal:fire(index or #array, value)
	end
end

function Data.arrayRemove(self: Data, path: Path, index: number): any
	local array = self:get(path)
	assert(type(array) == "table", `Data: value at path '{pathToString(path)}' is not an array`)

	local value = table.remove(array, index)
	local pathString = self:_firePathChangedSignals(path)
	local signal = self._signals.arrayRemoved[pathString]
	if signal then
		signal:fire(index, value)
	end
	return value
end

function Data.getChangedSignal(self: Data, path: Path): ChangedSignal
	return self:_getOrCreate("changed", pathToString(path)) :: any
end

function Data.getIndexChangedSignal(self: Data, path: Path): IndexChangedSignal
	return self:_getOrCreate("indexChanged", pathToString(path)) :: any
end

function Data.getArrayInsertedSignal(self: Data, path: Path): ArraySignal
	return self:_getOrCreate("arrayInserted", pathToString(path)) :: any
end

function Data.getArrayRemovedSignal(self: Data, path: Path): ArraySignal
	return self:_getOrCreate("arrayRemoved", pathToString(path)) :: any
end

function Data._getOrCreate(self: Data, kind: string, pathString: string): any
	local bucket = (self._signals :: any)[kind]
	local existing = bucket[pathString]
	if existing then
		return existing
	end
	local signal = Signal.new()
	bucket[pathString] = signal
	return signal
end

function Data._firePathChangedSignals(self: Data, path: Path, prev: any?): string
	if type(path) == "string" then
		self:_fireChanged(path, self:get(path), prev)
		return path
	end

	local node: any = self._data
	local pathString = ""

	for i, key in path do
		node = node[key]

		if i > 1 then
			self:_fireIndexChanged(pathString, key, node, prev)
			pathString ..= "."
		end

		if type(key) == "number" then
			pathString ..= "#"
		end
		pathString ..= tostring(key)

		self:_fireChanged(pathString, node, prev)
	end

	return pathString
end

function Data._fireChanged(self: Data, pathString: string, value: any, prev: any?)
	local signal = self._signals.changed[pathString]
	if signal then
		signal:fire(value, prev)
	end
end

function Data._fireIndexChanged(self: Data, pathString: string, index: any, value: any, prev: any?)
	local signal = self._signals.indexChanged[pathString]
	if signal then
		signal:fire(index, value, prev)
	end
end

function Data.destroy(self: Data)
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, bucket in self._signals :: any do
		for _, signal in bucket do
			signal:destroy()
		end
	end
	self._signals = nil :: any
end

return Data
