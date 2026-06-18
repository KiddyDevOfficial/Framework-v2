--!strict
--[=[
	@service LeaderstatsService
	Syncs configured `DataService` values into each player's leaderstats folder.
	Updates automatically when data is set or changed through `DataService`.

	Usage:
	```lua
	local Leaderstats = require(ReplicatedStorage.Shared.Leaderstats)
	-- edit Leaderstats.Entries to choose displayed stats
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))
local DataService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DataService"))
local LeaderstatsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Leaderstats"))

export type Class = Atlas.LeaderstatsServiceClass

local LeaderstatsService: Class = Atlas.CreateLeaderstatsService({
	Name = "LeaderstatsService",
	Entries = LeaderstatsConfig.Entries,
	DataService = DataService,
})

return LeaderstatsService
