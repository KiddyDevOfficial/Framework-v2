--!strict
--[=[
	@module DataTemplate
	Default per-player data shape for the built-in `DataService`. Keep every
	value JSON-compatible (numbers, strings, booleans, arrays, dictionaries).
	New keys added here are auto-reconciled into existing profiles on join.

	`export type DataTemplate` drives path autocomplete on `DataService` /
	`DataController` (`"currency"`, `{ "settings", "musicVolume" }`, …).
]=]

local DataTemplate = {
	currency = 0,
	level = 1,
	xp = 0,
	inventory = {} :: { string },
	settings = {
		musicVolume = 0.5,
		sfxVolume = 0.5,
	},
}

export type DataTemplate = typeof(DataTemplate)

export type PathSegment =
	"currency"
	| "level"
	| "xp"
	| "inventory"
	| "settings"
	| "musicVolume"
	| "sfxVolume"

export type Path = PathSegment | { PathSegment | number }

export type ArrayPath = "inventory" | { "inventory" | number }

return DataTemplate
