--!strict
--[=[
	@controller MonetizationController
	Boots `Monetization.client` on the client (purchase prompts and
	purchase-finished signals). Other controllers list
	`Dependencies = { "MonetizationController" }` when they need it first.

	Usage (typed via direct require):
	```lua
	local MonetizationController = require(StarterPlayerScripts.Client.Controllers.MonetizationController)

	MonetizationController:PromptGamePassPurchase(987654)
	MonetizationController.GamePassPurchaseFinished:connect(function(gamePassId, purchased)
	    if purchased then
	        print("purchased", gamePassId)
	    end
	end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

export type Class = Framework.MonetizationControllerClass

local MonetizationController: Class = Framework.CreateMonetizationController({
	Name = "MonetizationController",
})

local baseStart = MonetizationController.Start

function MonetizationController:Start()
	baseStart(self)

	MonetizationController.GamePassPurchaseFinished:connect(function(gamePassId, purchased)
		if purchased then
			print(`[MonetizationController] purchased game pass {gamePassId}`)
		end
	end)
end

return MonetizationController
