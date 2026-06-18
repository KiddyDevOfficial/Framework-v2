--!strict
--[=[
	@module Monetization
	Typed `MarketplaceService` helpers for developer products, game passes, and
	experience subscriptions.

	Split by realm, like `Data`:
	  * `Monetization.server` owns receipts, handlers, caches, and server prompts.
	  * `Monetization.client` owns prompt helpers and purchase-finished signals.

	Server:
	```lua
	local Monetization = require(ReplicatedStorage.Weave).Monetization.server
	Monetization:init()

	Monetization:registerProduct(123456, function(player, receipt)
	    addGems(player, 100)
	    return true
	end)

	if Monetization:ownsGamePass(player, 987654) then
	end
	```

	Client:
	```lua
	local Monetization = require(ReplicatedStorage.Weave).Monetization.client
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
