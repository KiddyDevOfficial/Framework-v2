--!strict
--[=[
	@module Util.TableUtil
	Pure-Lua helpers the stock `table` library doesn't have.
	Three ways to combine tables:
	  * `merge(a, b)`     - shallow; keys from `b` overwrite `a`.
	  * `deepMerge(a, b)` - recursive; `b` wins on leaves.
	  * `reconcile(t, template)` - fills missing keys from `template`
	    (the DataService template reconcile pattern).
]=]

local TableUtil = {}

function TableUtil.isEmpty(t: { [any]: any }): boolean
	return next(t) == nil
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.keys<K, V>(t: { [K]: V }): { K }
	local out: { K } = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

function TableUtil.values<K, V>(t: { [K]: V }): { V }
	local out: { V } = {}
	for _, v in t do
		table.insert(out, v)
	end
	return out
end

function TableUtil.find<V>(arr: { V }, predicate: (V, number) -> boolean): (V?, number?)
	for i, v in arr do
		if predicate(v, i) then
			return v, i
		end
	end
	return nil, nil
end

function TableUtil.filter<V>(arr: { V }, predicate: (V, number) -> boolean): { V }
	local out: { V } = {}
	for i, v in arr do
		if predicate(v, i) then
			table.insert(out, v)
		end
	end
	return out
end

function TableUtil.map<V, R>(arr: { V }, mapper: (V, number) -> R): { R }
	local out: { R } = {}
	for i, v in arr do
		out[i] = mapper(v, i)
	end
	return out
end

function TableUtil.reduce<V, A>(arr: { V }, reducer: (A, V, number) -> A, initial: A): A
	local acc = initial
	for i, v in arr do
		acc = reducer(acc, v, i)
	end
	return acc
end

function TableUtil.any<V>(arr: { V }, predicate: (V, number) -> boolean): boolean
	for i, v in arr do
		if predicate(v, i) then
			return true
		end
	end
	return false
end

function TableUtil.every<V>(arr: { V }, predicate: (V, number) -> boolean): boolean
	for i, v in arr do
		if not predicate(v, i) then
			return false
		end
	end
	return true
end

function TableUtil.contains<V>(arr: { V }, value: V): boolean
	return table.find(arr, value) ~= nil
end

function TableUtil.reverse<V>(arr: { V }): { V }
	local out: { V } = {}
	local n = #arr
	for i = 1, n do
		out[i] = arr[n - i + 1]
	end
	return out
end

function TableUtil.shuffle<V>(arr: { V }, rng: Random?): { V }
	local r = rng or Random.new()
	local out = table.clone(arr)
	for i = #out, 2, -1 do
		local j = r:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

function TableUtil.shallowCopy<T>(t: T): T
	return table.clone(t :: any) :: any
end

--[=[
	Recursive copy. Cycles raise an error.
]=]
function TableUtil.deepCopy<T>(t: T): T
	local function copy(source: any, seen: { [any]: any })
		if type(source) ~= "table" then
			return source
		end
		local existing = seen[source]
		if existing then
			error("[TableUtil.deepCopy] cyclic reference detected", 0)
		end
		seen[source] = source
		local out: any = {}
		for k, v in source do
			out[k] = copy(v, seen)
		end
		seen[source] = nil
		return out
	end
	return copy(t, {}) :: any
end

--[=[
	Shallow merge. Keys in `b` overwrite `a`. Returns a new table.
]=]
function TableUtil.merge<A, B>(a: A & { [any]: any }, b: B & { [any]: any }): A & B
	local out: any = table.clone(a :: any)
	for k, v in b :: any do
		out[k] = v
	end
	return out
end

--[=[
	Recursive merge - tables get merged, leaves overwritten. Arrays
	(contiguous numeric-keyed tables) are replaced whole, not merged.
]=]
function TableUtil.deepMerge<A, B>(a: A & { [any]: any }, b: B & { [any]: any }): A & B
	local function isArray(t: any): boolean
		if type(t) ~= "table" then
			return false
		end
		local n = 0
		for _ in t do
			n += 1
		end
		return #t == n
	end

	local function merge(left: any, right: any): any
		if type(left) ~= "table" or type(right) ~= "table" or isArray(left) or isArray(right) then
			return right
		end
		local out: any = table.clone(left)
		for k, v in right do
			out[k] = merge(out[k], v)
		end
		return out
	end

	return merge(a, b) :: any
end

--[=[
	Mutates `t` in place, filling missing keys from `template`. The data-template
	reconcile: existing values stay put, new template keys get deep-copied in.
]=]
function TableUtil.reconcile(t: { [any]: any }, template: { [any]: any })
	for k, v in template do
		if t[k] == nil then
			t[k] = type(v) == "table" and TableUtil.deepCopy(v) or v
		elseif type(v) == "table" and type(t[k]) == "table" then
			TableUtil.reconcile(t[k], v)
		end
	end
end

function TableUtil.freeze<T>(t: T): T
	table.freeze(t :: any)
	return t
end

function TableUtil.deepFreeze<T>(t: T): T
	if type(t) == "table" and not table.isfrozen(t :: any) then
		for _, v in t :: any do
			TableUtil.deepFreeze(v)
		end
		table.freeze(t :: any)
	end
	return t
end

return TableUtil
