--!strict
--[=[
	@module Util.Observer.observePlayer
	Observes every player, including those already in the game.
]=]

local Players = game:GetService("Players")

local Trove = require(script.Parent.Parent.Trove)
local Types = require(script.Parent.Types)

type Cleanup = Types.Cleanup
type Stop = Types.Stop
type PlayerCallback = Types.PlayerCallback

local function observePlayer(callback: PlayerCallback): Stop
	assert(type(callback) == "function", "[Observer.observePlayer] callback must be a function")

	local trove = Trove.new()
	local cleanups: { [Player]: Cleanup } = {}

	local function onAdded(player: Player)
		if cleanups[player] then
			return
		end
		cleanups[player] = callback(player) or function() end
	end

	local function onRemoving(player: Player)
		local cleanup = cleanups[player]
		if cleanup then
			cleanups[player] = nil
			cleanup()
		end
	end

	trove:connect(Players.PlayerAdded, onAdded)
	trove:connect(Players.PlayerRemoving, onRemoving)

	for _, player in Players:GetPlayers() do
		onAdded(player)
	end

	return function()
		for player in cleanups do
			onRemoving(player)
		end
		trove:destroy()
	end
end

return observePlayer
