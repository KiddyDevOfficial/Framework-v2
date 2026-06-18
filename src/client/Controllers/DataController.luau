--!strict
--[=[
	@controller DataController
	Boots `DataService.client` on the client. Its `init` yields until the
	server pushes the initial snapshot, which is why the adapter runs it
	in `Start` (the yield-allowed lifecycle phase).

	Usage (typed via direct require - paths autocomplete from `DataTemplate`):
	```lua
	local DataController = require(StarterPlayerScripts.Client.Controllers.DataController)

	DataController:WaitForData()
	print("currency:", DataController:Get("currency"))
	DataController:Get({ "settings", "musicVolume" })
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local DataTemplate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DataTemplate"))

type PlayerData = DataTemplate.DataTemplate
type PlayerDataPath = DataTemplate.Path
type PlayerDataArrayPath = DataTemplate.ArrayPath

export type Class = Weave.DataControllerClass<PlayerData, PlayerDataPath, PlayerDataArrayPath>
export type Path = PlayerDataPath

local DataController: Class = Weave.CreateDataController({
	Name = "DataController",
	Template = DataTemplate,
})

local baseStart = DataController.Start

function DataController:Start()
	baseStart(self)
	print("[DataController] initial snapshot received")
end

return DataController
