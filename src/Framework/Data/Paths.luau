--!strict
--[=[
	@module Data.Paths
	Runtime helpers and broad fallback types for the data path API.

	Luau can't derive nested tuple-path unions from arbitrary table types in a
	plain type alias, so game-specific path autocomplete has to come from the
	schema module itself, e.g. `Shared.DataTemplate.Path`.
]=]

local Paths = {}

export type Path = string | { string | number }
export type ArrayPath = Path

function Paths.toString(path: string | { any }): string
	if type(path) == "string" then
		return path
	end
	local parts = table.create(#path * 2)
	for i, key in path do
		if i > 1 then
			table.insert(parts, ".")
		end
		if type(key) == "number" then
			table.insert(parts, "#")
		end
		table.insert(parts, tostring(key))
	end
	return table.concat(parts)
end

return Paths
