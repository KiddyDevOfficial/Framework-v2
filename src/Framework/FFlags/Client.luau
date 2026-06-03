--!strict
--[=[
	@module FFlags.Client
	Read-only client cache for global runtime flags. The server owns all writes;
	clients receive an initial snapshot and incremental updates.
]=]

local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)

if RunService:IsServer() then
	return {} :: Types.ClientClass
end

type FlagValue = Types.FlagValue
type ChangeSource = Types.ChangeSource
type ChangeHandler = Types.ChangeHandler
type ClientClass = Types.ClientClass

local Net: any = nil

local function getNet(): any
	if not Net then
		Net = require(script.Parent.Networking)
	end
	return Net
end

local Client = {
	Changed = Signal.new(),
	_flags = {} :: { [string]: FlagValue },
	_observers = {} :: { [string]: Signal.Signal<FlagValue?, FlagValue?, ChangeSource> },
	_initialized = false,
	_ready = false,
	_readySignal = Signal.new(),
	_connection = nil :: RBXScriptConnection?,
}

local function assertFlagName(name: string)
	assert(type(name) == "string" and #name > 0, "[FFlags.Client] flag name must be a non-empty string")
end

local function fireChanged(self: any, name: string, value: FlagValue?, oldValue: FlagValue?, source: ChangeSource)
	self.Changed:fire(name, value, oldValue, source)

	local signal = self._observers[name]
	if signal then
		signal:fire(value, oldValue, source)
	end
end

local function applyValue(self: any, name: string, value: FlagValue?, removed: boolean?, source: ChangeSource)
	assertFlagName(name)

	local oldValue = self._flags[name]
	if removed == true then
		if oldValue == nil then
			return
		end
		self._flags[name] = nil
		fireChanged(self, name, nil, oldValue, source)
		return
	end

	if value == nil or oldValue == value then
		return
	end

	self._flags[name] = value
	fireChanged(self, name, value, oldValue, source)
end

function Client.init(self: ClientClass)
	if self._initialized then
		return
	end
	self._initialized = true
	local net = getNet()

	self._connection = net.Update:OnClientEvent(function(update)
		applyValue(self, update.Name, update.Value, update.Removed, update.Source)
	end)

	local snapshot = net.Snapshot:InvokeServer(nil)
	for name, value in snapshot do
		applyValue(self, name, value, false, "default")
	end

	self._ready = true
	self._readySignal:fire()
end

function Client.destroy(self: ClientClass)
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	for _, signal in self._observers do
		signal:destroy()
	end
	table.clear(self._observers)
	table.clear(self._flags)

	self.Changed:destroy()
	self.Changed = Signal.new()
	self._readySignal:destroy()
	self._readySignal = Signal.new()
	self._initialized = false
	self._ready = false
end

function Client.waitForReady(self: ClientClass)
	if self._ready then
		return
	end
	self._readySignal:wait()
end

function Client.isReady(self: ClientClass): boolean
	return self._ready
end

function Client.get(self: ClientClass, name: string, defaultValue: FlagValue?): FlagValue?
	assertFlagName(name)
	local value = self._flags[name]
	if value == nil then
		return defaultValue
	end
	return value
end

function Client.getBoolean(self: ClientClass, name: string, defaultValue: boolean?): boolean
	local value = self:get(name, defaultValue)
	if value == nil then
		return false
	end
	return value == true
end

function Client.getNumber(self: ClientClass, name: string, defaultValue: number?): number?
	local value = self:get(name, defaultValue)
	if type(value) == "number" then
		return value
	end
	return defaultValue
end

function Client.getString(self: ClientClass, name: string, defaultValue: string?): string?
	local value = self:get(name, defaultValue)
	if type(value) == "string" then
		return value
	end
	return defaultValue
end

function Client.getAll(self: ClientClass): { [string]: FlagValue }
	return table.clone(self._flags)
end

function Client.observe(self: ClientClass, name: string, handler: ChangeHandler): () -> ()
	assertFlagName(name)
	assert(type(handler) == "function", "[FFlags.Client] handler must be a function")

	local signal = self._observers[name]
	if not signal then
		signal = Signal.new()
		self._observers[name] = signal
	end

	local connection = signal:connect(handler)

	local current = self._flags[name]
	if current ~= nil then
		task.spawn(handler, current, nil, "default")
	end

	return function()
		connection:disconnect()
	end
end

return Client :: ClientClass
