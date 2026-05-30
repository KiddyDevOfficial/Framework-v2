--!strict
--[=[
	@module Monetization.Types
	Shared types for the monetization subsystem.
]=]

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
-- Without these, the server tracks processed purchases in-memory only
-- (sufficient within a single session, but not across rejoins).
export type PurchaseRecorder = {
	wasProcessed: (player: Player, purchaseId: string) -> boolean,
	record: (player: Player, purchaseId: string) -> (),
}

return {}
