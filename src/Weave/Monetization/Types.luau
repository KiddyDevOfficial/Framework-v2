--!strict
--[=[
	@module Monetization.Types
	Shared types for the monetization subsystem.
]=]

local Signal = require(script.Parent.Parent.Signal)

export type ReceiptInfo = {
	PurchaseId: string,
	PlayerId: number,
	ProductId: number,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
}

-- Return `true` only after the grant is saved.
export type ProductHandler = (player: Player, receipt: ReceiptInfo) -> boolean

export type GamePassHandler = (player: Player) -> ()

-- Optional cross-server receipt de-dupe.
export type PurchaseRecorder = {
	wasProcessed: (player: Player, purchaseId: string) -> boolean,
	record: (player: Player, purchaseId: string) -> (),
}

export type SubscriptionStatus = {
	IsSubscribed: boolean,
	IsRenewing: boolean,
}

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
