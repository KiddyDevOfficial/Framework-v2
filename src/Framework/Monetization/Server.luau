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

local Server = {
	-- Fires after a developer product is successfully granted: (player, productId).
	ProductPurchased = Signal.new(),
	-- Fires after a game pass purchase completes successfully: (player, gamePassId).
	GamePassPurchased = Signal.new(),

	_productHandlers = {} :: { [number]: ProductHandler },
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
			end
		)
	)

	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			self._gamePassCache[player] = nil
		end)
	)
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

return Server :: ServerClass
