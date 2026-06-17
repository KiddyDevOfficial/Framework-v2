--!strict
--[=[
	Menu frame animation styles for `FrameController`. Position and size tween
	together so the motion stays blended. Set per frame with `AnimateStyle`.
]=]

local TweenService = game:GetService("TweenService")

export type AnimContext = {
	frame: GuiObject,
	defaultSize: UDim2,
	defaultPos: UDim2,
	camera: Camera,
	blur: BlurEffect,
	defaultFov: number,
	applyEffects: boolean,
	play: (tweens: { Tween }, onComplete: ((Enum.PlaybackState) -> ())?) -> (),
}

export type Style = {
	OnPop: (ctx: AnimContext) -> (),
	UnPop: (ctx: AnimContext) -> (),
}

local FrameStyles = {}

local CLOSE_DURATION = 0.11
local CLOSE_EFFECTS_DURATION = 0.08
local CLOSE_EASING = Enum.EasingStyle.Quint
local CLOSE_Y_DELTA = 0.07
local CLOSE_SIZE_FACTOR = 0.93

local function resolveSizeFactor(object: GuiObject, factor: number): UDim2
	local size = object.Size
	return UDim2.fromScale(size.X.Scale * factor, size.Y.Scale * factor)
end

local function isScaleOnly(size: UDim2): boolean
	return size.X.Offset == 0 and size.Y.Offset == 0
end

local function posX(defaultPos: UDim2, xScale: number): UDim2
	return UDim2.new(xScale, defaultPos.X.Offset, defaultPos.Y.Scale, defaultPos.Y.Offset)
end

local function posY(defaultPos: UDim2, yScale: number): UDim2
	return UDim2.new(defaultPos.X.Scale, defaultPos.X.Offset, yScale, defaultPos.Y.Offset)
end

local function posYOffset(defaultPos: UDim2, delta: number): UDim2
	return UDim2.new(
		defaultPos.X.Scale,
		defaultPos.X.Offset,
		defaultPos.Y.Scale + delta,
		defaultPos.Y.Offset
	)
end

local function playEffects(ctx: AnimContext, tweenInfo: TweenInfo, fovMul: number, blurSize: number)
	if not ctx.applyEffects then
		return
	end
	ctx.play({
		TweenService:Create(ctx.camera, tweenInfo, { FieldOfView = ctx.defaultFov * fovMul }),
		TweenService:Create(ctx.blur, tweenInfo, { Size = blurSize }),
	})
end

local function blendOpen(
	ctx: AnimContext,
	startPos: UDim2,
	startSize: UDim2,
	duration: number,
	easing: Enum.EasingStyle,
	fovMul: number,
	blurSize: number
)
	local frame = ctx.frame
	frame.Position = startPos
	frame.Size = startSize

	local info = TweenInfo.new(duration, easing, Enum.EasingDirection.Out)
	ctx.play({
		TweenService:Create(frame, info, {
			Position = ctx.defaultPos,
			Size = ctx.defaultSize,
		}),
	})
	playEffects(ctx, info, fovMul, blurSize)
end

local function startSize(ctx: AnimContext, factor: number): UDim2
	if isScaleOnly(ctx.defaultSize) then
		return resolveSizeFactor(ctx.frame, factor)
	end
	return ctx.defaultSize
end

local function exitSize(ctx: AnimContext, factor: number): UDim2
	if isScaleOnly(ctx.frame.Size) then
		return resolveSizeFactor(ctx.frame, factor)
	end
	return ctx.frame.Size
end

