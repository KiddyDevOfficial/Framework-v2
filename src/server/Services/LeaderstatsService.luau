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

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local DataService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("DataService"))
local LeaderstatsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Leaderstats"))

export type Class = Weave.LeaderstatsServiceClass

local LeaderstatsService: Class = Weave.CreateLeaderstatsService({
	Name = "LeaderstatsService",
	Entries = LeaderstatsConfig.Entries,
	DataService = DataService,
})

return LeaderstatsService
