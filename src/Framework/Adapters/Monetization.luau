--!strict
--[=[
	@module Adapters.Monetization
	Framework bindings for the built-in Monetization subsystem. Exposes:

	  * `Monetization.CreateService(options)` - server `Service` that boots
	    `Monetization.server` in `Init` and forwards the API in PascalCase.
	  * `Monetization.CreateController(options)` - client `Controller` that
	    boots `Monetization.client` in `Start`.

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
	SetPurchaseRecorder: (self: ServiceClass, recorder: MonetizationTypes.PurchaseRecorder?) -> (),
	OwnsGamePass: (self: ServiceClass, player: Player, gamePassId: number) -> boolean,
	PromptProductPurchase: (self: ServiceClass, player: Player, productId: number) -> (),
	PromptGamePassPurchase: (self: ServiceClass, player: Player, gamePassId: number) -> (),
	ProductPurchased: Signal.Signal<Player, number>,
	GamePassPurchased: Signal.Signal<Player, number>,
}

export type ControllerClass = {
	Client: (self: ControllerClass) -> MonetizationTypes.ClientClass,
	PromptProductPurchase: (self: ControllerClass, productId: number) -> (),
	PromptGamePassPurchase: (self: ControllerClass, gamePassId: number) -> (),
	OwnsGamePass: (self: ControllerClass, gamePassId: number) -> boolean,
	GetProductInfo: (self: ControllerClass, assetId: number, infoType: Enum.InfoType?) -> any,
	ProductPurchaseFinished: Signal.Signal<number, boolean>,
	GamePassPurchaseFinished: Signal.Signal<number, boolean>,
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

	function def:SetPurchaseRecorder(recorder: MonetizationTypes.PurchaseRecorder?)
		return self._server:setPurchaseRecorder(recorder)
	end

	function def:OwnsGamePass(player: Player, gamePassId: number): boolean
		return self._server:ownsGamePass(player, gamePassId)
	end

	function def:PromptProductPurchase(player: Player, productId: number)
		return self._server:promptProductPurchase(player, productId)
	end

	function def:PromptGamePassPurchase(player: Player, gamePassId: number)
		return self._server:promptGamePassPurchase(player, gamePassId)
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

	function def:OwnsGamePass(gamePassId: number): boolean
		return self._client:ownsGamePass(gamePassId)
	end

	function def:GetProductInfo(assetId: number, infoType: Enum.InfoType?): any
		return self._client:getProductInfo(assetId, infoType)
	end

	return def :: ControllerClass
end

return MonetizationAdapter
