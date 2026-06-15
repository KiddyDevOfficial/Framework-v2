--!strict
--[=[
	@module GlobalMessaging.Manager
	Turns bank/event names into MessagingService topic strings and holds
	the experience-wide topic prefix (set by `Server.init`).
]=]

local Manager = {}

local MAX_TOPIC_LENGTH = 80

local _globalPrefix: string? = nil

local function defaultPrefix(): string
	return `G_{game.GameId}_`
end

function Manager.setGlobalPrefix(prefix: string)
	assert(type(prefix) == "string", "[Framework.GlobalMessaging] TopicPrefix must be a string")
	_globalPrefix = prefix
end

function Manager.getGlobalPrefix(): string
	return _globalPrefix or defaultPrefix()
end

function Manager.clearGlobalPrefix()
	_globalPrefix = nil
end

function Manager.buildRelativeTopic(bankName: string, eventName: string): string
	assert(type(bankName) == "string" and #bankName > 0, "[Framework.GlobalMessaging] bank name must be non-empty")
	assert(type(eventName) == "string" and #eventName > 0, "[Framework.GlobalMessaging] event name must be non-empty")
	return `{bankName}_{eventName}`
end

function Manager.resolveTopic(bankName: string, eventName: string): string
	local relative = Manager.buildRelativeTopic(bankName, eventName)
	local full = Manager.getGlobalPrefix() .. relative
	assert(
		#full <= MAX_TOPIC_LENGTH,
		`[Framework.GlobalMessaging] topic '{full}' exceeds {MAX_TOPIC_LENGTH} characters — shorten bank/event names or TopicPrefix`
	)
	return full
end

return Manager
