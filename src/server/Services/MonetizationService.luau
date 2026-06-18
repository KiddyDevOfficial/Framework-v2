--!nocheck
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
	MonetizationService:RegisterGamePass(987654, function(player) end)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local Lists = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lists")
local Products = require(Lists.Products)
local GamePasses = require(Lists.GamePasses)
local Players = game:GetService("Players")

export type Class = Weave.MonetizationServiceClass

local MonetizationService: Class = Weave.CreateMonetizationService({
	Name = "MonetizationService",
})

local baseInit = MonetizationService.Init

function MonetizationService:Init()
	baseInit(self)
	for _, product in Products.GetAllProducts() do
		self:RegisterProduct(product.id, product.handler)
	end

	for _, gamePass in GamePasses.GetAllGamePasses() do
		self:RegisterGamePass(gamePass.id, gamePass.handler)
	end

	for _, player in Players:GetPlayers() do
		self:GrantRegisteredGamePassesForPlayer(player)
	end
end

return MonetizationService
