--!strict
--[=[
	@module Util.Observer.observeCharacter
	Observes each player's character, including the current character and
	future respawns. Built on top of `observePlayer`.
]=]

local Trove = require(script.Parent.Parent.Trove)
local Types = require(script.Parent.Types)
local observePlayer = require(script.Parent.observePlayer)

type Cleanup = Types.Cleanup
type Stop = Types.Stop
type CharacterCallback = Types.CharacterCallback

local function observeCharacter(callback: CharacterCallback): Stop
	assert(type(callback) == "function", "[Observer.observeCharacter] callback must be a function")

	return observePlayer(function(player: Player)
		local charTrove = Trove.new()
		local current: Cleanup? = nil

		local function clear()
			local cleanup = current
			current = nil
			if cleanup then
				cleanup()
			end
		end

		local function onCharacter(character: Model)
			clear()
			current = callback(player, character)
		end

		charTrove:connect(player.CharacterAdded, onCharacter)
		charTrove:connect(player.CharacterRemoving, clear)

		local existing = player.Character
		if existing then
			onCharacter(existing)
		end

		return function()
			clear()
			charTrove:destroy()
		end
	end)
end

return observeCharacter
