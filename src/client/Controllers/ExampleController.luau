--!strict
--[=[
	@controller ExampleController
	Starter controller showing the framework lifecycle on the client. Return
	a plain table; the Loader stamps it and registers it by its ModuleScript
	name. Delete or copy this file to start your own controllers.

	Lifecycle (all optional): `Init` -> `Start` -> `Heartbeat` / `RenderStep`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local ExampleController = {
	Dependencies = {} :: { string },
}

function ExampleController:Init()
	-- Boot the client monetization layer (prompts + purchase signals).
	Framework.Monetization.client:init()

	Framework.Monetization.client.GamePassPurchaseFinished:connect(function(gamePassId, purchased)
		if purchased then
			print(`[ExampleController] purchased game pass {gamePassId}`)
		end
	end)
end

function ExampleController:Start()
	print("[ExampleController] started on the client.")
end

return ExampleController
