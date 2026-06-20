--!strict
--[=[
	@module Util.Zone
	Spatial trigger volumes. Give it a part, a list of parts, or a model/folder
	of parts and it polls that region on an interval, firing signals as players
	(and any instances you explicitly watch) enter and leave.

	Detection uses `OverlapParams` with an Include filter, so each poll only
	tests the characters and watched instances you care about, never the whole
	workspace. Works on the server or the client.

	```lua
	local zone = Atlas.Zone.new(workspace.SafeRoom)

	zone.playerEntered:connect(function(player)
	    print(player.Name, "entered the safe room")
	end)
	zone.playerExited:connect(function(player)
	    print(player.Name, "left")
	end)

	-- Track a non-player instance too (e.g. a soccer ball):
	zone:watch({ workspace.Ball })
	zone.instanceEntered:connect(function(instance)
	    if instance == workspace.Ball then
	        print("goal!")
	    end
	end)

	-- A region defined purely by a CFrame + size, no part required:
	local box = Atlas.Zone.fromBox(CFrame.new(0, 5, 0), Vector3.new(20, 10, 20))

	zone:destroy()
	```
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Signal = require(script.Parent.Parent.Signal)

type Signal<T...> = Signal.Signal<T...>

local DEFAULT_ACCURACY = 0.1

local Zone = {}
Zone.__index = Zone

export type Box = { cframe: CFrame, size: Vector3 }

export type Zone = {
	playerEntered: Signal<Player>,
	playerExited: Signal<Player>,
	instanceEntered: Signal<Instance>,
	instanceExited: Signal<Instance>,
	Accuracy: number,
	IsRunning: boolean,
	watch: (self: Zone, instances: { Instance }) -> (),
	unwatch: (self: Zone, instances: { Instance }) -> (),
	getPlayers: (self: Zone) -> { Player },
	isPlayerInside: (self: Zone, player: Player) -> boolean,
	getParts: (self: Zone) -> { BasePart },
	setAccuracy: (self: Zone, seconds: number) -> (),
	start: (self: Zone) -> (),
	stop: (self: Zone) -> (),
	destroy: (self: Zone) -> (),
}

local function collectParts(container: BasePart | { BasePart } | Instance): { BasePart }
	local parts: { BasePart } = {}
	if typeof(container) == "Instance" then
		if container:IsA("BasePart") then
			table.insert(parts, container)
		else
			for _, descendant in container:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end
		end
	elseif type(container) == "table" then
		for _, part in container do
			if typeof(part) == "Instance" and part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	return parts
end

local function playerFromPart(part: BasePart): Player?
	local current: Instance? = part
	while current do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player
			end
		end
		current = current.Parent
	end
	return nil
end

local function watchedRootOf(self: any, part: BasePart): Instance?
	local current: Instance? = part
	while current do
		if self._watched[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function detect(self: any)
	local include: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(include, character)
		end
	end
	for instance in self._watched do
		table.insert(include, instance)
	end
	self._params.FilterDescendantsInstances = include

	local foundPlayers: { [Player]: true } = {}
	local foundInstances: { [Instance]: true } = {}

	local function consider(part: BasePart)
		local player = playerFromPart(part)
		if player then
			foundPlayers[player] = true
			return
		end
		local root = watchedRootOf(self, part)
		if root then
			foundInstances[root] = true
		end
	end

	if self._box then
		for _, part in Workspace:GetPartBoundsInBox(self._box.cframe, self._box.size, self._params) do
			consider(part)
		end
	end
	for _, zonePart in self._parts do
		for _, part in Workspace:GetPartsInPart(zonePart, self._params) do
			consider(part)
		end
	end

	for player in foundPlayers do
		if not self._playersInside[player] then
			self.playerEntered:fire(player)
		end
	end
	for player in self._playersInside do
		if not foundPlayers[player] then
			self.playerExited:fire(player)
		end
	end
	for instance in foundInstances do
		if not self._instancesInside[instance] then
			self.instanceEntered:fire(instance)
		end
	end
	for instance in self._instancesInside do
		if not foundInstances[instance] then
			self.instanceExited:fire(instance)
		end
	end

	self._playersInside = foundPlayers
	self._instancesInside = foundInstances
end

local function construct(parts: { BasePart }, box: Box?): Zone
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {}

	local self = setmetatable({
		playerEntered = Signal.new(),
		playerExited = Signal.new(),
		instanceEntered = Signal.new(),
		instanceExited = Signal.new(),
		Accuracy = DEFAULT_ACCURACY,
		IsRunning = false,
		_parts = parts,
		_box = box,
		_watched = {} :: { [Instance]: true },
		_playersInside = {} :: { [Player]: true },
		_instancesInside = {} :: { [Instance]: true },
		_params = params,
		_accumulator = 0,
		_conn = nil :: RBXScriptConnection?,
	}, Zone)

	;(self :: any):start()
	return self :: any
end

function Zone.new(container: BasePart | { BasePart } | Instance): Zone
	local parts = collectParts(container)
	if #parts == 0 then
		warn("[Zone] no BaseParts found in container; zone will never detect anything")
	end
	return construct(parts, nil)
end

function Zone.fromBox(cframe: CFrame, size: Vector3): Zone
	assert(typeof(cframe) == "CFrame", "[Zone] fromBox: cframe must be a CFrame")
	assert(typeof(size) == "Vector3", "[Zone] fromBox: size must be a Vector3")
	return construct({}, { cframe = cframe, size = size })
end

function Zone.watch(self: Zone, instances: { Instance })
	local s: any = self
	for _, instance in instances do
		s._watched[instance] = true
	end
end

function Zone.unwatch(self: Zone, instances: { Instance })
	local s: any = self
	for _, instance in instances do
		s._watched[instance] = nil
		s._instancesInside[instance] = nil
	end
end

function Zone.getPlayers(self: Zone): { Player }
	local s: any = self
	local players: { Player } = {}
	for player in s._playersInside do
		table.insert(players, player)
	end
	return players
end

function Zone.isPlayerInside(self: Zone, player: Player): boolean
	local s: any = self
	return s._playersInside[player] == true
end

function Zone.getParts(self: Zone): { BasePart }
	local s: any = self
	return table.clone(s._parts)
end

function Zone.setAccuracy(self: Zone, seconds: number)
	assert(seconds > 0, "[Zone] accuracy must be > 0")
	local s: any = self
	s.Accuracy = seconds
end

function Zone.start(self: Zone)
	local s: any = self
	if s.IsRunning then
		return
	end
	s.IsRunning = true
	s._accumulator = 0
	detect(s)
	s._conn = RunService.Heartbeat:Connect(function(dt: number)
		s._accumulator += dt
		if s._accumulator >= s.Accuracy then
			s._accumulator = 0
			detect(s)
		end
	end)
end

function Zone.stop(self: Zone)
	local s: any = self
	if not s.IsRunning then
		return
	end
	s.IsRunning = false
	if s._conn then
		s._conn:Disconnect()
		s._conn = nil
	end
end

function Zone.destroy(self: Zone)
	local s: any = self
	self:stop()
	s.playerEntered:destroy()
	s.playerExited:destroy()
	s.instanceEntered:destroy()
	s.instanceExited:destroy()
	table.clear(s._watched)
	table.clear(s._playersInside)
	table.clear(s._instancesInside)
end

return Zone
