--!strict
--[=[
	@module Util.Observer.Types
	Shared types for the observer library.
]=]

export type Cleanup = () -> ()
export type Stop = () -> ()

export type TagCallback = (instance: Instance) -> Cleanup?
export type ChildCallback = (child: Instance) -> Cleanup?
export type PlayerCallback = (player: Player) -> Cleanup?
export type CharacterCallback = (player: Player, character: Model) -> Cleanup?
export type ValueCallback = (value: any) -> Cleanup?

return {}
