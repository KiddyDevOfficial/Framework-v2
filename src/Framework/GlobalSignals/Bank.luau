--!strict
--[=[
	@module GlobalSignals.Bank
	Namespace that owns a group of named in-process signals. Calling
	`GlobalSignals.Bank("Round")` is idempotent - the same name always
	returns the same bank instance, and each `Bank:Signal("Name")` returns
	the same signal object.
]=]

local GlobalSignal = require(script.Parent.Signal)

local Bank = {}
Bank.__index = Bank

export type Bank = {
	Name: string,
	_signals: { [string]: any },
	Signal: <T...>(self: Bank, name: string) -> GlobalSignal.GlobalSignal<T...>,
	DestroySignal: (self: Bank, name: string) -> (),
	Destroy: (self: Bank) -> (),
}

local bankCache: { [string]: Bank } = {}

function Bank.new(name: string): Bank
	assert(type(name) == "string" and #name > 0, "[Framework.GlobalSignals] Bank name must be a non-empty string")

	local cached = bankCache[name]
	if cached then
		return cached
	end

	local self = setmetatable({
		Name = name,
		_signals = {},
	}, Bank)
	bankCache[name] = self :: any
	return self :: any
end

function Bank.Signal<T...>(self: Bank, name: string): GlobalSignal.GlobalSignal<T...>
	assert(type(name) == "string" and #name > 0, "[Framework.GlobalSignals] Signal name must be a non-empty string")

	local existing = self._signals[name]
	if existing and not existing:isDestroyed() then
		return existing
	end

	local signal = GlobalSignal.new(self.Name, name)
	self._signals[name] = signal
	return signal :: GlobalSignal.GlobalSignal<T...>
end

function Bank.DestroySignal(self: Bank, name: string)
	local signal = self._signals[name]
	if signal then
		self._signals[name] = nil
		signal:destroy()
	end
end

function Bank.Destroy(self: Bank)
	for name, signal in self._signals do
		self._signals[name] = nil
		signal:destroy()
	end
	bankCache[self.Name] = nil
end

return Bank
