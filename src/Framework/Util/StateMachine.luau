--!strict
--[=[
	@module Util.StateMachine
	Typed finite state machines for server or client code. Use one when an
	entity is always in one state and only certain transitions are legal.

	Each machine carries a typed `data` payload, fires `Changed` on transitions,
	and supports per-state `onEnter` / `onExit` hooks.

	```lua
	local StateMachine = Framework.StateMachine

	type MechanicData = { ticks: number }

	local fsm = StateMachine.new({
	    initial = "Idle",
	    data = { ticks = 0 } :: MechanicData,
	    states = {
	        Idle = { transitions = { "Active" } },
	        Active = {
	            transitions = { "Idle", "Cooldown" },
	            onEnter = function(ctx) ctx.data.ticks += 1 end,
	        },
	        Cooldown = { transitions = { "Idle" } },
	    },
	})

	fsm:transition("Active")
	fsm:force("Cooldown")
	```

	Groups keep one machine per key (`Player`, `Instance`, string id, ...). Pass
	a shared `Config`, or a builder when each key needs its own setup.

	```lua
	local ExampleStates = require(ReplicatedStorage.Shared.StateMachines.ExampleStates)

	local group = StateMachine.group(ExampleStates.config)

	local group = StateMachine.group(ExampleStates.build)

	group:transition(player, "Active")
	Players.PlayerRemoving:Connect(function(p) group:remove(p) end)
	```
]=]

local Signal = require(script.Parent.Parent.Signal)
local TableUtil = require(script.Parent.TableUtil)
type Signal<T...> = Signal.Signal<T...>
type Connection = Signal.Connection

local StateMachine = {}
StateMachine.__index = StateMachine

--[=[
	Passed to state callbacks. `from` is `nil` when the initial state enters.
]=]
export type Context<D> = {
	machine: StateMachine<D>,
	from: string?,
	to: string,
	data: D,
}

export type StateConfig<D> = {
	transitions: { string }?,
	guard: ((ctx: Context<D>) -> boolean)?,
	onEnter: ((ctx: Context<D>) -> ())?,
	onExit: ((ctx: Context<D>) -> ())?,
	onUpdate: ((data: D, dt: number) -> ())?,
}

export type Config<D> = {
	initial: string,
	data: D?,
	states: { [string]: StateConfig<D> },
}

export type StateMachine<D> = {
	Changed: Signal<string, string>,
	get: (self: StateMachine<D>) -> string,
	is: (self: StateMachine<D>, state: string) -> boolean,
	getData: (self: StateMachine<D>) -> D,
	can: (self: StateMachine<D>, to: string) -> boolean,
	transition: (self: StateMachine<D>, to: string) -> boolean,
	force: (self: StateMachine<D>, to: string) -> boolean,
	update: (self: StateMachine<D>, dt: number) -> (),
	onEnter: (self: StateMachine<D>, state: string, callback: (ctx: Context<D>) -> ()) -> Connection,
	onExit: (self: StateMachine<D>, state: string, callback: (ctx: Context<D>) -> ()) -> Connection,
	isDestroyed: (self: StateMachine<D>) -> boolean,
	destroy: (self: StateMachine<D>) -> (),
}

--[=[
	New machine. It enters `initial` immediately and errors if that state is not
	defined.
]=]
function StateMachine.new<D>(config: Config<D>): StateMachine<D>
	assert(type(config) == "table", "[StateMachine] config table required")
	assert(type(config.initial) == "string", "[StateMachine] config.initial must be a state name")
	local states = config.states or {}
	assert(states[config.initial], `[StateMachine] initial state '{config.initial}' is not defined`)

	local self = setmetatable({
		Changed = Signal.new(),
		_states = states,
		_current = config.initial,
		_data = (config.data or {}) :: any,
		_enterSignals = {} :: { [string]: Signal<Context<D>> },
		_exitSignals = {} :: { [string]: Signal<Context<D>> },
		_destroyed = false,
	}, StateMachine)

	local s: any = self
	local cfg = states[config.initial]
	if cfg and cfg.onEnter then
		cfg.onEnter({ machine = self :: any, from = nil, to = config.initial, data = s._data })
	end

	return self :: any
