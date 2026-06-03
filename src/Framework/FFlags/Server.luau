--!strict
--[=[
	@module FFlags.Server
	Global runtime flags shared between live servers through `GlobalMessaging`.

	Flags are intentionally lightweight and non-persistent. Use them for live
	toggles and short-lived shared values; store long-term config elsewhere.
]=]

local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local GlobalMessaging = require(script.Parent.Parent.GlobalMessaging)
local Types = require(script.Parent.Types)

if RunService:IsClient() then
	return {} :: Types.ServerClass
end

type FlagValue = Types.FlagValue
type ChangeSource = Types.ChangeSource
type ChangeHandler = Types.ChangeHandler
type InitOptions = Types.InitOptions
type FlagChangedPayload = Types.FlagChangedPayload
type ServerClass = Types.ServerClass

local Net = require(script.Parent.Networking)
local Bank = GlobalMessaging.Bank("FFlags")
local FlagChanged = Bank:Event("Changed") :: GlobalMessaging.Topic<FlagChangedPayload>

local Server = {
	Changed = Signal.new(),
	_flags = {} :: { [string]: FlagValue },
	_observers = {} :: { [string]: Signal.Signal<FlagValue?, FlagValue?, ChangeSource> },
	_unsubscribe = nil :: (() -> ())?,
	_initialized = false,
}

local function assertFlagName(name: string)
	assert(type(name) == "string" and #name > 0, "[FFlags.Server] flag name must be a non-empty string")
end

local function fireChanged(self: any, name: string, value: FlagValue?, oldValue: FlagValue?, source: ChangeSource)
	self.Changed:fire(name, value, oldValue, source)
	Net.Update:FireAllClients({
		Name = name,
		Value = value,
		OldValue = oldValue,
		Removed = value == nil,
		Source = source,
	})

	local signal = self._observers[name]
	if signal then
		signal:fire(value, oldValue, source)
	end
end

function Server.init(self: ServerClass, options: InitOptions?)
	if self._initialized then
		return
	end
	self._initialized = true

	if options and options.Defaults then
		for name, value in options.Defaults do
			assertFlagName(name)
			self._flags[name] = value
			fireChanged(self, name, value, nil, "default")
		end
	end

	Net.Snapshot:OnServerInvoke(function()
		return self:getAll()
	end)

	self._unsubscribe = FlagChanged:Subscribe(function(message)
		local payload = message.Data
		if payload.SourceJobId == game.JobId then
			return
		end

		if payload.Removed == true then
			self:removeLocal(payload.Name, "remote")
		else
			local value = payload.Value
			if value ~= nil then
				self:setLocal(payload.Name, value, "remote")
			end
		end
	end)
end

function Server.destroy(self: ServerClass)
	if self._unsubscribe then
		self._unsubscribe()
		self._unsubscribe = nil
	end

	for _, signal in self._observers do
		signal:destroy()
	end
	table.clear(self._observers)
	table.clear(self._flags)
	self.Changed:destroy()
	self.Changed = Signal.new()
	self._initialized = false
end

function Server.get(self: ServerClass, name: string, defaultValue: FlagValue?): FlagValue?
	assertFlagName(name)
	local value = self._flags[name]
	if value == nil then
		return defaultValue
	end
	return value
end

function Server.getBoolean(self: ServerClass, name: string, defaultValue: boolean?): boolean
	local value = self:get(name, defaultValue)
	if value == nil then
		return false
	end
	return value == true
end

function Server.getNumber(self: ServerClass, name: string, defaultValue: number?): number?
	local value = self:get(name, defaultValue)
	if type(value) == "number" then
		return value
	end
	return defaultValue
end

function Server.getString(self: ServerClass, name: string, defaultValue: string?): string?
	local value = self:get(name, defaultValue)
	if type(value) == "string" then
		return value
	end
	return defaultValue
end

function Server.getAll(self: ServerClass): { [string]: FlagValue }
	return table.clone(self._flags)
end

function Server.setLocal(self: ServerClass, name: string, value: FlagValue, source: ChangeSource?)
	assertFlagName(name)
	local oldValue = self._flags[name]
	if oldValue == value then
		return
	end

	self._flags[name] = value
	fireChanged(self, name, value, oldValue, source or "local")
end

function Server.set(self: ServerClass, name: string, value: FlagValue): boolean
	self:setLocal(name, value, "local")

	return FlagChanged:Publish({
		Name = name,
		Value = value,
		SourceJobId = game.JobId,
	})
end

function Server.removeLocal(self: ServerClass, name: string, source: ChangeSource?)
	assertFlagName(name)
	local oldValue = self._flags[name]
	if oldValue == nil then
		return
	end

	self._flags[name] = nil
	fireChanged(self, name, nil, oldValue, source or "local")
end

function Server.remove(self: ServerClass, name: string): boolean
	self:removeLocal(name, "local")

	return FlagChanged:Publish({
		Name = name,
		Removed = true,
		SourceJobId = game.JobId,
	})
end

function Server.observe(self: ServerClass, name: string, handler: ChangeHandler): () -> ()
	assertFlagName(name)
	assert(type(handler) == "function", "[FFlags.Server] handler must be a function")

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

return Server :: ServerClass
