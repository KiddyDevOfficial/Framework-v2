--!strict
--[=[
	@module GlobalMessaging.Bank
	Groups typed cross-server topics, mirroring `Networking.Bank`.
	`GlobalMessaging.Bank("Example")` is idempotent — the same name always
	returns the same bank instance.
]=]

local Topic = require(script.Parent.Topic)

local Bank = {}
Bank.__index = Bank

export type Bank = {
	Name: string,
	_topics: { [string]: any },
	Event: <Args>(self: Bank, name: string) -> Topic.Topic<Args>,
}

local bankCache: { [string]: Bank } = {}

function Bank.new(name: string): Bank
	assert(type(name) == "string" and #name > 0, "[Framework.GlobalMessaging] Bank name must be a non-empty string")

	local cached = bankCache[name]
	if cached then
		return cached
	end

	local self = setmetatable({
		Name = name,
		_topics = {},
	}, Bank)
	bankCache[name] = self :: any
	return self :: any
end

function Bank.Event<Args>(self: Bank, name: string): Topic.Topic<Args>
	local existing = self._topics[name]
	if existing then
		return existing
	end
	local packet = Topic.new(self.Name, name)
	self._topics[name] = packet
	return packet :: Topic.Topic<Args>
end

return Bank
