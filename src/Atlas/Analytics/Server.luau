--!strict
--[=[
	@module Analytics.Server
	Thin, crash-proof wrapper over Roblox `AnalyticsService`. Every log call is
	wrapped in `pcall`, so a telemetry hiccup never propagates into gameplay
	code, and each returns whether the underlying call succeeded.

	Flow and progression fields accept a string or the matching `EnumItem`.
	Unknown strings are reported (when `WarnOnError` is set) and the call is
	skipped rather than throwing.
]=]

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

if RunService:IsClient() then
	return {} :: Types.ServerClass
end

type ServerClass = Types.ServerClass
type InitOptions = Types.InitOptions
type EconomyEvent = Types.EconomyEvent
type ProgressionEvent = Types.ProgressionEvent
type FunnelStep = Types.FunnelStep
type OnboardingStep = Types.OnboardingStep
type CustomEvent = Types.CustomEvent

local Server = {
	_initialized = false,
	_warnOnError = true,
}

local function report(self: ServerClass, message: string)
	if (self :: any)._warnOnError then
		warn("[Analytics.Server] " .. message)
	end
end

local function resolveFlowType(value: Types.EconomyFlow): Enum.AnalyticsEconomyFlowType?
	if typeof(value) == "EnumItem" then
		return value :: any
	end
	if type(value) == "string" then
		return Enum.AnalyticsEconomyFlowType:FromName(value)
	end
	return nil
end

local function resolveTransaction(value: Types.TransactionType): string
	if typeof(value) == "EnumItem" then
		return (value :: EnumItem).Name
	end
	return value :: string
end

local function resolveProgression(value: Types.ProgressionStatus): Enum.AnalyticsProgressionType?
	if typeof(value) == "EnumItem" then
		return value :: any
	end
	if type(value) == "string" then
		return Enum.AnalyticsProgressionType:FromName(value)
	end
	return nil
end

function Server.init(self: ServerClass, options: InitOptions?)
	local s: any = self
	local opts: InitOptions = options or {}
	if opts.WarnOnError ~= nil then
		s._warnOnError = opts.WarnOnError
	end
	s._initialized = true
end

function Server.logEconomyEvent(self: ServerClass, player: Player, event: EconomyEvent): boolean
	local flowType = resolveFlowType(event.flowType)
	if not flowType then
		report(self, `logEconomyEvent: unknown flowType "{tostring(event.flowType)}"`)
		return false
	end

	local ok, err = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			event.currencyType,
			event.amount,
			event.endingBalance,
			resolveTransaction(event.transactionType),
			event.itemSku,
			event.customFields
		)
	end)
	if not ok then
		report(self, `logEconomyEvent failed: {err}`)
	end
	return ok
end

function Server.logProgressionEvent(self: ServerClass, player: Player, event: ProgressionEvent): boolean
	local status = resolveProgression(event.status)
	if not status then
		report(self, `logProgressionEvent: unknown status "{tostring(event.status)}"`)
		return false
	end

	local ok, err = pcall(function()
		AnalyticsService:LogProgressionEvent(
			player,
			event.path,
			status,
			event.level or 1,
			event.levelName,
			event.customFields
		)
	end)
	if not ok then
		report(self, `logProgressionEvent failed: {err}`)
	end
	return ok
end

function Server.logFunnelStep(self: ServerClass, player: Player, step: FunnelStep): boolean
	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			step.funnelName,
			step.sessionId,
			step.step,
			step.stepName,
			step.customFields
		)
	end)
	if not ok then
		report(self, `logFunnelStep failed: {err}`)
	end
	return ok
end

function Server.logOnboardingStep(self: ServerClass, player: Player, step: OnboardingStep): boolean
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step.step, step.stepName, step.customFields)
	end)
	if not ok then
		report(self, `logOnboardingStep failed: {err}`)
	end
	return ok
end

function Server.logCustomEvent(self: ServerClass, player: Player, event: CustomEvent): boolean
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, event.name, event.value, event.customFields)
	end)
	if not ok then
		report(self, `logCustomEvent failed: {err}`)
	end
	return ok
end

return Server :: ServerClass
