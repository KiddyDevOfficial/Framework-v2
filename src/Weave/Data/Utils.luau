--!strict
--[=[
	@module Data.Utils
	Wire-protocol enums and small shared helpers used by both `Server` and
	`Client`. The numeric `Action` values are what actually go over the
	replication `RemoteEvent`, so both sides have to agree on them - never
	reorder them.
]=]

local Utils = {}

Utils.Action = {
	Init = 0,
	Set = 1,
	ArrayInsert = 2,
	ArrayRemove = 3,
}

export type Action = number

return Utils
