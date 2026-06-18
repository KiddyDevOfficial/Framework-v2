--!strict
--[=[
	@module Util.Cache
	In-memory cache with optional LRU eviction and TTL expiry. Useful for
	expensive lookups like product info, group ranks, or pathfinding results.

	* `maxSize` - once you go over it, the least-recently-used entry is dropped
	* `ttl`     - seconds an entry stays valid; expired entries get dropped
	              lazily on the next access (`os.clock` based, monotonic)

	Leave both out and it's just an unbounded table with a nicer API.

	```lua
	local Cache = Atlas.Cache

	local prices = Cache.new({ maxSize = 200, ttl = 60 })

	local function priceOf(id: number): number
	    local hit = prices:get(id)
	    if hit ~= nil then
	        return hit
	    end
	    local info = MarketplaceService:GetProductInfo(id)
	    prices:set(id, info.PriceInRobux or 0)
	    return prices:get(id) :: number
	end
	```
]=]

local Cache = {}
Cache.__index = Cache

export type Options = {
	maxSize: number?,
	ttl: number?,
}

export type Cache<K, V> = {
	set: (self: Cache<K, V>, key: K, value: V) -> (),
	get: (self: Cache<K, V>, key: K) -> V?,
	has: (self: Cache<K, V>, key: K) -> boolean,
	remove: (self: Cache<K, V>, key: K) -> (),
	clear: (self: Cache<K, V>) -> (),
	size: (self: Cache<K, V>) -> number,
	keys: (self: Cache<K, V>) -> { K },
}

function Cache.new<K, V>(options: Options?): Cache<K, V>
	local opts: Options = options or {}
	local self = setmetatable({
		_values = {} :: { [K]: V },
		_expiry = {} :: { [K]: number },
		_order = {} :: { K },
		_maxSize = opts.maxSize,
		_ttl = opts.ttl,
	}, Cache)
	return self :: any
end

local function indexOf(order: { any }, key: any): number?
	for i, k in order do
		if k == key then
			return i
		end
	end
	return nil
end

local function touch(s: any, key: any)
	local i = indexOf(s._order, key)
	if i then
		table.remove(s._order, i)
	end
	table.insert(s._order, key)
end

local function drop(s: any, key: any)
	s._values[key] = nil
	s._expiry[key] = nil
	local i = indexOf(s._order, key)
	if i then
		table.remove(s._order, i)
	end
end

local function isLive(s: any, key: any): boolean
	if s._values[key] == nil then
		return false
	end
	local deadline = s._expiry[key]
	if deadline ~= nil and os.clock() >= deadline then
		drop(s, key)
		return false
	end
	return true
end

function Cache.set<K, V>(self: Cache<K, V>, key: K, value: V)
	local s: any = self
	local existed = s._values[key] ~= nil
	s._values[key] = value
	if s._ttl ~= nil then
		s._expiry[key] = os.clock() + s._ttl
	end
	touch(s, key)

	if not existed and s._maxSize ~= nil then
		while #s._order > s._maxSize do
			drop(s, s._order[1])
		end
	end
end

function Cache.get<K, V>(self: Cache<K, V>, key: K): V?
	local s: any = self
	if not isLive(s, key) then
		return nil
	end
	touch(s, key)
	return s._values[key]
end

function Cache.has<K, V>(self: Cache<K, V>, key: K): boolean
	return isLive(self :: any, key)
end

function Cache.remove<K, V>(self: Cache<K, V>, key: K)
	drop(self :: any, key)
end

function Cache.clear<K, V>(self: Cache<K, V>)
	local s: any = self
	table.clear(s._values)
	table.clear(s._expiry)
	table.clear(s._order)
end

function Cache.size<K, V>(self: Cache<K, V>): number
	return #(self :: any)._order
end

function Cache.keys<K, V>(self: Cache<K, V>): { K }
	return table.clone((self :: any)._order)
end

return Cache
