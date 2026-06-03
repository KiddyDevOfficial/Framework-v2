--!strict
--[=[
	@module GlobalMessaging.Server
	Server singleton for [MessagingService] subscribe / publish.
	https://create.roblox.com/docs/reference/engine/classes/MessagingService

	Low-level API uses relative topic keys (`BankName_EventName`). Prefer
	typed banks via `GlobalMessaging.Bank` in shared modules.
]=]

local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local Manager = require(script.Parent.Manager)
local Types = require(script.Parent.Types)

if RunService:IsClient() then
	return {} :: Types.ServerClass
end

type ServerClass = Types.ServerClass
type Message = Types.Message
type MessageHandler = Types.MessageHandler
type InitOptions = Types.InitOptions

local Server = {
	_initialized = false,
	_connections = {} :: { [string]: RBXScriptConnection },
}

local function warnOnce(message: string)
	warn("[GlobalMessaging.Server] " .. message)
end

local function normalizeTopic(topic: string): string
	local trimmed = string.gsub(topic, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

function Server.resolveTopic(_self: ServerClass, topic: string): string
	local normalized = normalizeTopic(topic)
	assert(#normalized > 0, "[GlobalMessaging.Server] topic must be non-empty")
	local full = Manager.getGlobalPrefix() .. normalized
	assert(
		#full <= 80,
		`[GlobalMessaging.Server] topic '{full}' exceeds 80 characters (prefix + topic)`
	)
	return full
end

function Server.init(self: ServerClass, options: InitOptions?)
	if self._initialized then
		return
	end
	self._initialized = true

	local prefix = if options then options.TopicPrefix else nil
	Manager.setGlobalPrefix(if prefix ~= nil then prefix else `G_{game.GameId}_`)
end

function Server.isSubscribed(self: ServerClass, topic: string): boolean
	local fullTopic = self:resolveTopic(topic)
	return self._connections[fullTopic] ~= nil
end

function Server.subscribe(self: ServerClass, topic: string, handler: MessageHandler): () -> ()
	assert(type(handler) == "function", "[GlobalMessaging.Server] handler must be a function")

	local fullTopic = self:resolveTopic(topic)

	if self._connections[fullTopic] then
		self:unsubscribe(topic)
	end

	local ok, connection = pcall(function()
		return MessagingService:SubscribeAsync(fullTopic, function(incoming: { Data: any, Sent: number })
			local message: Message = {
				Data = incoming.Data,
				Sent = incoming.Sent,
			}
			local handlerOk, err = pcall(handler, message)
			if not handlerOk then
				warnOnce(`handler for topic '{topic}' errored: {err}`)
			end
		end)
	end)

	if not ok then
		warnOnce(`SubscribeAsync failed for '{fullTopic}': {connection}`)
		return function() end
	end

	self._connections[fullTopic] = connection

	return function()
		self:unsubscribe(topic)
	end
end

function Server.unsubscribe(self: ServerClass, topic: string)
	local fullTopic = self:resolveTopic(topic)
	local connection = self._connections[fullTopic]
	if not connection then
		return
	end
	connection:Disconnect()
	self._connections[fullTopic] = nil
end

function Server.publish(self: ServerClass, topic: string, data: any): boolean
	local fullTopic = self:resolveTopic(topic)

	local ok, err = pcall(function()
		MessagingService:PublishAsync(fullTopic, data)
	end)
	if not ok then
		warnOnce(`PublishAsync failed for '{fullTopic}': {err}`)
		return false
	end
	return true
end

function Server.destroy(self: ServerClass)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	Manager.clearGlobalPrefix()
	self._initialized = false
end

return Server :: ServerClass
