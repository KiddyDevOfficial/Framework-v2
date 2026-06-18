--!strict
--[=[
	@module Util.Sound
	Small sound handler for named `Sound` templates. It can play 2D sounds, 3D
	positional sounds, or sounds parented to an instance. Each play is a clone,
	so sounds can overlap, and volume flows through managed `SoundGroup`s under
	one master group.

	```lua
	local Sound = Weave.Sound

	local sfx = Sound.new()
	sfx:setLibrary(ReplicatedStorage.Assets.Sounds)   -- folder of Sound templates

	sfx:play("Coin")                                   -- 2D, one-shot
	sfx:play("Music", { looped = true, group = "Music" })
	sfx:playAt("Explosion", hitPosition, { group = "SFX" })
	sfx:playOn("Engine", car.PrimaryPart, { looped = true })

	sfx:setGroupVolume("Music", 0.5)
	sfx:setMasterVolume(0.8)
	sfx:setMuted(true)

	sfx:destroy()
	```

	Lookup is recursive, so a library split into `SFX/` and `Music/` subfolders
	still resolves by bare name.
]=]

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Trove = require(script.Parent.Trove)

local Sound = {}
Sound.__index = Sound

local DEFAULT_MASTER_NAME = "WeaveMaster"
local SOUND_3D_NAME = "_WeaveSound3D"

export type PlayProps = {
	volume: number?,
	playbackSpeed: number?,
	looped: boolean?,
	timePosition: number?,
	soundId: string?,
	group: string?,
	soundGroup: SoundGroup?,
}

export type Options = {
	library: Instance?,
	defaultParent: Instance?,
	masterGroupName: string?,
}

export type SoundPlayer = {
	setLibrary: (self: SoundPlayer, folder: Instance) -> (),
	getLibrary: (self: SoundPlayer) -> Instance?,
	hasLibrary: (self: SoundPlayer) -> boolean,
	get: (self: SoundPlayer, name: string) -> Sound?,
	play: (self: SoundPlayer, name: string, props: PlayProps?) -> Sound?,
	playOn: (self: SoundPlayer, name: string, parent: Instance, props: PlayProps?) -> Sound?,
	playAt: (self: SoundPlayer, name: string, target: Vector3 | BasePart, props: PlayProps?) -> Sound?,
	stop: (self: SoundPlayer, sound: Sound) -> (),
	stopAll: (self: SoundPlayer) -> (),
	getGroup: (self: SoundPlayer, name: string) -> SoundGroup,
	setGroupVolume: (self: SoundPlayer, name: string, volume: number) -> (),
	setMasterVolume: (self: SoundPlayer, volume: number) -> (),
	getMasterVolume: (self: SoundPlayer) -> number,
	setMuted: (self: SoundPlayer, muted: boolean) -> (),
	isMuted: (self: SoundPlayer) -> boolean,
	destroy: (self: SoundPlayer) -> (),
}

--[=[
	New sound handler. Set a library with `options.library` or `:setLibrary`.
]=]
function Sound.new(options: Options?): SoundPlayer
	local opts: Options = options or {}
	local self = setmetatable({
		_library = opts.library,
		_defaultParent = opts.defaultParent or SoundService,
		_masterName = opts.masterGroupName or DEFAULT_MASTER_NAME,
		_master = nil :: SoundGroup?,
		_groups = {} :: { [string]: SoundGroup },
		_muted = false,
		_masterVolume = 1,
		_trove = Trove.new(),
		_active = Trove.new(),
	}, Sound)
	return self :: any
end

local function ensureMaster(self: any): SoundGroup
	if self._master then
		return self._master
	end
	local group = Instance.new("SoundGroup")
	group.Name = self._masterName
	group.Volume = self._masterVolume
	group.Parent = SoundService
	self._master = group
	self._trove:add(group)
	return group
end

local function resolveGroup(self: any, props: PlayProps): SoundGroup?
	if props.soundGroup then
		return props.soundGroup
	end
	if props.group then
		return self:getGroup(props.group)
	end
	return ensureMaster(self)
end

local function applyProps(self: any, sound: Sound, props: PlayProps)
	if props.soundId then
		sound.SoundId = props.soundId
	end
	if props.volume then
		sound.Volume = props.volume
	end
	if props.playbackSpeed then
		sound.PlaybackSpeed = props.playbackSpeed
	end
	if props.looped ~= nil then
		sound.Looped = props.looped
	end
	if props.timePosition then
		sound.TimePosition = props.timePosition
	end
	sound.SoundGroup = resolveGroup(self, props)
end

