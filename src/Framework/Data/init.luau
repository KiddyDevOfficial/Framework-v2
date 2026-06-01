--!strict
--[=[
	@module Data
	Framework-native DataService with a
	[`leifstout/dataservice`](https://github.com/leifstout/dataService)-style
	shape (`{ server, client }`).

	Persistence is backed by
	[MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)
	(vendored at `./ProfileStore.luau`) through the `Profile` adapter, giving
	session locking, periodic auto-save, template reconciliation, a Studio mock
	and a cross-server message queue. Replication goes through a single
	RemoteEvent + RemoteFunction managed under
	`ReplicatedStorage/_FrameworkDataService`.

	Most users won't touch this module directly - `Framework.CreateDataService`
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

export type Server = typeof(Server)
export type Client = typeof(Client)
export type Data = Data.Data
export type Path = Data.Path

return {
	server = Server,
	client = Client,
	Data = Data,
}
