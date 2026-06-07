--!strict
--[=[
	@module GlobalSignals.Signal
	Named in-process signal used by `GlobalSignals.Bank`. This is not a
	RemoteEvent and not cross-server MessagingService; it is a shared Lua
	event bus for scripts running in the same server/client VM.
]=]

local Signal = require(script.Parent.Parent.Signal)
type Signal<T...> = Signal.Signal<T...>
type Connection = Signal.Connection

local GlobalSignal = {}
GlobalSignal.__index = GlobalSignal

export type GlobalSignal<T...> = {
	Name: string,
	BankName: string,
	connect: (self: GlobalSignal<T...>, handler: (T...) -> ()) -> Connection,
	Connect: (self: GlobalSignal<T...>, handler: (T...) -> ()) -> Connection,
	once: (self: GlobalSignal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: GlobalSignal<T...>, handler: (T...) -> ()) -> Connection,
	fire: (self: GlobalSignal<T...>, T...) -> (),
	Fire: (self: GlobalSignal<T...>, T...) -> (),
	wait: (self: GlobalSignal<T...>) -> ...any,
	Wait: (self: GlobalSignal<T...>) -> ...any,
	handlerCount: (self: GlobalSignal<T...>) -> number,
	HandlerCount: (self: GlobalSignal<T...>) -> number,
	destroy: (self: GlobalSignal<T...>) -> (),
	Destroy: (self: GlobalSignal<T...>) -> (),
	isDestroyed: (self: GlobalSignal<T...>) -> boolean,
}

function GlobalSignal.new<T...>(bankName: string, name: string): GlobalSignal<T...>
	assert(type(bankName) == "string" and #bankName > 0, "[Framework.GlobalSignals] Bank name must be non-empty")
	assert(type(name) == "string" and #name > 0, "[Framework.GlobalSignals] Signal name must be non-empty")

	return setmetatable({
		Name = name,
		BankName = bankName,
		_signal = Signal.new(),
		_destroyed = false,
	}, GlobalSignal) :: any
end

function GlobalSignal.connect<T...>(self: GlobalSignal<T...>, handler: (T...) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, `[Framework.GlobalSignals] {s.BankName}.{s.Name} is destroyed`)
	return (s._signal :: Signal<T...>):connect(handler)
end

GlobalSignal.Connect = GlobalSignal.connect

function GlobalSignal.once<T...>(self: GlobalSignal<T...>, handler: (T...) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, `[Framework.GlobalSignals] {s.BankName}.{s.Name} is destroyed`)
	return (s._signal :: Signal<T...>):once(handler)
end

GlobalSignal.Once = GlobalSignal.once

function GlobalSignal.fire<T...>(self: GlobalSignal<T...>, ...: T...)
	local s: any = self
	if s._destroyed then
		return
	end
	(s._signal :: Signal<T...>):fire(...)
end

GlobalSignal.Fire = GlobalSignal.fire

function GlobalSignal.wait<T...>(self: GlobalSignal<T...>): ...any
	local s: any = self
	assert(not s._destroyed, `[Framework.GlobalSignals] {s.BankName}.{s.Name} is destroyed`)
	return (s._signal :: Signal<T...>):wait()
end

GlobalSignal.Wait = GlobalSignal.wait

function GlobalSignal.handlerCount<T...>(self: GlobalSignal<T...>): number
	return ((self :: any)._signal :: Signal<T...>):handlerCount()
end

GlobalSignal.HandlerCount = GlobalSignal.handlerCount

function GlobalSignal.isDestroyed<T...>(self: GlobalSignal<T...>): boolean
	return (self :: any)._destroyed
end

function GlobalSignal.destroy<T...>(self: GlobalSignal<T...>)
	local s: any = self
	if s._destroyed then
		return
	end
	s._destroyed = true
	s._signal:destroy()
end

GlobalSignal.Destroy = GlobalSignal.destroy

return GlobalSignal
