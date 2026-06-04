--!strict
--[=[
	@module Util.StateMachine
	A shared, type-first finite state machine. Works identically on the
	server and client for any gameplay loop where an entity is always in
	exactly one state and only certain transitions are legal.

	Each machine carries a typed `data` payload that every callback can read
	and mutate, fires a `Changed` signal on every transition, and exposes
	per-state `onEnter` / `onExit` hooks. Drop a machine into a `Trove` for
	automatic cleanup.

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
	fsm:force("Cooldown")  -- bypass whitelist + guard when needed
	```

	**Groups** — one machine per key (`Player`, `Instance`, string id, …).
	Pass a shared `Config` (each key gets a deep-copied `data` table) or a
	builder when you need per-key setup:

	```lua
	local ExampleStates = require(ReplicatedStorage.Shared.StateMachines.ExampleStates)

	-- same definition for every key
	local group = StateMachine.group(ExampleStates.config)

	-- or customize per key
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
	Passed to every state callback. `from` is `nil` for the initial state's
	entry. `data` is the machine's shared, mutable payload.
]=]
export type Context<D> = {
	machine: StateMachine<D>,
	from: string?,
	to: string,
	data: D,
}

--[=[
	Configuration for a single state.

	* `transitions` - whitelist of state names this state may move to via
	  `transition`. `nil` means "any state is allowed". `force` ignores this.
	* `guard` - runs before entering this state; return `false` to veto.
	* `onEnter` / `onExit` - lifecycle callbacks.
	* `onUpdate` - run by `machine:update(dt)` while this is the current state.
]=]
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
	-- Fired after every transition: `(newState, oldState)`.
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
	Creates a machine and enters the `initial` state (its `onEnter` runs with
	`from = nil`). Errors if `initial` is not present in `states`.
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
	Returns whether `transition(to)` would currently succeed: target exists,
	differs from the current state, is allowed by the source whitelist, and
	passes the target's `guard`.
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

--[=[
	Attempts a legal transition. Returns `false` (without side effects) when
	`can(to)` is false.
]=]
function StateMachine.transition<D>(self: StateMachine<D>, to: string): boolean
	if not self:can(to) then
		return false
	end
	return (self :: any):_change(to)
end

--[=[
	Forces a transition, ignoring the source `transitions` whitelist and the
	target `guard`. Still runs `onExit` / `onEnter` and fires `Changed`. Use
	for "from anywhere" effects (interrupts, resets, global events).
	Returns `false` only if the target is unknown or already current.
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

--[=[
	Runs the current state's `onUpdate(data, dt)` if defined. Call this from a
	`Heartbeat` / `Stepped` loop to drive per-frame mechanics.
]=]
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

--[=[
	Subscribes to entries into `state` (in addition to its config `onEnter`).
]=]
function StateMachine.onEnter<D>(self: StateMachine<D>, state: string, callback: (ctx: Context<D>) -> ()): Connection
	local s: any = self
	assert(not s._destroyed, "[StateMachine] cannot observe a destroyed machine")
	return lazySignal(s._enterSignals, state):connect(callback)
end

--[=[
	Subscribes to exits from `state` (in addition to its config `onExit`).
]=]
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

----------------------------------------------------------------------
-- Group: one machine per key (e.g. per Player), created on demand.
----------------------------------------------------------------------

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
	Creates a registry of machines keyed by `K`. Machines are created on
	demand the first time a key is used.

	* Pass a `Config` — every key shares the same state graph; `data` is
	  deep-copied per key.
	* Pass `builder(key)` — return a fresh `Config` when you need per-key
	  differences (player stats, instance attributes, etc.).
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

--[=[
	Returns the machine for `key`, creating it from `builder(key)` if needed.
]=]
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

--[=[
	Current state name for `key` (creating the machine if needed).
]=]
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

--[=[
	Drives `update(dt)` on every live machine in the group.
]=]
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

--[=[
	Destroys and forgets the machine for `key`.
]=]
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
