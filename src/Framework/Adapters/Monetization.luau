--!strict
--[=[
	@module Adapters.Monetization
	Framework bindings for the built-in Monetization subsystem. Exposes:

	  * `Monetization.CreateService(options)` - server `Service` that boots
	    `Monetization.server` in `Init` and forwards the API in PascalCase.
	  * `Monetization.CreateController(options)` - client `Controller` that
	    boots `Monetization.client` in `Start`.

	Subscriptions follow the Roblox API:
	https://create.roblox.com/docs/production/monetization/subscriptions

	```lua
	return Framework.CreateMonetizationService({ Name = "MonetizationService" })
	```

	```lua
	return Framework.CreateMonetizationController({ Name = "MonetizationController" })
	```
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local Controller = require(script.Parent.Parent.Modular.Controller)
local Signal = require(script.Parent.Parent.Signal)
local MonetizationPackage = require(script.Parent.Parent.Monetization)
local MonetizationTypes = require(script.Parent.Parent.Monetization.Types)

local MonetizationAdapter = {}

export type ServerOptions = {
	Name: string?,
	Dependencies: { string }?,
}

export type ClientOptions = {
	Name: string?,
	Dependencies: { string }?,
}

export type ServiceClass = {
	Server: (self: ServiceClass) -> MonetizationTypes.ServerClass,
	RegisterProduct: (self: ServiceClass, productId: number, handler: MonetizationTypes.ProductHandler) -> (),
	UnregisterProduct: (self: ServiceClass, productId: number) -> (),
	RegisterGamePass: (self: ServiceClass, gamePassId: number, handler: MonetizationTypes.GamePassHandler) -> (),
	UnregisterGamePass: (self: ServiceClass, gamePassId: number) -> (),
	GrantRegisteredGamePassesForPlayer: (self: ServiceClass, player: Player) -> (),
	SetPurchaseRecorder: (self: ServiceClass, recorder: MonetizationTypes.PurchaseRecorder?) -> (),
	RegisterSubscription: (
		self: ServiceClass,
		subscriptionId: string,
		handler: MonetizationTypes.SubscriptionStatusHandler
	) -> (),
	UnregisterSubscription: (self: ServiceClass, subscriptionId: string) -> (),
	OwnsGamePass: (self: ServiceClass, player: Player, gamePassId: number) -> boolean,
	GetUserSubscriptionStatus: (
		self: ServiceClass,
		player: Player,
		subscriptionId: string
	) -> MonetizationTypes.SubscriptionStatus?,
	GetUserSubscriptionDetails: (self: ServiceClass, player: Player, subscriptionId: string) -> any?,
	GetUserSubscriptionPaymentHistory: (self: ServiceClass, player: Player, subscriptionId: string) -> { any }?,
	PromptProductPurchase: (self: ServiceClass, player: Player, productId: number) -> (),
	PromptGamePassPurchase: (self: ServiceClass, player: Player, gamePassId: number) -> (),
	PromptSubscriptionPurchase: (self: ServiceClass, player: Player, subscriptionId: string) -> (),
	PromptCancelSubscription: (self: ServiceClass, player: Player, subscriptionId: string) -> (),
	ProductPurchased: Signal.Signal<Player, number>,
	GamePassPurchased: Signal.Signal<Player, number>,
	SubscriptionStatusChanged: Signal.Signal<Player, string, MonetizationTypes.SubscriptionStatus>,
}

export type ControllerClass = {
	Client: (self: ControllerClass) -> MonetizationTypes.ClientClass,
	PromptProductPurchase: (self: ControllerClass, productId: number) -> (),
	PromptGamePassPurchase: (self: ControllerClass, gamePassId: number) -> (),
	PromptSubscriptionPurchase: (self: ControllerClass, subscriptionId: string) -> (),
	OwnsGamePass: (self: ControllerClass, gamePassId: number) -> boolean,
	GetProductInfo: (self: ControllerClass, assetId: number, infoType: Enum.InfoType?) -> any,
	GetSubscriptionProductInfo: (self: ControllerClass, subscriptionId: string) -> any?,
	ProductPurchaseFinished: Signal.Signal<number, boolean>,
	GamePassPurchaseFinished: Signal.Signal<number, boolean>,
	SubscriptionPurchaseFinished: Signal.Signal<string, boolean>,
}

function MonetizationAdapter.CreateService(options: ServerOptions?): ServiceClass
	local opts: ServerOptions = options or {}
	local name = opts.Name or "MonetizationService"

	local def: any = Service.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	})

	function def:Init()
		if not RunService:IsServer() then
			return
		end

		local server = MonetizationPackage.server
		server:init()
		self._server = server
		self.ProductPurchased = server.ProductPurchased
		self.GamePassPurchased = server.GamePassPurchased
		self.SubscriptionStatusChanged = server.SubscriptionStatusChanged
	end

	function def:Server(): MonetizationTypes.ServerClass
		return self._server
	end

	function def:RegisterProduct(productId: number, handler: MonetizationTypes.ProductHandler)
		return self._server:registerProduct(productId, handler)
	end

	function def:UnregisterProduct(productId: number)
		return self._server:unregisterProduct(productId)
	end

	function def:RegisterGamePass(gamePassId: number, handler: MonetizationTypes.GamePassHandler)
		return self._server:registerGamePass(gamePassId, handler)
	end

	function def:UnregisterGamePass(gamePassId: number)
		return self._server:unregisterGamePass(gamePassId)
	end

	function def:GrantRegisteredGamePassesForPlayer(player: Player)
		return self._server:grantRegisteredGamePassesForPlayer(player)
	end

	function def:SetPurchaseRecorder(recorder: MonetizationTypes.PurchaseRecorder?)
		return self._server:setPurchaseRecorder(recorder)
	end

	function def:RegisterSubscription(
		subscriptionId: string,
		handler: MonetizationTypes.SubscriptionStatusHandler
	)
		return self._server:registerSubscription(subscriptionId, handler)
	end

	function def:UnregisterSubscription(subscriptionId: string)
		return self._server:unregisterSubscription(subscriptionId)
	end

	function def:OwnsGamePass(player: Player, gamePassId: number): boolean
		return self._server:ownsGamePass(player, gamePassId)
	end

	function def:GetUserSubscriptionStatus(player: Player, subscriptionId: string): MonetizationTypes.SubscriptionStatus?
		return self._server:getUserSubscriptionStatus(player, subscriptionId)
	end

	function def:GetUserSubscriptionDetails(player: Player, subscriptionId: string): any?
		return self._server:getUserSubscriptionDetails(player, subscriptionId)
	end

	function def:GetUserSubscriptionPaymentHistory(player: Player, subscriptionId: string): { any }?
		return self._server:getUserSubscriptionPaymentHistory(player, subscriptionId)
	end

	function def:PromptProductPurchase(player: Player, productId: number)
		return self._server:promptProductPurchase(player, productId)
	end

	function def:PromptGamePassPurchase(player: Player, gamePassId: number)
		return self._server:promptGamePassPurchase(player, gamePassId)
	end

	function def:PromptSubscriptionPurchase(player: Player, subscriptionId: string)
		return self._server:promptSubscriptionPurchase(player, subscriptionId)
	end

	function def:PromptCancelSubscription(player: Player, subscriptionId: string)
		return self._server:promptCancelSubscription(player, subscriptionId)
	end

	return def :: ServiceClass
