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

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))

export type Class = Weave.MonetizationControllerClass

local MonetizationController: Class = Weave.CreateMonetizationController({
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
