--!strict
--[=[
	@module Symbol
	Opaque, comparable identifiers. Two symbols with the same name are only equal
	when they come from `Symbol.named`.

	Good for:
	  * Private table keys (no string collisions).
	  * Sentinels (NONE, MISSING, ANY, ...).
	  * Tagged unions / discriminators.
]=]

local Symbol = {}
Symbol.__index = Symbol

export type Symbol = typeof(setmetatable(
	{} :: {
		name: string,
		_interned: boolean,
	},
	Symbol
))

local intern: { [string]: Symbol } = {}

--[=[
	Globally interned symbol; the same name returns the same object.
]=]
function Symbol.named(name: string): Symbol
	local cached = intern[name]
	if cached then
		return cached
	end
	local self = setmetatable({
		name = name,
		_interned = true,
	}, Symbol)
	intern[name] = self
	return self
end

--[=[
	Brand-new symbol every call, even when the name matches another.
]=]
function Symbol.unique(name: string): Symbol
	return setmetatable({
		name = name,
		_interned = false,
	}, Symbol)
end

function Symbol.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Symbol
end

function Symbol.__tostring(self: Symbol): string
	return `Symbol({self.name})`
end


return Symbol
