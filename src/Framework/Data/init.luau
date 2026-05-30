--!strict
--[=[
	@module Data
	Framework-native, self-contained DataService. Replaces the
	[`leifstout/dataservice`](https://github.com/leifstout/dataService)
	Wally package: same shape (`{ server, client }`), zero external
	dependencies.

	Persistence is a thin `DataStoreService` wrapper with session locking,
	auto-save and a Studio-friendly in-memory mock; replication goes
	through a single RemoteEvent + RemoteFunction managed under
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
