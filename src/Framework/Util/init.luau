--!strict
--[=[
	@module Util
	Aggregator for framework utility modules. Either grab the bundle
	(`Framework.Util.TableUtil.deepCopy(...)`) or pull one directly off
	`Framework` (`Framework.TableUtil.deepCopy(...)`).
]=]

local Trove = require(script.Trove)
local TableUtil = require(script.TableUtil)
local StringUtil = require(script.StringUtil)
local NumberUtil = require(script.NumberUtil)
local Debounce = require(script.Debounce)
local Timer = require(script.Timer)
local Promise = require(script.Promise)
local GuiButton = require(script.GuiButton)
local Observer = require(script.Observer)
local StateMachine = require(script.StateMachine)
local Spring = require(script.Spring)
local Queue = require(script.Queue)
local Cache = require(script.Cache)

local Util = {
	Trove = Trove,
	TableUtil = TableUtil,
	StringUtil = StringUtil,
	NumberUtil = NumberUtil,
	Debounce = Debounce,
	Timer = Timer,
	Promise = Promise,
	GuiButton = GuiButton,
	Observer = Observer,
	StateMachine = StateMachine,
	Spring = Spring,
	Queue = Queue,
	Cache = Cache,
}

export type Trove = Trove.Trove
export type Timer = Timer.Timer
export type Promise<T> = Promise.Promise<T>
export type Observer<T> = Observer.Observer<T>
export type StateMachine<D> = StateMachine.StateMachine<D>
export type StateConfig<D> = StateMachine.StateConfig<D>
export type StateContext<D> = StateMachine.Context<D>
export type StateMachineConfig<D> = StateMachine.Config<D>
export type StateMachineGroup<K, D> = StateMachine.Group<K, D>
export type Spring<T> = Spring.Spring<T>
export type Animatable = Spring.Animatable
export type Queue<T> = Queue.Queue<T>
export type Cache<K, V> = Cache.Cache<K, V>
export type CacheOptions = Cache.Options

return Util
