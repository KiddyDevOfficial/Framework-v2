--!strict
--[=[
	@module Monetization.Server
	Authoritative monetization singleton. Owns `MarketplaceService.ProcessReceipt`,
	routes developer-product receipts to registered handlers, caches game-pass
	ownership, and fans out purchase events through signals.

	Method names are camelCase to match the rest of the framework's
	`self._xxx:<method>` call sites.
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)

if RunService:IsClient() then
	return {} :: Types.ServerClass
end

type ServerClass = Types.ServerClass
type ReceiptInfo = Types.ReceiptInfo
type ProductHandler = Types.ProductHandler
type PurchaseRecorder = Types.PurchaseRecorder
type SubscriptionStatus = Types.SubscriptionStatus
type SubscriptionStatusHandler = Types.SubscriptionStatusHandler
type GamePassHandler = Types.GamePassHandler

local Server = {
	-- Fires after a developer product is successfully granted: (player, productId).
	ProductPurchased = Signal.new(),
	-- Fires after a game pass purchase completes successfully: (player, gamePassId).
	GamePassPurchased = Signal.new(),
	-- Fires when a tracked subscription's status changes: (player, subscriptionId, status).
	SubscriptionStatusChanged = Signal.new(),

	_productHandlers = {} :: { [number]: ProductHandler },
	_gamePassHandlers = {} :: { [number]: GamePassHandler },
	_subscriptionHandlers = {} :: { [string]: SubscriptionStatusHandler },
	_gamePassCache = {} :: { [Player]: { [number]: boolean } },
	_recorder = nil :: PurchaseRecorder?,
	_processedThisSession = {} :: { [string]: boolean },
	_initialized = false,
	_connections = {} :: { RBXScriptConnection },
}

local function warnOnce(message: string)
	warn("[Monetization.Server] " .. message)
end

--[=[
	Wires `ProcessReceipt`, game-pass purchase callbacks and player cleanup.
	Safe to call once; subsequent calls are ignored.
]=]
function Server.init(self: ServerClass)
	if self._initialized then
		return
	end
	self._initialized = true

	MarketplaceService.ProcessReceipt = function(receipt: ReceiptInfo)
		return self:_processReceipt(receipt)
	end

	table.insert(
		self._connections,
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(
			function(player: Player, gamePassId: number, wasPurchased: boolean)
				if not wasPurchased then
					return
				end
				local cache = self._gamePassCache[player]
				if cache then
					cache[gamePassId] = true
				end
				self.GamePassPurchased:fire(player, gamePassId)
				self:_invokeGamePassHandler(player, gamePassId)
			end
		)
	)

	table.insert(
		self._connections,
		Players.PlayerAdded:Connect(function(player: Player)
			self:grantRegisteredGamePassesForPlayer(player)
		end)
	)

	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			self._gamePassCache[player] = nil
		end)
	)

	table.insert(
		self._connections,
		Players.UserSubscriptionStatusChanged:Connect(function(player: Player, subscriptionId: string)
			self:_onUserSubscriptionStatusChanged(player, subscriptionId)
		end)
	)
end

function Server.registerSubscription(
	self: ServerClass,
	subscriptionId: string,
	handler: SubscriptionStatusHandler
)
	assert(type(subscriptionId) == "string", "[Monetization.Server] subscriptionId must be a string")
	assert(#subscriptionId > 0, "[Monetization.Server] subscriptionId must be non-empty")
	assert(type(handler) == "function", "[Monetization.Server] handler must be a function")
	self._subscriptionHandlers[subscriptionId] = handler
end

function Server.unregisterSubscription(self: ServerClass, subscriptionId: string)
	self._subscriptionHandlers[subscriptionId] = nil
end

function Server._onUserSubscriptionStatusChanged(self: any, player: Player, subscriptionId: string)
	local status = self:getUserSubscriptionStatus(player, subscriptionId)
	if not status then
		return
	end

	self.SubscriptionStatusChanged:fire(player, subscriptionId, status)

	local handler = self._subscriptionHandlers[subscriptionId]
	if not handler then
		return
	end

	local ok, err = pcall(handler, player, subscriptionId, status)
	if not ok then
		warnOnce(`subscription handler for '{subscriptionId}' errored: {err}`)
	end
end

function Server.getUserSubscriptionStatus(
	self: ServerClass,
	player: Player,
	subscriptionId: string
): SubscriptionStatus?
	local ok, result = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
	end)
	if not ok then
		warnOnce(`GetUserSubscriptionStatusAsync failed for '{subscriptionId}': {result}`)
		return nil
	end
	return {
		IsSubscribed = result.IsSubscribed == true,
		IsRenewing = result.IsRenewing == true,
	}
end

function Server.getUserSubscriptionDetails(self: ServerClass, player: Player, subscriptionId: string): any?
	local ok, result = pcall(function()
		return MarketplaceService:GetUserSubscriptionDetailsAsync(player, subscriptionId)
	end)
	if not ok then
		warnOnce(`GetUserSubscriptionDetailsAsync failed for '{subscriptionId}': {result}`)
		return nil
	end
	return result
