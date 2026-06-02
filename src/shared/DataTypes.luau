--!strict
--[=[
	@module DataTypes
	Re-exports the player data schema and path helpers for use outside
	`DataService` / `DataController` modules (e.g. UI, shared systems).

	```lua
	local DataTypes = require(ReplicatedStorage.Shared.DataTypes)
	type Path = DataTypes.Path
	```
]=]

local DataTemplate = require(script.Parent.DataTemplate)

export type PlayerData = DataTemplate.DataTemplate
export type Path = DataTemplate.Path
export type ArrayPath = DataTemplate.ArrayPath

return nil
