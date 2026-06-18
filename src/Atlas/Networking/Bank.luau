--!strict
--[=[
	@module Networking.Bank
	Namespace that owns a group of typed packets. `Networking.Bank("Player")`
	is idempotent - the same name always resolves to the same folder and
	cached packet objects, so two separate shared modules can refer to the
	same packet without double-binding the remote.
]=]

local Manager = require(script.Parent.Manager)
local Event = require(script.Parent.Event)
local UnreliableEvent = require(script.Parent.UnreliableEvent)
local Request = require(script.Parent.Request)

local Bank = {}
Bank.__index = Bank

export type Bank = {
	Name: string,
	_folder: Folder,
	_packets: { [string]: any },
	Event: <Args>(self: Bank, name: string) -> Event.Event<Args>,
	UnreliableEvent: <Args>(self: Bank, name: string) -> UnreliableEvent.UnreliableEvent<Args>,
	Request: <Args, Return>(self: Bank, name: string) -> Request.Request<Args, Return>,
}

local bankCache: { [string]: Bank } = {}

function Bank.new(name: string): Bank
	assert(type(name) == "string" and #name > 0, "[Atlas.Networking] Bank name must be a non-empty string")

	local cached = bankCache[name]
	if cached then
		return cached
	end

	local self = setmetatable({
		Name = name,
		_folder = Manager.GetBankFolder(name),
		_packets = {},
	}, Bank)
	bankCache[name] = self :: any
	return self :: any
end

function Bank.Event<Args>(self: Bank, name: string): Event.Event<Args>
	local existing = self._packets[name]
	if existing then
		return existing
	end
	local packet = Event.new(self._folder, self.Name, name)
	self._packets[name] = packet
	return packet :: Event.Event<Args>
end

function Bank.UnreliableEvent<Args>(self: Bank, name: string): UnreliableEvent.UnreliableEvent<Args>
	local existing = self._packets[name]
	if existing then
		return existing
	end
	local packet = UnreliableEvent.new(self._folder, self.Name, name)
	self._packets[name] = packet
	return packet :: UnreliableEvent.UnreliableEvent<Args>
end

function Bank.Request<Args, Return>(self: Bank, name: string): Request.Request<Args, Return>
	local existing = self._packets[name]
	if existing then
		return existing
	end
	local packet = Request.new(self._folder, self.Name, name)
	self._packets[name] = packet
	return packet :: Request.Request<Args, Return>
end

return Bank