local function blendClose(
	ctx: AnimContext,
	exitPos: UDim2,
	exitSizeGoal: UDim2,
	duration: number,
	easing: Enum.EasingStyle,
	effectsDuration: number?
)
	local frame = ctx.frame
	local frameInfo = TweenInfo.new(duration, easing, Enum.EasingDirection.In)
	ctx.play({
		TweenService:Create(frame, frameInfo, {
			Position = exitPos,
			Size = exitSizeGoal,
		}),
	})

	if not ctx.applyEffects then
		return
	end

	local effectInfo = TweenInfo.new(effectsDuration or duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	ctx.play({
		TweenService:Create(ctx.camera, effectInfo, { FieldOfView = ctx.defaultFov }),
		TweenService:Create(ctx.blur, effectInfo, { Size = 0 }),
	})
end

local function satisfyingCloseDown(ctx: AnimContext)
	blendClose(
		ctx,
		posYOffset(ctx.defaultPos, CLOSE_Y_DELTA),
		exitSize(ctx, CLOSE_SIZE_FACTOR),
		CLOSE_DURATION,
		CLOSE_EASING,
		CLOSE_EFFECTS_DURATION
	)
end

local styles: { [string]: Style } = {
	default = {
		OnPop = function(ctx)
			blendOpen(
				ctx,
				posY(ctx.defaultPos, 1.08),
				startSize(ctx, 0.92),
				0.32,
				Enum.EasingStyle.Quint,
				1.12,
				12
			)
		end,
		UnPop = function(ctx)
			satisfyingCloseDown(ctx)
		end,
	},

	liquid = {
		OnPop = function(ctx)
			blendOpen(
				ctx,
				posY(ctx.defaultPos, 1.10),
				startSize(ctx, 0.90),
				0.34,
				Enum.EasingStyle.Quint,
				1.12,
				12
			)
		end,
		UnPop = function(ctx)
			satisfyingCloseDown(ctx)
		end,
	},

	fancy = {
		OnPop = function(ctx)
			blendOpen(
				ctx,
				posY(ctx.defaultPos, 1.12),
				startSize(ctx, 0.91),
				0.30,
				Enum.EasingStyle.Cubic,
				1.12,
				12
			)
		end,
		UnPop = function(ctx)
			satisfyingCloseDown(ctx)
		end,
	},

	smooth = {
		OnPop = function(ctx)
			blendOpen(
				ctx,
				posY(ctx.defaultPos, 1.06),
				startSize(ctx, 0.94),
				0.30,
				Enum.EasingStyle.Sine,
				1.10,
				10
			)
		end,
		UnPop = function(ctx)
			satisfyingCloseDown(ctx)
		end,
	},

	elastic = {
		OnPop = function(ctx)
			blendOpen(
				ctx,
				posY(ctx.defaultPos, 1.06),
				startSize(ctx, 0.94),
				0.30,
				Enum.EasingStyle.Sine,
				1.10,
				10
			)
		end,
		UnPop = function(ctx)
			satisfyingCloseDown(ctx)
		end,
	},

	slide = {
		OnPop = function(ctx)
			local frame = ctx.frame
			frame.Size = ctx.defaultSize
			frame.Position = posX(ctx.defaultPos, -0.55)

			local info = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			ctx.play({
				TweenService:Create(frame, info, { Position = ctx.defaultPos }),
			})
			playEffects(ctx, info, 1.08, 8)
		end,

		UnPop = function(ctx)
			local info = TweenInfo.new(CLOSE_DURATION, CLOSE_EASING, Enum.EasingDirection.In)
			ctx.play({
				TweenService:Create(ctx.frame, info, {
					Position = posX(ctx.defaultPos, ctx.defaultPos.X.Scale + 0.12),
				}),
			})
			if ctx.applyEffects then
				local effectInfo = TweenInfo.new(CLOSE_EFFECTS_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				ctx.play({
					TweenService:Create(ctx.camera, effectInfo, { FieldOfView = ctx.defaultFov }),
					TweenService:Create(ctx.blur, effectInfo, { Size = 0 }),
				})
			end
		end,
	},

	drop = {
		OnPop = function(ctx)
			blendOpen(
				ctx,
				posY(ctx.defaultPos, -0.35),
				startSize(ctx, 0.93),
				0.34,
				Enum.EasingStyle.Quint,
				1.14,
				10
			)
		end,
		UnPop = function(ctx)
			satisfyingCloseDown(ctx)
		end,
	},
}

function FrameStyles.get(name: string?): Style
	local key = if type(name) == "string" and styles[name] then name else "default"
	return styles[key]
end

function FrameStyles.names(): { string }
	local out: { string } = {}
	for key in styles do
		table.insert(out, key)
	end
	table.sort(out)
	return out
end

return FrameStyles
