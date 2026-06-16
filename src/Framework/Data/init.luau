--!strict
--[=[
	@module Data
	Framework-native DataService shaped like
	[`leifstout/dataservice`](https://github.com/leifstout/dataService)
	(`{ server, client }`).

	Persistence runs on
	[MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)
	(vendored at `./ProfileStore.luau`) through the `Profile` adapter, so you
	get session locking, periodic auto-save, template reconciliation, a Studio
	mock and a cross-server message queue. Replication rides a single
	RemoteEvent + RemoteFunction under
	`ReplicatedStorage/_FrameworkDataService`.

	You usually won't touch this module directly - `Framework.CreateDataService`
	and `Framework.CreateDataController` wrap it into a Service / Controller
	that boots in the loader's dependency order.

	```lua
	local Framework = require(ReplicatedStorage.Framework)
	Framework.DataService.server:init({ template = ... })   -- server
	Framework.DataService.client:init()                     -- client
	```
]=]

local Server = require(script.Server)
local Client = require(script.Client)
local Data = require(script.Data)
local Paths = require(script.Paths)
local Migration = require(script.Migration)

export type Server = typeof(Server)
export type Client = typeof(Client)
export type Data = Data.Data
export type Path = Data.Path
export type AnyPath = Paths.Path
export type AnyArrayPath = Paths.ArrayPath
export type Migrator = Migration.Migrator
export type MigrationConfig = Migration.Config

return {
	server = Server,
	client = Client,
	Data = Data,
	Paths = Paths,
	Migration = Migration,
}
