--!nocheck
--[=[
	@service DataService
	Boots the framework-native DataService on the server with the shared
	`DataTemplate`. Other services list `Dependencies = { "DataService" }`
	to be guaranteed a live profile store before their own `Init` runs.

	Usage (typed via direct require - paths autocomplete from `DataTemplate`):
	```lua
	local DataService = require(ServerScriptService.Server.Services.DataService)

	DataService:WaitForData(player)
	DataService:Update(player, "currency", function(c) return c + 100 end)
	DataService:Update(player, { "settings", "musicVolume" }, function(v) return v + 0.1 end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local DataTemplate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DataTemplate"))

type PlayerData = DataTemplate.DataTemplate
type PlayerDataPath = DataTemplate.Path
type PlayerDataArrayPath = DataTemplate.ArrayPath

local USE_MOCK = false and RunService:IsStudio()

export type Class = Weave.DataServiceClass<PlayerData, PlayerDataPath, PlayerDataArrayPath>
export type Path = PlayerDataPath

local DataService: Class = Weave.CreateDataService({
	Name = "DataService",
	Template = DataTemplate,
	ProfileStoreIndex = "PlayerData",
	UseMock = USE_MOCK,
	OnPlayerInit = function(_self, player, data: PlayerData)
		local extended = data :: any
		extended.stats = extended.stats or { playTime = 0, joinCount = 0 }
		extended.stats.joinCount += 1
		print(`[DataService] {player.Name} profile loaded (joinCount = {extended.stats.joinCount})`)
	end,
})

return DataService
