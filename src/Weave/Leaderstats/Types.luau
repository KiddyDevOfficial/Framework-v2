--!strict
--[=[
	@module Leaderstats.Types
	Types for piping DataService values into player leaderstats.
]=]

export type ValueClass = "IntValue" | "NumberValue" | "StringValue"

export type Entry = {
	Path: string | { string | number },
	Name: string,
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
