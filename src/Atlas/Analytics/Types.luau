--!strict
--[=[
	@module Analytics.Types
	Shared types for the `AnalyticsService` wrapper. Flow and progression
	fields accept either a plain string or the matching `EnumItem`, so callers
	can write `flowType = "Sink"` or `flowType = Enum.AnalyticsEconomyFlowType.Sink`.
]=]

export type EconomyFlow = "Source" | "Sink" | Enum.AnalyticsEconomyFlowType
export type TransactionType = string | Enum.AnalyticsEconomyTransactionType
export type ProgressionStatus = "Start" | "Complete" | "Fail" | "Custom" | Enum.AnalyticsProgressionType
export type CustomFields = { [string]: any }

export type EconomyEvent = {
	flowType: EconomyFlow,
	currencyType: string,
	amount: number,
	endingBalance: number,
	transactionType: TransactionType,
	itemSku: string?,
	customFields: CustomFields?,
}

export type ProgressionEvent = {
	path: string,
	status: ProgressionStatus,
	level: number?,
	levelName: string?,
	customFields: CustomFields?,
}

export type FunnelStep = {
	funnelName: string,
	sessionId: string?,
	step: number?,
	stepName: string?,
	customFields: CustomFields?,
}

export type OnboardingStep = {
	step: number,
	stepName: string?,
	customFields: CustomFields?,
}

export type CustomEvent = {
	name: string,
	value: number?,
	customFields: CustomFields?,
}

export type InitOptions = {
	WarnOnError: boolean?,
}

export type ServerClass = {
	init: (self: ServerClass, options: InitOptions?) -> (),
	logEconomyEvent: (self: ServerClass, player: Player, event: EconomyEvent) -> boolean,
	logProgressionEvent: (self: ServerClass, player: Player, event: ProgressionEvent) -> boolean,
	logFunnelStep: (self: ServerClass, player: Player, step: FunnelStep) -> boolean,
	logOnboardingStep: (self: ServerClass, player: Player, step: OnboardingStep) -> boolean,
	logCustomEvent: (self: ServerClass, player: Player, event: CustomEvent) -> boolean,
}

return {}
