--!strict
--[=[
	@module Adapters.Analytics
	Atlas service binding for the AnalyticsService wrapper. Boots the server
	package in `Init` and re-exposes the logging API in PascalCase.

	```lua
	return Atlas.CreateAnalyticsService({ Name = "AnalyticsService" })
	```

	```lua
	local Analytics = require(ServerScriptService.Server.Services.AnalyticsService)
	Analytics:LogEconomyEvent(player, {
	    flowType = "Source",
	    currencyType = "Coins",
	    amount = 50,
	    endingBalance = 450,
	    transactionType = "Gameplay",
	})
	```
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local AnalyticsPackage = require(script.Parent.Parent.Analytics)
local AnalyticsTypes = require(script.Parent.Parent.Analytics.Types)

local AnalyticsAdapter = {}

export type ServerOptions = {
	Name: string?,
	Dependencies: { string }?,
	WarnOnError: boolean?,
}

export type ServiceClass = {
	Server: (self: ServiceClass) -> AnalyticsTypes.ServerClass,
	LogEconomyEvent: (self: ServiceClass, player: Player, event: AnalyticsTypes.EconomyEvent) -> boolean,
	LogProgressionEvent: (self: ServiceClass, player: Player, event: AnalyticsTypes.ProgressionEvent) -> boolean,
	LogFunnelStep: (self: ServiceClass, player: Player, step: AnalyticsTypes.FunnelStep) -> boolean,
	LogOnboardingStep: (self: ServiceClass, player: Player, step: AnalyticsTypes.OnboardingStep) -> boolean,
	LogCustomEvent: (self: ServiceClass, player: Player, event: AnalyticsTypes.CustomEvent) -> boolean,
}

function AnalyticsAdapter.CreateService(options: ServerOptions?): ServiceClass
	local opts: ServerOptions = options or {}
	local name = opts.Name or "AnalyticsService"

	local def: any = Service.Create({
		Name = name,
		Dependencies = opts.Dependencies or {},
	})

	function def:Init()
		if not RunService:IsServer() then
			return
		end

		local server = AnalyticsPackage.server
		server:init({ WarnOnError = opts.WarnOnError })
		self._server = server
	end

	function def:Server(): AnalyticsTypes.ServerClass
		return self._server
	end

	function def:LogEconomyEvent(player: Player, event: AnalyticsTypes.EconomyEvent): boolean
		return self._server:logEconomyEvent(player, event)
	end

	function def:LogProgressionEvent(player: Player, event: AnalyticsTypes.ProgressionEvent): boolean
		return self._server:logProgressionEvent(player, event)
	end

	function def:LogFunnelStep(player: Player, step: AnalyticsTypes.FunnelStep): boolean
		return self._server:logFunnelStep(player, step)
	end

	function def:LogOnboardingStep(player: Player, step: AnalyticsTypes.OnboardingStep): boolean
		return self._server:logOnboardingStep(player, step)
	end

	function def:LogCustomEvent(player: Player, event: AnalyticsTypes.CustomEvent): boolean
		return self._server:logCustomEvent(player, event)
	end

	return def :: ServiceClass
end

return AnalyticsAdapter
