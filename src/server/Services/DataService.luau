--!strict
--[=[
	@service DataService
	Boots the framework-native DataService on the server with the shared
	`DataTemplate`. Other services list `Dependencies = { "DataService" }`
	to be guaranteed a live profile store before their own `Init` runs.

	Usage (typed via direct require - the module *is* the singleton):
	```lua
	local DataService = require(ServerScriptService.Server.Services.DataService)

	DataService:WaitForData(player)
	DataService:Update(player, "currency", function(c) return c + 100 end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local DataTemplate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DataTemplate"))

local USE_MOCK = false and RunService:IsStudio()
export type Class = Framework.DataServiceClass

return Framework.CreateDataService({
	Name = "DataService",
	Template = DataTemplate,
	ProfileStoreIndex = "PlayerData",
	UseMock = USE_MOCK,
	OnPlayerInit = function(_self, player, data)
		data.stats = data.stats or { playTime = 0, joinCount = 0 }
		data.stats.joinCount += 1
		print(`[DataService] {player.Name} profile loaded (joinCount = {data.stats.joinCount})`)
	end,
})
