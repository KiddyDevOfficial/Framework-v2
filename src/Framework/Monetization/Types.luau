--!strict
--[=[
	@module Monetization.Types
	Shared types for the monetization subsystem.
]=]

local Signal = require(script.Parent.Parent.Signal)

-- Shape of the `receiptInfo` table passed to `MarketplaceService.ProcessReceipt`.
export type ReceiptInfo = {
	PurchaseId: string,
	PlayerId: number,
	ProductId: number,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
}

-- Returns `true` once the product has been granted AND that grant is safely
-- persisted; only then is the receipt acknowledged as `PurchaseGranted`.
export type ProductHandler = (player: Player, receipt: ReceiptInfo) -> boolean

-- Called when a player buys a registered game pass or already owns one on join.
export type GamePassHandler = (player: Player) -> ()

-- Optional persistence hooks for receipt de-duplication across servers.
export type PurchaseRecorder = {
	wasProcessed: (player: Player, purchaseId: string) -> boolean,
	record: (player: Player, purchaseId: string) -> (),
}

-- Result of `MarketplaceService:GetUserSubscriptionStatusAsync`.
-- See https://create.roblox.com/docs/production/monetization/subscriptions
export type SubscriptionStatus = {
	IsSubscribed: boolean,
	IsRenewing: boolean,
}

-- Called on the server when `Players.UserSubscriptionStatusChanged` fires for a
-- registered subscription id (after status is re-fetched).
export type SubscriptionStatusHandler = (
	player: Player,
	subscriptionId: string,
	status: SubscriptionStatus
) -> ()

export type ServerClass = {
	ProductPurchased: Signal.Signal<Player, number>,
	GamePassPurchased: Signal.Signal<Player, number>,
	SubscriptionStatusChanged: Signal.Signal<Player, string, SubscriptionStatus>,
	init: (self: ServerClass) -> (),
	setPurchaseRecorder: (self: ServerClass, recorder: PurchaseRecorder?) -> (),
	registerProduct: (self: ServerClass, productId: number, handler: ProductHandler) -> (),
	unregisterProduct: (self: ServerClass, productId: number) -> (),
	registerGamePass: (self: ServerClass, gamePassId: number, handler: GamePassHandler) -> (),
	unregisterGamePass: (self: ServerClass, gamePassId: number) -> (),
	grantRegisteredGamePassesForPlayer: (self: ServerClass, player: Player) -> (),
	registerSubscription: (self: ServerClass, subscriptionId: string, handler: SubscriptionStatusHandler) -> (),
	unregisterSubscription: (self: ServerClass, subscriptionId: string) -> (),
	ownsGamePass: (self: ServerClass, player: Player, gamePassId: number) -> boolean,
	getUserSubscriptionStatus: (self: ServerClass, player: Player, subscriptionId: string) -> SubscriptionStatus?,
	getUserSubscriptionDetails: (self: ServerClass, player: Player, subscriptionId: string) -> any?,
	getUserSubscriptionPaymentHistory: (self: ServerClass, player: Player, subscriptionId: string) -> { any }?,
	promptProductPurchase: (self: ServerClass, player: Player, productId: number) -> (),
	promptGamePassPurchase: (self: ServerClass, player: Player, gamePassId: number) -> (),
	promptSubscriptionPurchase: (self: ServerClass, player: Player, subscriptionId: string) -> (),
	promptCancelSubscription: (self: ServerClass, player: Player, subscriptionId: string) -> (),
}

export type ClientClass = {
	ProductPurchaseFinished: Signal.Signal<number, boolean>,
	GamePassPurchaseFinished: Signal.Signal<number, boolean>,
	SubscriptionPurchaseFinished: Signal.Signal<string, boolean>,
	init: (self: ClientClass) -> (),
	promptProductPurchase: (self: ClientClass, productId: number) -> (),
	promptGamePassPurchase: (self: ClientClass, gamePassId: number) -> (),
	promptSubscriptionPurchase: (self: ClientClass, subscriptionId: string) -> (),
	ownsGamePass: (self: ClientClass, gamePassId: number) -> boolean,
	getProductInfo: (self: ClientClass, assetId: number, infoType: Enum.InfoType?) -> any,
	getSubscriptionProductInfo: (self: ClientClass, subscriptionId: string) -> any?,
}

return {}
