--!strict
--[=[
	@module Enum
	Type-safe, immutable enums. Each `EnumValue` is its own table identity -
	compare with `==`, and it serializes as a stable string name.

	```lua
	local Direction = Enum.create("Direction", { "North", "East", "South", "West" })
	type Direction = Enum.ValueOf<typeof(Direction)>

	local d: Direction = Direction.North
	print(d.name)        -- "North"
	print(d.ordinal)     -- 1
	print(d == Direction.fromName("North"))  -- true
	```
]=]

local Symbol = require(script.Parent.Symbol)
type Symbol = Symbol.Symbol

local Enum = {}

local TAG_ENUM = Symbol.unique("Enum.tag")
local TAG_VALUE = Symbol.unique("EnumValue.tag")

export type EnumValue = {
	name: string,
	ordinal: number,
	enum: any,
	__tag: Symbol,
}

export type Enum<V> = {
	__name: string,
	__values: { V },
	__byName: { [string]: V },
	__tag: Symbol,
	values: (self: Enum<V>) -> { V },
	fromName: (self: Enum<V>, name: string) -> V?,
	fromOrdinal: (self: Enum<V>, ordinal: number) -> V?,
	contains: (self: Enum<V>, value: any) -> boolean,
	[string]: any,
}

--[=[
	Instance-type helper. Given the table `create` returns,
	`ValueOf<typeof(MyEnum)>` gives you the enum-value type.
]=]
export type ValueOf<E> = EnumValue

--[=[
	Builds a frozen enum from a list of names. Each entry becomes both a
	field on the returned table and an entry in the internal lookup tables.
]=]

function Enum.create(name: string, names: { string }): any
	local self: any = {
		__name = name,
		__tag = TAG_ENUM,
		__values = {},
		__byName = {},
	}

	for ordinal, valueName in names do
		assert(type(valueName) == "string", `enum '{name}': value #{ordinal} is not a string`)
		assert(self[valueName] == nil, `enum '{name}': duplicate value '{valueName}'`)
		local value: EnumValue = {
			name = valueName,
			ordinal = ordinal,
			enum = self,
			__tag = TAG_VALUE,
		}
		table.freeze(value)
		self[valueName] = value
		self.__byName[valueName] = value
		table.insert(self.__values, value)
	end

	function self.values(): { EnumValue }
		return self.__values
	end

	function self.fromName(_, n: string): EnumValue?
		return self.__byName[n]
	end

	function self.fromOrdinal(_, ord: number): EnumValue?
		return self.__values[ord]
	end

	function self.contains(_, value: any): boolean
		return type(value) == "table" and value.__tag == TAG_VALUE and value.enum == self
	end

	table.freeze(self)
	return self
end

function Enum.is(value: any): boolean
	return type(value) == "table" and value.__tag == TAG_ENUM
end

function Enum.isValue(value: any): boolean
	return type(value) == "table" and value.__tag == TAG_VALUE
end

return Enum
