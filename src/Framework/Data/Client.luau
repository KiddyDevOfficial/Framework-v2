--!strict
--[=[
	@module Data.Client
	Client-side singleton. Subscribes to the framework's replication
	`RemoteEvent`, applies inbound `Init` / `Set` / `ArrayInsert` /
	`ArrayRemove` actions to a local `Data` mirror, and exposes the
	same reactive read / signal API as the server.

	`init` yields until the server replies with the initial snapshot,
	which is why the framework adapter runs it in `Start`.
]=]

local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Data = require(script.Parent.Data)
local Networking = require(script.Parent.Networking)
local Utils = require(script.Parent.Utils)

if RunService:IsServer() then
	return {} :: any
end

type Path = Data.Path

local Client = {
	_data = nil :: Data.Data?,
	_waitSignal = Signal.new(),
	_replicate = nil :: RemoteEvent?,
	_fetch = nil :: RemoteFunction?,
	_initialized = false,
}

local function applyAction(self: any, action: number, ...: any)
	local data: Data.Data = self._data
	if action == Utils.Action.Init then
		assert(self._data == nil, "DataService.Client: received second Init action")
		local snapshot = ...
		self._data = Data.new(snapshot)
		self._waitSignal:fire()
		self._waitSignal:destroy()
	elseif action == Utils.Action.Set then
		local path, value = ...
		data:set(path, value)
	elseif action == Utils.Action.ArrayInsert then
		local path, value, index = ...
		data:arrayInsert(path, value, index)
	elseif action == Utils.Action.ArrayRemove then
		local path, index = ...
		data:arrayRemove(path, index)
	else
		warn(`[Framework.DataService] Client received unknown action {tostring(action)}`)
	end
end

--[=[
	Yields until the server pushes the initial snapshot. Safe to call
	more than once - subsequent calls are no-ops once data is ready.
]=]
function Client.init(self: any)
	if self._initialized then
		self:waitForData()
		return
	end
	self._initialized = true

	local replicate, fetch = Networking.buildClient()
	self._replicate = replicate
	self._fetch = fetch

	replicate.OnClientEvent:Connect(function(action: number, ...: any)
		applyAction(self, action, ...)
	end)

	self:waitForData()
end

function Client.waitForData(self: any): Data.Data
	if self._data then
		return self._data
	end
	self._waitSignal:wait()
	return self._data
end

function Client.fetch(self: any, path: Path?, dontSet: boolean?): any
	local value = (self._fetch :: RemoteFunction):InvokeServer(path)
	if not dontSet and self._data then
		self._data:set(path, value)
	end
	return value
end

function Client.get(self: any, path: Path?): any
	self:waitForData()
	return self._data:get(path)
end

function Client.set(self: any, path: Path, value: any)
	self._data:set(path, value)
end

function Client.update(self: any, path: Path, callback: (any) -> any): any
	return self._data:update(path, callback)
end

function Client.arrayInsert(self: any, path: Path, value: any, index: number?)
	self._data:arrayInsert(path, value, index)
end

function Client.arrayRemove(self: any, path: Path, index: number): any
	return self._data:arrayRemove(path, index)
end

function Client.getChangedSignal(self: any, path: Path)
	return self._data:getChangedSignal(path)
end

function Client.getIndexChangedSignal(self: any, path: Path)
	return self._data:getIndexChangedSignal(path)
end

function Client.getArrayInsertedSignal(self: any, path: Path)
	return self._data:getArrayInsertedSignal(path)
end

function Client.getArrayRemovedSignal(self: any, path: Path)
	return self._data:getArrayRemovedSignal(path)
end

return Client
