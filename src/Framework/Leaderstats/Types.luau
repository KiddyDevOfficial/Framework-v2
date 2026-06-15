--!strict
--[=[
	@module Leaderstats.Types
	Types for piping DataService values into player leaderstats.
]=]

export type ValueClass = "IntValue" | "NumberValue" | "StringValue"

export type Entry = {
	-- DataService path (`"currency"`, `{ "settings", "musicVolume" }`, ...)
	Path: string | { string | number },
	-- Instance name under the player's leaderstats folder
	Name: string,
	-- Left out? We pick IntValue / NumberValue / StringValue from the current value
	Class: ValueClass?,
}

export type InitOptions = {
	Entries: { Entry },
	DataService: DataServiceLike,
	FolderName: string?,
}

export type DataServiceLike = {
	WaitForData: (self: DataServiceLike, player: Player) -> any,
	Get: (self: DataServiceLike, player: Player, path: Entry.Path?) -> any,
	GetChangedSignal: (self: DataServiceLike, player: Player, path: Entry.Path) -> any,
}

export type ServerClass = {
	init: (self: ServerClass, options: InitOptions) -> (),
	destroy: (self: ServerClass) -> (),
	mountPlayer: (self: ServerClass, player: Player) -> (),
	unmountPlayer: (self: ServerClass, player: Player) -> (),
}

return {}