end

function Server.getUserSubscriptionPaymentHistory(
	self: ServerClass,
	player: Player,
	subscriptionId: string
): { any }?
	local ok, result = pcall(function()
		return MarketplaceService:GetUserSubscriptionPaymentHistoryAsync(player, subscriptionId)
	end)
	if not ok then
		warnOnce(`GetUserSubscriptionPaymentHistoryAsync failed for '{subscriptionId}': {result}`)
		return nil
	end
	return result
end

--[=[
	Provides cross-server receipt de-duplication. Without a recorder, the
	server only remembers purchases processed in the current session.
]=]
function Server.setPurchaseRecorder(self: ServerClass, recorder: PurchaseRecorder?)
	self._recorder = recorder
end

--[=[
	Registers a handler for a developer product. The handler must return
	`true` only once the grant is safely persisted.
]=]
function Server.registerProduct(self: ServerClass, productId: number, handler: ProductHandler)
	assert(type(productId) == "number", "[Monetization.Server] productId must be a number")
	assert(type(handler) == "function", "[Monetization.Server] handler must be a function")
	self._productHandlers[productId] = handler
end

function Server.unregisterProduct(self: ServerClass, productId: number)
	self._productHandlers[productId] = nil
end

function Server.registerGamePass(self: ServerClass, gamePassId: number, handler: GamePassHandler)
	assert(type(gamePassId) == "number", "[Monetization.Server] gamePassId must be a number")
	assert(type(handler) == "function", "[Monetization.Server] handler must be a function")
	self._gamePassHandlers[gamePassId] = handler
end

function Server.unregisterGamePass(self: ServerClass, gamePassId: number)
	self._gamePassHandlers[gamePassId] = nil
end

function Server._invokeGamePassHandler(self: any, player: Player, gamePassId: number)
	local handler = self._gamePassHandlers[gamePassId]
	if not handler then
		return
	end

	local ok, err = pcall(handler, player)
	if not ok then
		warnOnce(`game pass handler for {gamePassId} errored: {err}`)
	end
end

--[=[
	Runs handlers for every registered game pass the player already owns.
	Also runs automatically on `Players.PlayerAdded`.
]=]
function Server.grantRegisteredGamePassesForPlayer(self: ServerClass, player: Player)
	for gamePassId in self._gamePassHandlers do
		if self:ownsGamePass(player, gamePassId) then
			self:_invokeGamePassHandler(player, gamePassId)
		end
	end
end

local function markProcessed(self: any, player: Player?, purchaseId: string)
	if self._recorder and player then
		self._recorder.record(player, purchaseId)
	end
	self._processedThisSession[purchaseId] = true
end

local function alreadyProcessed(self: any, player: Player?, purchaseId: string): boolean
	if self._processedThisSession[purchaseId] then
		return true
	end
	if self._recorder and player then
		return self._recorder.wasProcessed(player, purchaseId)
	end
	return false
end

function Server._processReceipt(self: any, receipt: ReceiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		-- Player left mid-purchase; let Roblox retry when they return.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if alreadyProcessed(self, player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local handler = self._productHandlers[receipt.ProductId]
	if not handler then
		warnOnce(`no handler registered for product {receipt.ProductId}; deferring receipt`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(handler, player, receipt)
	if not ok then
		warnOnce(`handler for product {receipt.ProductId} errored: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	markProcessed(self, player, receipt.PurchaseId)
	self.ProductPurchased:fire(player, receipt.ProductId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[=[
	Returns whether `player` owns `gamePassId`, caching the (network) result
	for the lifetime of their session.
]=]
function Server.ownsGamePass(self: ServerClass, player: Player, gamePassId: number): boolean
	local cache = self._gamePassCache[player]
	if not cache then
		cache = {}
		self._gamePassCache[player] = cache
	end
	local cached = cache[gamePassId]
	if cached ~= nil then
		return cached
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)
	if not ok then
		warnOnce(`UserOwnsGamePassAsync failed for {gamePassId}: {owns}`)
		return false
	end

	cache[gamePassId] = owns
	return owns
end

function Server.promptProductPurchase(self: ServerClass, player: Player, productId: number)
	MarketplaceService:PromptProductPurchase(player, productId)
end

function Server.promptGamePassPurchase(self: ServerClass, player: Player, gamePassId: number)
	MarketplaceService:PromptGamePassPurchase(player, gamePassId)
end

function Server.promptSubscriptionPurchase(self: ServerClass, player: Player, subscriptionId: string)
	MarketplaceService:PromptSubscriptionPurchase(player, subscriptionId)
end

function Server.promptCancelSubscription(self: ServerClass, player: Player, subscriptionId: string)
	MarketplaceService:PromptCancelSubscription(player, subscriptionId)
end

return Server :: ServerClass
