--!strict
--[=[
	@module ExampleStates
	Starter state-machine definition — copy and rename for your own mechanics
	(combat, tools, NPC AI, minigames, etc.).

	`config` is a shared graph you can pass straight to `StateMachine.group`:

	```lua
	local ExampleStates = require(ReplicatedStorage.Shared.StateMachines.ExampleStates)
	local Framework = require(ReplicatedStorage.Framework)

	local group = Framework.StateMachine.group(ExampleStates.config)

	group:transition(player, "Active")
	group:force(player, "Cooldown")

	RunService.Heartbeat:Connect(function(dt)
	    group:update(dt)
	end)

	Players.PlayerRemoving:Connect(function(p)
	    group:remove(p)
	end)
	```

	When each key needs its own `data` shape, use `build` instead:

	```lua
	local group = Framework.StateMachine.group(ExampleStates.build)
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

export type ExampleData = {
	ticks: number,
	cooldownRemaining: number,
}

local COOLDOWN_DURATION = 2

local config: Framework.StateMachineConfig<ExampleData> = {
	initial = "Idle",
	data = {
		ticks = 0,
		cooldownRemaining = 0,
	},
	states = {
		Idle = {
			transitions = { "Active" },
		},

		Active = {
			transitions = { "Idle", "Cooldown" },
			onEnter = function(ctx)
				ctx.data.ticks += 1
			end,
		},

		Cooldown = {
			transitions = { "Idle" },
			onEnter = function(ctx)
				ctx.data.cooldownRemaining = COOLDOWN_DURATION
			end,
			onUpdate = function(data, dt)
				data.cooldownRemaining = math.max(0, data.cooldownRemaining - dt)
			end,
			onExit = function(ctx)
				ctx.data.cooldownRemaining = 0
			end,
		},
	},
}

local function build(_key: any): Framework.StateMachineConfig<ExampleData>
	return {
		initial = config.initial,
		states = config.states,
		data = {
			ticks = 0,
			cooldownRemaining = 0,
		},
	}
end

return {
	config = config,
	build = build,
	COOLDOWN_DURATION = COOLDOWN_DURATION,
}
