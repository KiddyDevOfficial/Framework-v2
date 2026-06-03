--!strict
--[=[
	@module Leaderstats
	Configure which `DataService` values appear in each player's leaderstats
	folder. Paths must match keys/paths in `Shared/DataTemplate.luau`.
]=]

export type Entry = {
	Path: string | { string | number },
	Name: string,
	Class: ("IntValue" | "NumberValue" | "StringValue")?,
}

local Leaderstats = {}

Leaderstats.Entries = {
	{
		Path = "level",
		Name = "Level",
		Class = "IntValue",
	},
	{
		Path = "xp",
		Name = "XP",
		Class = "IntValue",
	},
} :: { Entry }

return Leaderstats