end

function MonetizationAdapter.CreateController(options: ClientOptions?): ControllerClass
	local opts: ClientOptions = options or {}
	local name = opts.Name or "MonetizationController"

	local def: any = Controller.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	})

	function def:Init()
		if not RunService:IsClient() then
			return
		end
		self._client = MonetizationPackage.client
	end

	function def:Start()
		if not RunService:IsClient() then
			return
		end
		self._client:init()
		self.ProductPurchaseFinished = self._client.ProductPurchaseFinished
		self.GamePassPurchaseFinished = self._client.GamePassPurchaseFinished
		self.SubscriptionPurchaseFinished = self._client.SubscriptionPurchaseFinished
	end

	function def:Client(): MonetizationTypes.ClientClass
		return self._client
	end

	function def:PromptProductPurchase(productId: number)
		return self._client:promptProductPurchase(productId)
	end

	function def:PromptGamePassPurchase(gamePassId: number)
		return self._client:promptGamePassPurchase(gamePassId)
	end

	function def:PromptSubscriptionPurchase(subscriptionId: string)
		return self._client:promptSubscriptionPurchase(subscriptionId)
	end

	function def:OwnsGamePass(gamePassId: number): boolean
		return self._client:ownsGamePass(gamePassId)
	end

	function def:GetProductInfo(assetId: number, infoType: Enum.InfoType?): any
		return self._client:getProductInfo(assetId, infoType)
	end

	function def:GetSubscriptionProductInfo(subscriptionId: string): any?
		return self._client:getSubscriptionProductInfo(subscriptionId)
	end

	return def :: ControllerClass
end

return MonetizationAdapter
