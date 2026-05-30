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
}

export type Trove = Trove.Trove
export type Timer = Timer.Timer
export type Promise<T> = Promise.Promise<T>
export type Observer<T> = Observer.Observer<T>

return Util
