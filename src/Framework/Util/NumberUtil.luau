--!strict
--[=[
	@module Util.NumberUtil
	Math helpers Roblox doesn't ship: `clamp`, `lerp`, `inverseLerp`,
	`mapRange`, `roundTo`, `snap`, `sign`, `approxEqual`.
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
	Returns `t` in [0, 1] such that `lerp(a, b, t) == value`. `a == b`
	returns 0.
]=]
function NumberUtil.inverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return (value - a) / (b - a)
end

--[=[
	Remaps `value` from `[inMin, inMax]` to `[outMin, outMax]`.
]=]
function NumberUtil.mapRange(value: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	local t = NumberUtil.inverseLerp(inMin, inMax, value)
	return NumberUtil.lerp(outMin, outMax, t)
end

function NumberUtil.round(n: number): number
	return math.floor(n + 0.5)
end

--[=[
	Rounds `n` to the nearest multiple of `step`. `roundTo(7.4, 0.5)`
	is `7.5`.
]=]
function NumberUtil.roundTo(n: number, step: number): number
	if step == 0 then
		return n
	end
	return math.floor(n / step + 0.5) * step
end

--[=[
	Snaps `n` *down* to the nearest multiple of `step`. `snap(7.9, 0.5)`
	is `7.5`.
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
