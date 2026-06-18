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

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))
local GlobalSignals = Atlas.GlobalSignals

local Bank = GlobalSignals.Bank("Example")

export type PlayerStateChangedArgs = {
	player: Player,
	state: string,
	oldState: string?,
}

return {
	--RoundStarted = Bank:Signal("RoundStarted") :: Atlas.GlobalSignal<string>,
	--PlayerStateChanged = Bank:Signal("PlayerStateChanged") :: Atlas.GlobalSignal<PlayerStateChangedArgs>,
}