end

function StateMachine.get<D>(self: StateMachine<D>): string
	return (self :: any)._current
end

function StateMachine.is<D>(self: StateMachine<D>, state: string): boolean
	return (self :: any)._current == state
end

function StateMachine.getData<D>(self: StateMachine<D>): D
	return (self :: any)._data
end

--[=[
	Whether `transition(to)` would succeed right now.
]=]
function StateMachine.can<D>(self: StateMachine<D>, to: string): boolean
	local s: any = self
	if s._destroyed then
		return false
	end
	local target = s._states[to]
	if not target then
		return false
	end
	if s._current == to then
		return false
	end

	local currentCfg = s._states[s._current]
	if currentCfg and currentCfg.transitions and not table.find(currentCfg.transitions, to) then
		return false
	end

	if target.guard then
		local ctx: Context<D> = { machine = self, from = s._current, to = to, data = s._data }
		if not target.guard(ctx) then
			return false
		end
	end

	return true
end

function StateMachine._change<D>(self: StateMachine<D>, to: string): boolean
	local s: any = self
	local from: string = s._current
	local fromCfg = s._states[from]
	local toCfg = s._states[to]

	local exitCtx: Context<D> = { machine = self, from = from, to = to, data = s._data }
	if fromCfg and fromCfg.onExit then
		fromCfg.onExit(exitCtx)
	end
	local exitSig = s._exitSignals[from]
	if exitSig then
		exitSig:fire(exitCtx)
	end

	s._current = to

	local enterCtx: Context<D> = { machine = self, from = from, to = to, data = s._data }
	if toCfg and toCfg.onEnter then
		toCfg.onEnter(enterCtx)
	end
	local enterSig = s._enterSignals[to]
	if enterSig then
		enterSig:fire(enterCtx)
	end

	s.Changed:fire(to, from)
	return true
end

function StateMachine.transition<D>(self: StateMachine<D>, to: string): boolean
	if not self:can(to) then
		return false
	end
	return (self :: any):_change(to)
end

--[=[
	Forces a transition, ignoring whitelists and guards. Hooks and `Changed`
	still run.
]=]
function StateMachine.force<D>(self: StateMachine<D>, to: string): boolean
	local s: any = self
	if s._destroyed then
		return false
	end
	if not s._states[to] or s._current == to then
		return false
	end
	return s:_change(to)
end

function StateMachine.update<D>(self: StateMachine<D>, dt: number)
	local s: any = self
	if s._destroyed then
		return
	end
	local cfg = s._states[s._current]
	if cfg and cfg.onUpdate then
		cfg.onUpdate(s._data, dt)
	end
end

local function lazySignal<D>(map: { [string]: Signal<Context<D>> }, state: string): Signal<Context<D>>
	local sig = map[state]
	if not sig then
		sig = Signal.new()
		map[state] = sig
	end
	return sig
end

function StateMachine.onEnter<D>(self: StateMachine<D>, state: string, callback: (ctx: Context<D>) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, "[StateMachine] cannot observe a destroyed machine")
	return lazySignal(s._enterSignals, state):connect(callback)
end

function StateMachine.onExit<D>(self: StateMachine<D>, state: string, callback: (ctx: Context<D>) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, "[StateMachine] cannot observe a destroyed machine")
	return lazySignal(s._exitSignals, state):connect(callback)
end

function StateMachine.isDestroyed<D>(self: StateMachine<D>): boolean
	return (self :: any)._destroyed
end

function StateMachine.destroy<D>(self: StateMachine<D>)
	local s: any = self
	if s._destroyed then
		return
	end
	s._destroyed = true
	s.Changed:destroy()
	for _, sig in s._enterSignals do
		sig:destroy()
	end
	for _, sig in s._exitSignals do
		sig:destroy()
	end
	table.clear(s._enterSignals)
	table.clear(s._exitSignals)
end

----- Groups -----

local Group = {}
Group.__index = Group

