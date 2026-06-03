--!strict
--[=[
	@module Monetization
	Framework-native monetization layer over `MarketplaceService`. Wraps
	developer products (consumables), game passes (one-time unlocks), and
	experience subscriptions with a typed, signal-driven API.
	Self-contained: no external Wally dependencies.

	Split into realm singletons, mirroring the `Data` subsystem:
	  * `Monetization.server` - authoritative `ProcessReceipt`, product
	    handlers, ownership cache, server-side prompts.
	  * `Monetization.client` - prompt helpers, cached ownership / product
	    info, purchase-finished signals for UI.

	Server:
	```lua
	local Monetization = require(ReplicatedStorage.Framework).Monetization.server
	Monetization:init()

	Monetization:registerProduct(123456, function(player, receipt)
	    -- grant the consumable; return true once the grant is persisted.
	    addGems(player, 100)
	    return true
	end)

	if Monetization:ownsGamePass(player, 987654) then
	    -- unlock VIP perks
	end
	```

	Client:
	```lua
	local Monetization = require(ReplicatedStorage.Framework).Monetization.client
	Monetization:init()

	Monetization:promptGamePassPurchase(987654)
	Monetization.GamePassPurchaseFinished:connect(function(gamePassId, purchased)
	    if purchased then refreshShop() end
	end)
	```
]=]

local Server = require(script.Server)
local Client = require(script.Client)
local Types = require(script.Types)

export type Server = Types.ServerClass
export type Client = Types.ClientClass
export type ServerClass = Types.ServerClass
export type ClientClass = Types.ClientClass
export type ProductHandler = Types.ProductHandler
export type GamePassHandler = Types.GamePassHandler
export type ReceiptInfo = Types.ReceiptInfo
export type PurchaseRecorder = Types.PurchaseRecorder
export type SubscriptionStatus = Types.SubscriptionStatus
export type SubscriptionStatusHandler = Types.SubscriptionStatusHandler

return {
	server = Server :: Types.ServerClass,
	client = Client :: Types.ClientClass,
}
