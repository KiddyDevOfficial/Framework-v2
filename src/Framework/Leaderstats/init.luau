--!strict
--[=[
	@module Leaderstats
	Mirrors the `DataService` paths you configure into each player's leaderstats folder.

	```lua
	local Leaderstats = require(ReplicatedStorage.Framework).Leaderstats.server
	Leaderstats:init({
	    Entries = require(ReplicatedStorage.Shared.Leaderstats).Entries,
	    DataService = require(ServerScriptService.Server.Services.DataService),
	})
	```
]=]

local Server = require(script.Server)
local Types = require(script.Types)

export type Server = Types.ServerClass
export type ServerClass = Types.ServerClass
export type Entry = Types.Entry
export type ValueClass = Types.ValueClass
export type InitOptions = Types.InitOptions

return {
	server = Server :: Types.ServerClass,
}