export type Group<K, D> = {
	get: (self: Group<K, D>, key: K) -> StateMachine<D>,
	find: (self: Group<K, D>, key: K) -> StateMachine<D>?,
	has: (self: Group<K, D>, key: K) -> boolean,
	state: (self: Group<K, D>, key: K) -> string,
	is: (self: Group<K, D>, key: K, state: string) -> boolean,
	can: (self: Group<K, D>, key: K, to: string) -> boolean,
	getData: (self: Group<K, D>, key: K) -> D,
	transition: (self: Group<K, D>, key: K, to: string) -> boolean,
	force: (self: Group<K, D>, key: K, to: string) -> boolean,
	update: (self: Group<K, D>, dt: number) -> (),
	keys: (self: Group<K, D>) -> { K },
	remove: (self: Group<K, D>, key: K) -> (),
	clear: (self: Group<K, D>) -> (),
	isDestroyed: (self: Group<K, D>) -> boolean,
	destroy: (self: Group<K, D>) -> (),
}

local function configForKey<D>(template: Config<D>, _key: any): Config<D>
	local data = template.data
	if data ~= nil and type(data) == "table" then
		data = TableUtil.deepCopy(data)
	end
	return {
		initial = template.initial,
		states = template.states,
		data = data,
	}
end

--[=[
	A registry of machines keyed by `K`, created on first use.

	A shared `Config` reuses the same state graph and deep-copies table `data`
	per key. A builder can return a fresh config per key.
]=]
function StateMachine.group<K, D>(configOrBuilder: Config<D> | ((key: K) -> Config<D>)): Group<K, D>
	local builder: (key: K) -> Config<D>
	if type(configOrBuilder) == "function" then
		builder = configOrBuilder :: (key: K) -> Config<D>
	else
		local template = configOrBuilder :: Config<D>
		builder = function(key: K)
			return configForKey(template, key)
		end
	end

	return setmetatable({
		_builder = builder,
		_machines = {} :: { [K]: StateMachine<D> },
		_destroyed = false,
	}, Group) :: any
end

function Group.get<K, D>(self: Group<K, D>, key: K): StateMachine<D>
	local s: any = self
	assert(not s._destroyed, "[StateMachine.Group] destroyed group")
	local machine = s._machines[key]
	if not machine then
		machine = StateMachine.new(s._builder(key))
		s._machines[key] = machine
	end
	return machine
end

function Group.find<K, D>(self: Group<K, D>, key: K): StateMachine<D>?
	return (self :: any)._machines[key]
end

function Group.has<K, D>(self: Group<K, D>, key: K): boolean
	return (self :: any)._machines[key] ~= nil
end

function Group.state<K, D>(self: Group<K, D>, key: K): string
	return self:get(key):get()
end

function Group.is<K, D>(self: Group<K, D>, key: K, state: string): boolean
	return self:get(key):is(state)
end

function Group.can<K, D>(self: Group<K, D>, key: K, to: string): boolean
	return self:get(key):can(to)
end

function Group.getData<K, D>(self: Group<K, D>, key: K): D
	return self:get(key):getData()
end

function Group.transition<K, D>(self: Group<K, D>, key: K, to: string): boolean
	return self:get(key):transition(to)
end

function Group.force<K, D>(self: Group<K, D>, key: K, to: string): boolean
	return self:get(key):force(to)
end

function Group.update<K, D>(self: Group<K, D>, dt: number)
	local s: any = self
	if s._destroyed then
		return
	end
	for _, machine in s._machines do
		machine:update(dt)
	end
end

function Group.keys<K, D>(self: Group<K, D>): { K }
	local out = {}
	for key in (self :: any)._machines do
		table.insert(out, key)
	end
	return out
end

function Group.remove<K, D>(self: Group<K, D>, key: K)
	local s: any = self
	local machine = s._machines[key]
	if machine then
		s._machines[key] = nil
		machine:destroy()
	end
end

function Group.clear<K, D>(self: Group<K, D>)
	local s: any = self
	for key, machine in s._machines do
		s._machines[key] = nil
		machine:destroy()
	end
end

function Group.isDestroyed<K, D>(self: Group<K, D>): boolean
	return (self :: any)._destroyed
end

function Group.destroy<K, D>(self: Group<K, D>)
	local s: any = self
	if s._destroyed then
		return
	end
	s._destroyed = true
	self:clear()
end

return StateMachine
