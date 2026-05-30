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

-- Optional persistence hooks for receipt de-duplication across servers.
export type PurchaseRecorder = {
	wasProcessed: (player: Player, purchaseId: string) -> boolean,
	record: (player: Player, purchaseId: string) -> (),
}

export type ServerClass = {
	ProductPurchased: Signal.Signal<Player, number>,
	GamePassPurchased: Signal.Signal<Player, number>,
	init: (self: ServerClass) -> (),
	setPurchaseRecorder: (self: ServerClass, recorder: PurchaseRecorder?) -> (),
	registerProduct: (self: ServerClass, productId: number, handler: ProductHandler) -> (),
	unregisterProduct: (self: ServerClass, productId: number) -> (),
	ownsGamePass: (self: ServerClass, player: Player, gamePassId: number) -> boolean,
	promptProductPurchase: (self: ServerClass, player: Player, productId: number) -> (),
	promptGamePassPurchase: (self: ServerClass, player: Player, gamePassId: number) -> (),
}

export type ClientClass = {
	ProductPurchaseFinished: Signal.Signal<number, boolean>,
	GamePassPurchaseFinished: Signal.Signal<number, boolean>,
	init: (self: ClientClass) -> (),
	promptProductPurchase: (self: ClientClass, productId: number) -> (),
	promptGamePassPurchase: (self: ClientClass, gamePassId: number) -> (),
	ownsGamePass: (self: ClientClass, gamePassId: number) -> boolean,
	getProductInfo: (self: ClientClass, assetId: number, infoType: Enum.InfoType?) -> any,
}

return {}
