--!strict
--[=[
	@module ExampleSignals
	Starter shared GlobalSignals bank - one place defines local in-process
	signals, and any script in the same server/client VM can require this
	module to get the same typed handles.

	```lua
	local Signals = require(ReplicatedStorage.Shared.Signals.ExampleSignals)

	Signals.RoundStarted:connect(function(mapName)
	    print("round started", mapName)
	end)

	Signals.RoundStarted:fire("Arena")
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local GlobalSignals = Framework.GlobalSignals

local Bank = GlobalSignals.Bank("Example")

export type PlayerStateChangedArgs = {
	player: Player,
	state: string,
	oldState: string?,
}

return {
	--RoundStarted = Bank:Signal("RoundStarted") :: Framework.GlobalSignal<string>,
	--PlayerStateChanged = Bank:Signal("PlayerStateChanged") :: Framework.GlobalSignal<PlayerStateChangedArgs>,
}