-- `owned` may be the sound clone or the hidden 3D holder part.
local function startSound(self: any, sound: Sound, parent: Instance, owned: Instance): Sound
	sound.Parent = parent
	self._active:add(owned)
	sound:Play()
	if not sound.Looped then
		local conn: RBXScriptConnection
		conn = sound.Ended:Connect(function()
			conn:Disconnect()
			self._active:remove(owned)
		end)
	end
	return sound
end

--[=[
	Assigns the template folder. Lookup is recursive.
]=]
function Sound.setLibrary(self: SoundPlayer, folder: Instance)
	assert(typeof(folder) == "Instance", "[Sound] library must be an Instance")
	local s: any = self
	s._library = folder
end

function Sound.getLibrary(self: SoundPlayer): Instance?
	return (self :: any)._library
end

function Sound.hasLibrary(self: SoundPlayer): boolean
	return (self :: any)._library ~= nil
end

--[=[
	The shared template `Sound` for `name`, if one exists.
]=]
function Sound.get(self: SoundPlayer, name: string): Sound?
	local library = (self :: any)._library
	if not library then
		warn("[Sound] no library assigned; call :setLibrary(folder) first")
		return nil
	end
	local found = library:FindFirstChild(name, true)
	if found and found:IsA("Sound") then
		return found
	end
	return nil
end

local function clone(self: SoundPlayer, name: string): Sound?
	local template = self:get(name)
	if not template then
		warn(`[Sound] no sound named '{name}' in the library`)
		return nil
	end
	return template:Clone()
end

--[=[
	Plays `name` as a 2D sound and returns the clone.
]=]
function Sound.play(self: SoundPlayer, name: string, props: PlayProps?): Sound?
	local sound = clone(self, name)
	if not sound then
		return nil
	end
	applyProps(self :: any, sound, props or {})
	return startSound(self :: any, sound, (self :: any)._defaultParent, sound)
end

--[=[
	Plays `name` under `parent`. The clone is cleaned up by this handler.
]=]
function Sound.playOn(self: SoundPlayer, name: string, parent: Instance, props: PlayProps?): Sound?
	local sound = clone(self, name)
	if not sound then
		return nil
	end
	applyProps(self :: any, sound, props or {})
	return startSound(self :: any, sound, parent, sound)
end

--[=[
	Plays `name` at a world position or on a `BasePart`.
]=]
function Sound.playAt(self: SoundPlayer, name: string, target: Vector3 | BasePart, props: PlayProps?): Sound?
	if typeof(target) == "Instance" then
		return self:playOn(name, target, props)
	end

	local sound = clone(self, name)
	if not sound then
		return nil
	end
	applyProps(self :: any, sound, props or {})

	local holder = Instance.new("Part")
	holder.Name = SOUND_3D_NAME
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(target)
	holder.Parent = Workspace

	return startSound(self :: any, sound, holder, holder)
end

function Sound.stop(self: SoundPlayer, sound: Sound)
	(self :: any)._active:remove(sound)
end

--[=[
	Stops sounds started by this player. Library and volume settings stay intact.
]=]
function Sound.stopAll(self: SoundPlayer)
	(self :: any)._active:clean()
end

--[=[
	The managed `SoundGroup` named `name`, created under the master group.
]=]
function Sound.getGroup(self: SoundPlayer, name: string): SoundGroup
	local s: any = self
	local existing = s._groups[name]
	if existing then
		return existing
	end
	local master = ensureMaster(s)
	local existingChild = master:FindFirstChild(name)
	local group: SoundGroup
	if existingChild and existingChild:IsA("SoundGroup") then
		group = existingChild
	else
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = master
		s._trove:add(group)
	end
	s._groups[name] = group
	return group
end

function Sound.setGroupVolume(self: SoundPlayer, name: string, volume: number)
	self:getGroup(name).Volume = volume
end

function Sound.setMasterVolume(self: SoundPlayer, volume: number)
	local s: any = self
	s._masterVolume = volume
	if not s._muted then
		ensureMaster(s).Volume = volume
	end
end

function Sound.getMasterVolume(self: SoundPlayer): number
	return (self :: any)._masterVolume
end

function Sound.setMuted(self: SoundPlayer, muted: boolean)
	local s: any = self
	if s._muted == muted then
		return
	end
	s._muted = muted
	ensureMaster(s).Volume = if muted then 0 else s._masterVolume
end

function Sound.isMuted(self: SoundPlayer): boolean
	return (self :: any)._muted
end

function Sound.destroy(self: SoundPlayer)
	local s: any = self
	s._active:destroy()
	s._trove:destroy()
	s._master = nil
	table.clear(s._groups)
end

return Sound
