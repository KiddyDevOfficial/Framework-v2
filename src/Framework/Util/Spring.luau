--!strict
--[=[
	@module Util.Spring
	Physics-based spring interpolation - the natural alternative to fixed
	tweens for camera follow, UI bounce, recoil, and smooth value chasing.
	Drive it from a `Heartbeat` / `RenderStep` hook by calling `:step(dt)`.

	The integrator is the unconditionally stable semi-implicit damped
	harmonic oscillator (Allen Chou), so large `dt` spikes never explode.
	Works on `number`, `Vector2`, and `Vector3` targets.

	* `frequency`     - oscillations per second; higher = snappier.
	* `dampingRatio`  - `1` critically damped (no overshoot), `<1`
	                    bouncy/underdamped, `>1` sluggish/overdamped.

	```lua
	local Spring = Framework.Spring

	local camera = Spring.new(Vector3.zero, 4, 1)
	camera:setTarget(Vector3.new(0, 10, 0))

	RunService.RenderStepped:Connect(function(dt)
	    workspace.CurrentCamera.CFrame = CFrame.new(camera:step(dt))
	end)

	-- A bouncy UI value:
	local scale = Spring.new(1, 6, 0.4)
	button.MouseButton1Click:Connect(function()
	    scale:impulse(2)   -- kick the velocity for a pop
	end)
	```
]=]

local Spring = {}
Spring.__index = Spring

local DEFAULT_FREQUENCY = 4
local DEFAULT_DAMPING_RATIO = 1
local DEFAULT_POSITION_EPSILON = 1e-3
local DEFAULT_VELOCITY_EPSILON = 1e-3
local TWO_PI = 2 * math.pi

export type Animatable = number | Vector2 | Vector3

export type Spring<T> = {
	step: (self: Spring<T>, dt: number) -> T,
	getValue: (self: Spring<T>) -> T,
	getVelocity: (self: Spring<T>) -> T,
	getTarget: (self: Spring<T>) -> T,
	setTarget: (self: Spring<T>, target: T) -> (),
	setValue: (self: Spring<T>, value: T, settle: boolean?) -> (),
	setVelocity: (self: Spring<T>, velocity: T) -> (),
	setFrequency: (self: Spring<T>, frequency: number) -> (),
	setDampingRatio: (self: Spring<T>, dampingRatio: number) -> (),
	impulse: (self: Spring<T>, delta: T) -> (),
	isSettled: (self: Spring<T>, positionEpsilon: number?, velocityEpsilon: number?) -> boolean,
}

local function magnitude(value: any): number
	if type(value) == "number" then
		return math.abs(value)
	end
	-- Vector2 / Vector3
	return value.Magnitude
end

--[=[
	Creates a spring resting at `initial`. `frequency` defaults to `4`
	and `dampingRatio` to `1` (critically damped). The value type is
	inferred from `initial` and must be a `number`, `Vector2`, or `Vector3`.
]=]
function Spring.new<T>(initial: T, frequency: number?, dampingRatio: number?): Spring<T>
	local zero: any = initial
	if type(initial) == "number" then
		zero = 0
	else
		-- Vector types
		zero = (initial :: any) - (initial :: any)
	end

	local self = setmetatable({
		_value = initial,
		_velocity = zero,
		_target = initial,
		_frequency = math.max(frequency or DEFAULT_FREQUENCY, 0),
		_dampingRatio = math.max(dampingRatio or DEFAULT_DAMPING_RATIO, 0),
	}, Spring)
	return self :: any
end

function Spring.step<T>(self: Spring<T>, dt: number): T
	local s: any = self
	if dt <= 0 then
		return s._value
	end

	local omega = TWO_PI * s._frequency
	if omega <= 0 then
		return s._value
	end

	local x: any = s._value
	local v: any = s._velocity
	local xt: any = s._target

	local f = 1 + 2 * dt * s._dampingRatio * omega
	local oo = omega * omega
	local hoo = dt * oo
	local hhoo = dt * hoo
	local detInv = 1 / (f + hhoo)

	local detX = f * x + dt * v + hhoo * xt
	local detV = v + hoo * (xt - x)

	s._value = detX * detInv
	s._velocity = detV * detInv
	return s._value
end

function Spring.getValue<T>(self: Spring<T>): T
	return (self :: any)._value
end

function Spring.getVelocity<T>(self: Spring<T>): T
	return (self :: any)._velocity
end

function Spring.getTarget<T>(self: Spring<T>): T
	return (self :: any)._target
end

function Spring.setTarget<T>(self: Spring<T>, target: T)
	(self :: any)._target = target
end

function Spring.setValue<T>(self: Spring<T>, value: T, settle: boolean?)
	local s: any = self
	s._value = value
	if settle then
		s._velocity = s._velocity - s._velocity
		s._target = value
	end
end

function Spring.setVelocity<T>(self: Spring<T>, velocity: T)
	(self :: any)._velocity = velocity
end

function Spring.setFrequency<T>(self: Spring<T>, frequency: number)
	(self :: any)._frequency = math.max(frequency, 0)
end

function Spring.setDampingRatio<T>(self: Spring<T>, dampingRatio: number)
	(self :: any)._dampingRatio = math.max(dampingRatio, 0)
end

function Spring.impulse<T>(self: Spring<T>, delta: T)
	local s: any = self
	s._velocity = s._velocity + delta
end

function Spring.isSettled<T>(self: Spring<T>, positionEpsilon: number?, velocityEpsilon: number?): boolean
	local s: any = self
	local posEps = positionEpsilon or DEFAULT_POSITION_EPSILON
	local velEps = velocityEpsilon or DEFAULT_VELOCITY_EPSILON
	return magnitude(s._target - s._value) <= posEps and magnitude(s._velocity) <= velEps
end

return Spring
