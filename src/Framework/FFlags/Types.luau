--!strict
--[=[
	@module FFlags.Types
	Types for global runtime flags synchronized across live servers through
	`GlobalMessaging`.
]=]

local Signal = require(script.Parent.Parent.Signal)

export type FlagValue = boolean | number | string

export type ChangeSource = "default" | "local" | "remote"

export type ChangeHandler = (value: FlagValue?, oldValue: FlagValue?, source: ChangeSource) -> ()

export type InitOptions = {
	Defaults: { [string]: FlagValue }?,
}

export type FlagChangedPayload = {
	Name: string,
	Value: FlagValue?,
	Removed: boolean?,
	SourceJobId: string,
}

export type ServerClass = {
	Changed: Signal.Signal<string, FlagValue?, FlagValue?, ChangeSource>,
	init: (self: ServerClass, options: InitOptions?) -> (),
	destroy: (self: ServerClass) -> (),
	get: (self: ServerClass, name: string, defaultValue: FlagValue?) -> FlagValue?,
	getAll: (self: ServerClass) -> { [string]: FlagValue },
	set: (self: ServerClass, name: string, value: FlagValue) -> boolean,
	setLocal: (self: ServerClass, name: string, value: FlagValue, source: ChangeSource?) -> (),
	remove: (self: ServerClass, name: string) -> boolean,
	removeLocal: (self: ServerClass, name: string, source: ChangeSource?) -> (),
	observe: (self: ServerClass, name: string, handler: ChangeHandler) -> () -> (),
}

export type ClientClass = {
	Changed: Signal.Signal<string, FlagValue?, FlagValue?, ChangeSource>,
	init: (self: ClientClass) -> (),
	destroy: (self: ClientClass) -> (),
	waitForReady: (self: ClientClass) -> (),
	isReady: (self: ClientClass) -> boolean,
	get: (self: ClientClass, name: string, defaultValue: FlagValue?) -> FlagValue?,
	getAll: (self: ClientClass) -> { [string]: FlagValue },
	observe: (self: ClientClass, name: string, handler: ChangeHandler) -> () -> (),
}

return {}
