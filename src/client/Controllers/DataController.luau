--!strict
--[=[
	@controller DataController
	Boots `DataService.client` on the client. Its `init` yields until the
	server pushes the initial snapshot, which is why the adapter runs it
	in `Start` (the yield-allowed lifecycle phase).

	Other controllers list `Dependencies = { "DataController" }` and call
	`Data:WaitForData()` if they need to be fully defensive.

	Usage (typed via direct require):
	```lua
	local DataController = require(StarterPlayerScripts.Client.Controllers.DataController)

	DataController:WaitForData()
	print("currency:", DataController:Get("currency"))
	DataController:GetChangedSignal("currency"):connect(function(value)
	    print("currency replicated:", value)
	end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

export type Class = Framework.DataControllerClass

local DataController: any = Framework.CreateDataController({
	Name = "DataController",
})

local baseStart = DataController.Start

function DataController:Start()
	baseStart(self)
	print("[DataController] initial snapshot received")
end

return DataController :: Class
