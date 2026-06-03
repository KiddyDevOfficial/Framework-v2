--!strict
--[=[
	@module Monetization.Client
	Client-side monetization helper. Triggers purchase prompts, surfaces
	purchase-finished events as signals for UI, and caches game-pass
	ownership / product info to avoid repeated marketplace calls.
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)

if RunService:IsServer() then
	return {} :: Types.ClientClass
end

type ClientClass = Types.ClientClass

local Client = {
	-- (productId, wasPurchased)
	ProductPurchaseFinished = Signal.new(),
	-- (gamePassId, wasPurchased)
	GamePassPurchaseFinished = Signal.new(),
	-- (subscriptionId, didTryPurchasing)
	SubscriptionPurchaseFinished = Signal.new(),

	_gamePassCache = {} :: { [number]: boolean },
	_productInfoCache = {} :: { [string]: any },
	_subscriptionInfoCache = {} :: { [string]: any },
	_initialized = false,
	_connections = {} :: { RBXScriptConnection },
}

local function warnOnce(message: string)
	warn("[Monetization.Client] " .. message)
end

--[=[
	Connects the marketplace prompt-finished callbacks. Safe to call once.
]=]
function Client.init(self: ClientClass)
	if self._initialized then
		return
	end
	self._initialized = true

	local localPlayer = Players.LocalPlayer

	table.insert(
		self._connections,
		MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId: number, productId: number, wasPurchased: boolean)
				if userId ~= localPlayer.UserId then
					return
				end
				self.ProductPurchaseFinished:fire(productId, wasPurchased)
			end
		)
	)

	table.insert(
		self._connections,
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(
			function(player: Player, gamePassId: number, wasPurchased: boolean)
				if player ~= localPlayer then
					return
				end
				if wasPurchased then
					self._gamePassCache[gamePassId] = true
				end
				self.GamePassPurchaseFinished:fire(gamePassId, wasPurchased)
			end
		)
	)

	table.insert(
		self._connections,
		MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(
			function(player: Player, subscriptionId: string, didTryPurchasing: boolean)
				if player ~= localPlayer then
					return
				end
				self.SubscriptionPurchaseFinished:fire(subscriptionId, didTryPurchasing)
			end
		)
	)
end

function Client.promptProductPurchase(self: ClientClass, productId: number)
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
end

function Client.promptGamePassPurchase(self: ClientClass, gamePassId: number)
	MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamePassId)
end

function Client.promptSubscriptionPurchase(self: ClientClass, subscriptionId: string)
	MarketplaceService:PromptSubscriptionPurchase(Players.LocalPlayer, subscriptionId)
end

--[=[
	Cached `UserOwnsGamePassAsync` for the local player.
]=]
function Client.ownsGamePass(self: ClientClass, gamePassId: number): boolean
	local cached = self._gamePassCache[gamePassId]
	if cached ~= nil then
		return cached
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Players.LocalPlayer.UserId, gamePassId)
	end)
	if not ok then
		warnOnce(`UserOwnsGamePassAsync failed for {gamePassId}: {owns}`)
		return false
	end

	self._gamePassCache[gamePassId] = owns
	return owns
end

--[=[
	Cached `GetProductInfo`. `infoType` defaults to `Enum.InfoType.Product`.
]=]
function Client.getProductInfo(self: ClientClass, assetId: number, infoType: Enum.InfoType?): any
	local kind = infoType or Enum.InfoType.Product
	local key = `{kind.Name}:{assetId}`
	local cached = self._productInfoCache[key]
	if cached ~= nil then
		return cached
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, kind)
	end)
	if not ok then
		warnOnce(`GetProductInfo failed for {assetId}: {info}`)
		return nil
	end

	self._productInfoCache[key] = info
	return info
end

--[=[
	Cached `GetSubscriptionProductInfoAsync` (client-only; localized pricing).
	Status checks must run on the server via `Monetization.server:getUserSubscriptionStatus`.
]=]
function Client.getSubscriptionProductInfo(self: ClientClass, subscriptionId: string): any?
	local cached = self._subscriptionInfoCache[subscriptionId]
	if cached ~= nil then
		return cached
	end

	local ok, info = pcall(function()
		return MarketplaceService:GetSubscriptionProductInfoAsync(subscriptionId)
	end)
	if not ok then
		warnOnce(`GetSubscriptionProductInfoAsync failed for '{subscriptionId}': {info}`)
		return nil
	end

	self._subscriptionInfoCache[subscriptionId] = info
	return info
end

return Client :: ClientClass
