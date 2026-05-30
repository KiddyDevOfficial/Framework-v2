--!strict
--[=[
	@service MonetizationService
	Boots `Monetization.server` on the server (`ProcessReceipt`, product
	handlers, game-pass cache). Other services list
	`Dependencies = { "MonetizationService" }` to run after it is live.

	Usage (typed via direct require):
	```lua
	local MonetizationService = require(ServerScriptService.Server.Services.MonetizationService)

	MonetizationService:RegisterProduct(123456, function(player, receipt)
	    return true
	end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

export type Class = Framework.MonetizationServiceClass

local MonetizationService: Class = Framework.CreateMonetizationService({
	Name = "MonetizationService",
})

local baseInit = MonetizationService.Init

function MonetizationService:Init()
	baseInit(self)

	-- Example: grant a consumable for developer product 0 (replace the id).
	self:RegisterProduct(0, function(_player, _receipt)
		return true
	end)
end

return MonetizationService
