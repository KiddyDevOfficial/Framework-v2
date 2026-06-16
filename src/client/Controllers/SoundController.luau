--!strict
--[=[
	@controller SoundController
	Singleton wrapper around `Framework.Util.Sound` - one shared sound handler
	for the whole client. Assign a library of template `Sound`s once, then any
	controller can play them by name by depending on `"SoundController"` (or
	just requiring this module).

	On `Init` it looks for a default library at `SoundService.Sounds` and assigns
	it if present; otherwise call `:setLibrary(folder)` yourself (e.g. point it
	at `ReplicatedStorage.Assets.Sounds`).

	```lua
	local SoundController = require(script.Parent.SoundController)

	SoundController:setLibrary(ReplicatedStorage.Assets.Sounds)
	SoundController:play("Coin")
	SoundController:playAt("Explosion", hitPosition, { group = "SFX" })
	SoundController:setMasterVolume(0.8)
	```

	For anything the proxy below doesn't cover, reach the handler directly via
	`SoundController.Player`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))
local Sound = Framework.Util.Sound

type PlayProps = Framework.SoundPlayProps

local player = Sound.new()

local SoundController = {
	Player = player,
}

function SoundController:Init()
	local defaultLibrary = SoundService:FindFirstChild("Sounds")
	if defaultLibrary then
		player:setLibrary(defaultLibrary)
	end
end

function SoundController:setLibrary(folder: Instance)
	player:setLibrary(folder)
end

function SoundController:hasLibrary(): boolean
	return player:hasLibrary()
end

function SoundController:get(name: string): Sound?
	return player:get(name)
end

function SoundController:play(name: string, props: PlayProps?): Sound?
	return player:play(name, props)
end

function SoundController:playOn(name: string, parent: Instance, props: PlayProps?): Sound?
	return player:playOn(name, parent, props)
end

function SoundController:playAt(name: string, target: Vector3 | BasePart, props: PlayProps?): Sound?
	return player:playAt(name, target, props)
end

function SoundController:stop(sound: Sound)
	player:stop(sound)
end

function SoundController:stopAll()
	player:stopAll()
end

function SoundController:setGroupVolume(name: string, volume: number)
	player:setGroupVolume(name, volume)
end

function SoundController:setMasterVolume(volume: number)
	player:setMasterVolume(volume)
end

function SoundController:setMuted(muted: boolean)
	player:setMuted(muted)
end

function SoundController:isMuted(): boolean
	return player:isMuted()
end

function SoundController:Stop()
	player:destroy()
end

return SoundController
