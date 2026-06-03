--!strict
--[=[
	@module FFlags.Networking
	Private remotes used to replicate read-only FFlags snapshots and updates
	from server to client.
]=]

local Networking = require(script.Parent.Parent.Networking)
local Types = require(script.Parent.Types)

local Bank = Networking.Bank("FFlags")

export type Snapshot = { [string]: Types.FlagValue }
export type UpdatePayload = {
	Name: string,
	Value: Types.FlagValue?,
	OldValue: Types.FlagValue?,
	Removed: boolean?,
	Source: Types.ChangeSource,
}

return {
	Snapshot = Bank:Request("Snapshot") :: Networking.Request<nil, Snapshot>,
	Update = Bank:Event("Update") :: Networking.Event<UpdatePayload>,
}
