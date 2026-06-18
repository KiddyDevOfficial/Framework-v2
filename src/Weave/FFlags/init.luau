--!strict
--[=[
	@module FFlags
	Global runtime flags synced across live servers over `GlobalMessaging`.

	```lua
	local FFlags = require(ReplicatedStorage.Weave).FFlags.server
	FFlags:init({ Defaults = { DoubleXP = false } })

	FFlags:observe("DoubleXP", function(value)
	    print("DoubleXP changed:", value)
	end)

	FFlags:set("DoubleXP", true)
	```
]=]

local Server = require(script.Server)
local Client = require(script.Client)
local Types = require(script.Types)

export type Server = Types.ServerClass
export type Client = Types.ClientClass
export type ServerClass = Types.ServerClass
export type ClientClass = Types.ClientClass
export type FlagValue = Types.FlagValue
export type ChangeSource = Types.ChangeSource
export type ChangeHandler = Types.ChangeHandler
export type InitOptions = Types.InitOptions

return {
	server = Server :: Types.ServerClass,
	client = Client :: Types.ClientClass,
}
