--!strict
--[=[
	@module Symbol
	Opaque, comparable identifiers. Two symbols created with the same name
	are NOT equal unless created via `Symbol.named` (which is interned).

	Useful for:
	  * Private keys on tables (no string collision).
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
	Returns a globally-interned symbol. Calling `Symbol.named("X")` twice
	returns the exact same symbol (referentially equal).
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
	Returns a brand-new symbol every call, even if the name matches another.
	Use when you want a private, untforgeable token.
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
