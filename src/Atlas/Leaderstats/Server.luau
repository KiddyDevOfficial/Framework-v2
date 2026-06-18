--!strict
--[=[
	@module Leaderstats.Server
	Builds player leaderstats and keeps them in sync with `DataService` paths.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

if RunService:IsClient() then
	return {} :: Types.ServerClass
end

type Entry = Types.Entry
type ValueClass = Types.ValueClass
type InitOptions = Types.InitOptions
type DataServiceLike = Types.DataServiceLike
type ServerClass = Types.ServerClass

type PlayerState = {
	folder: Folder,
	connections: { any },
}

local Server = {
	_entries = {} :: { Entry },
	_dataService = nil :: DataServiceLike?,
	_folderName = "leaderstats",
	_players = {} :: { [Player]: PlayerState },
	_playerAddedConnection = nil :: RBXScriptConnection?,
	_playerRemovingConnection = nil :: RBXScriptConnection?,
	_initialized = false,
}

local function warnOnce(message: string)
	warn("[Leaderstats.Server] " .. message)
end

local function inferClass(value: any): ValueClass
	if type(value) == "string" then
		return "StringValue"
	end
	if type(value) == "number" then
		if value == math.floor(value) then
			return "IntValue"
		end
		return "NumberValue"
	end
	return "StringValue"
end

local function createValueInstance(className: ValueClass): ValueBase
	return Instance.new(className)
end

local function applyValue(instance: ValueBase, value: any)
	if instance:IsA("IntValue") then
		instance.Value = if type(value) == "number" then math.floor(value) else 0
	elseif instance:IsA("NumberValue") then
		instance.Value = if type(value) == "number" then value else 0
	elseif instance:IsA("StringValue") then
		instance.Value = if value ~= nil then tostring(value) else ""
	end
end

local function ensureValueInstance(folder: Folder, entry: Entry, currentValue: any): ValueBase
	local existing = folder:FindFirstChild(entry.Name)
	local className = entry.Class or inferClass(currentValue)

	if existing and existing.ClassName == className then
		return existing :: ValueBase
	end

	if existing then
		existing:Destroy()
	end

	local instance = createValueInstance(className)
	instance.Name = entry.Name
	instance.Parent = folder
	return instance
end

function Server.init(self: ServerClass, options: InitOptions)
	if self._initialized then
		return
	end
	self._initialized = true

	assert(type(options.Entries) == "table", "[Leaderstats.Server] Entries table is required")
	assert(options.DataService ~= nil, "[Leaderstats.Server] DataService is required")

	self._entries = options.Entries
	self._dataService = options.DataService
	self._folderName = options.FolderName or "leaderstats"

	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			self:mountPlayer(player)
		end)
	end)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		self:unmountPlayer(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:mountPlayer(player)
		end)
	end
end

function Server.destroy(self: ServerClass)
	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
		self._playerAddedConnection = nil
	end
	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
		self._playerRemovingConnection = nil
	end

	for player in pairs(self._players) do
		self:unmountPlayer(player)
	end

	self._entries = {}
	self._dataService = nil
	self._initialized = false
end

function Server.mountPlayer(self: ServerClass, player: Player)
	if self._players[player] then
		return
	end

	local dataService = self._dataService
	if not dataService then
		return
	end

	local ok, err = pcall(function()
		dataService:WaitForData(player)
	end)
	if not ok then
		warnOnce(`failed to wait for data for {player.Name}: {err}`)
		return
	end

	local folder = player:FindFirstChild(self._folderName)
	if not folder or not folder:IsA("Folder") then
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = self._folderName
		folder.Parent = player
	end

	local state: PlayerState = {
		folder = folder,
		connections = {},
	}

	for _, entry in self._entries do
		local currentValue = dataService:Get(player, entry.Path)
		local valueObject = ensureValueInstance(folder, entry, currentValue)
		applyValue(valueObject, currentValue)

		local changedSignal = dataService:GetChangedSignal(player, entry.Path)
		local connection = changedSignal:connect(function(newValue: any)
			applyValue(valueObject, newValue)
		end)
		table.insert(state.connections, connection)
	end

	self._players[player] = state
end

function Server.unmountPlayer(self: ServerClass, player: Player)
	local state = self._players[player]
	if not state then
		return
	end

	for _, connection in state.connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		elseif type(connection) == "table" and connection.disconnect then
			connection:disconnect()
		end
	end

	self._players[player] = nil
end

return Server :: ServerClass
