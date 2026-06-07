--!strict
--[=[
	@module GlobalSignals
	Shared in-process signal registry with bank support. Use this when
	multiple scripts in the same server/client VM need to publish and listen
	to lightweight Lua events without wiring object references around.

	For client/server remotes, use `Framework.Networking`. For cross-server
	MessagingService, use `Framework.GlobalMessaging`.

	```lua
	local GlobalSignals = require(ReplicatedStorage.Framework).GlobalSignals
	local Bank = GlobalSignals.Bank("Round")

	local RoundStarted = Bank:Signal<string>("Started")
	RoundStarted:connect(function(mapName)
	    print("round started", mapName)
	end)

	RoundStarted:fire("Arena")
	```
]=]

local Bank = require(script.Bank)
local GlobalSignal = require(script.Signal)

local DEFAULT_BANK = "_Default"

local GlobalSignals = {}

GlobalSignals.Bank = Bank.new

--[=[
	Shortcut for `GlobalSignals.Bank("_Default"):Signal(name)`.
]=]
function GlobalSignals.Signal<T...>(name: string): GlobalSignal.GlobalSignal<T...>
	return Bank.new(DEFAULT_BANK):Signal(name)
end

export type Bank = Bank.Bank
export type Signal<T...> = GlobalSignal.GlobalSignal<T...>

return GlobalSignals
