--!strict
--[=[
	@module Util.Observer
	Observer helpers for things that appear and disappear over time: tagged
	instances, children, properties, attributes, players, and characters.

	Each observer lives in its own child module; this container re-exports
	them as a single library table.

	Each callback may return a cleanup function. It runs when the subject goes
	away or before the next callback for the same subject. Every `observe*`
	function returns a stop function that disconnects everything and runs any
	outstanding cleanups.

	```lua
	local Observer = Atlas.Observer

	local stop = Observer.observeTag("Killbrick", function(part: BasePart)
	    local conn = part.Touched:Connect(onTouch)
	    return function()
	        conn:Disconnect()
	    end
	end)

	stop()
	```

	```lua
	Observer.observeCharacter(function(player, character)
	    local hum = character:WaitForChild("Humanoid")
	    return function() end
	end)
	```
]=]

local Types = require(script.Types)

export type Cleanup = Types.Cleanup
export type Stop = Types.Stop
export type TagCallback = Types.TagCallback
export type ChildCallback = Types.ChildCallback
export type PlayerCallback = Types.PlayerCallback
export type CharacterCallback = Types.CharacterCallback
export type ValueCallback = Types.ValueCallback

return {
	observeTag = require(script.observeTag),
	observeChildren = require(script.observeChildren),
	observeProperty = require(script.observeProperty),
	observeAttribute = require(script.observeAttribute),
	observePlayer = require(script.observePlayer),
	observeCharacter = require(script.observeCharacter),
}
