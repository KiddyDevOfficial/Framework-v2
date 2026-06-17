--!strict
--[=[
	@module Util.NumberUtil
	Small math helpers missing from Roblox's base library.
]=]

local NumberUtil = {}

function NumberUtil.clamp(n: number, min: number, max: number): number
	if n < min then
		return min
	elseif n > max then
		return max
	end
	return n
end

function NumberUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--[=[
	The `t` where `lerp(a, b, t) == value`; returns 0 when `a == b`.
]=]
function NumberUtil.inverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return (value - a) / (b - a)
end

--[=[
	Remaps `value` from `[inMin, inMax]` onto `[outMin, outMax]`.
]=]
function NumberUtil.mapRange(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	local t = NumberUtil.inverseLerp(inMin, inMax, value)
	return NumberUtil.lerp(outMin, outMax, t)
end

function NumberUtil.round(n: number): number
	return math.floor(n + 0.5)
end

--[=[
	Rounds to the nearest multiple of `step`.
]=]
function NumberUtil.roundTo(n: number, step: number): number
	if step == 0 then
		return n
	end
	return math.floor(n / step + 0.5) * step
end

--[=[
	Snaps down to the nearest multiple of `step`.
]=]
function NumberUtil.snap(n: number, step: number): number
	if step == 0 then
		return n
	end
	return math.floor(n / step) * step
end

function NumberUtil.sign(n: number): number
	if n > 0 then
		return 1
	elseif n < 0 then
		return -1
	end
	return 0
end

function NumberUtil.approxEqual(a: number, b: number, epsilon: number?): boolean
	return math.abs(a - b) <= (epsilon or 1e-6)
end

function NumberUtil.isBetween(n: number, min: number, max: number, inclusive: boolean?): boolean
	if inclusive == false then
		return n > min and n < max
	end
	return n >= min and n <= max
end

return NumberUtil
