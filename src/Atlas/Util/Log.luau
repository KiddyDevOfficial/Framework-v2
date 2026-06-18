--!strict
--[=[
	@module Util.Log
	Leveled, tagged logging. Create one logger per system, then turn verbosity
	up globally, per tag, or per logger when needed.

	```lua
	local Log = Atlas.Log

	local log = Log.new("Combat")
	log:info("hit", target.Name, "for", damage)
	log:debug("internal state", state)

	Log.setLevel(Log.Level.Debug)
	Log.setTagLevel("Combat", Log.Level.Trace)
	```

	## FFlag-gated verbosity

	`Log` only needs something with `observe(name, handler)`, so either side of
	`Atlas.FFlags` can drive the global level:

	```lua
	-- server: Log.useFFlag(Atlas.FFlags.server, "LogLevel")
	-- client: Log.useFFlag(Atlas.FFlags.client, "LogLevel")
	local unbind = Log.useFFlag(Atlas.FFlags.client, "LogLevel")
	```
]=]

local Log = {}

export type Level = number

Log.Level = {
	Trace = 10,
	Debug = 20,
	Info = 30,
	Warn = 40,
	Error = 50,
	None = 100,
} :: { [string]: Level }

local LEVEL_NAME: { [Level]: string } = {
	[10] = "TRACE",
	[20] = "DEBUG",
	[30] = "INFO",
	[40] = "WARN",
	[50] = "ERROR",
}

export type Sink = (level: Level, levelName: string, tag: string, args: { any }) -> ()

export type Logger = {
	tag: string,
	trace: (self: Logger, ...any) -> (),
	debug: (self: Logger, ...any) -> (),
	info: (self: Logger, ...any) -> (),
	warn: (self: Logger, ...any) -> (),
	error: (self: Logger, ...any) -> (),
	log: (self: Logger, level: Level, ...any) -> (),
	isEnabled: (self: Logger, level: Level) -> boolean,
	setLevel: (self: Logger, level: Level?) -> (),
}

local Logger = {}
Logger.__index = Logger

local globalLevel: Level = Log.Level.Info
local tagLevels: { [string]: Level? } = {}
local sink: Sink? = nil

--[=[
	Sets the global minimum level.
]=]
function Log.setLevel(level: Level)
	globalLevel = level
end

function Log.getLevel(): Level
	return globalLevel
end

--[=[
	Sets or clears a per-tag minimum level.
]=]
function Log.setTagLevel(tag: string, level: Level?)
	tagLevels[tag] = level
end

--[=[
	Redirects emitted logs through `fn`; pass `nil` to restore console output.
]=]
function Log.setSink(fn: Sink?)
	sink = fn
end

--[=[
	Resolves a flag value (`"debug"`, `20`, etc.) to a log level.
]=]
function Log.levelFromValue(value: any): Level
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		local key = value:sub(1, 1):upper() .. value:sub(2):lower()
		local level = Log.Level[key]
		if level then
			return level
		end
	end
	return Log.Level.Info
end

--[=[
	Binds the global level to an FFlag and returns the unsubscribe function.
]=]
function Log.useFFlag(fflags: { observe: (any, string, (...any) -> ()) -> () -> () }, flagName: string): () -> ()
	return fflags:observe(flagName, function(value: any)
		Log.setLevel(Log.levelFromValue(value))
	end)
end

local function levelFor(tag: string): Level
	local override = tagLevels[tag]
	if override ~= nil then
		return override
	end
	return globalLevel
end

--[=[
	New logger tagged `tag`. `level` gives it a private minimum.
]=]
function Log.new(tag: string, level: Level?): Logger
	assert(type(tag) == "string" and #tag > 0, "[Log] tag must be a non-empty string")
	local self = setmetatable({
		tag = tag,
		_level = level,
	}, Logger)
	return self :: any
end

function Logger.setLevel(self: Logger, level: Level?)
	(self :: any)._level = level
end

function Logger.isEnabled(self: Logger, level: Level): boolean
	local s: any = self
	local minimum = if s._level ~= nil then s._level else levelFor(s.tag)
	return level >= minimum
end

function Logger.log(self: Logger, level: Level, ...: any)
	if not self:isEnabled(level) then
		return
	end
	local s: any = self
	local name = LEVEL_NAME[level] or tostring(level)
	if sink then
		sink(level, name, s.tag, table.pack(...))
		return
	end
	local prefix = `[{name}][{s.tag}]`
	if level >= Log.Level.Warn then
		warn(prefix, ...)
	else
		print(prefix, ...)
	end
end

function Logger.trace(self: Logger, ...: any)
	self:log(Log.Level.Trace, ...)
end

function Logger.debug(self: Logger, ...: any)
	self:log(Log.Level.Debug, ...)
end

function Logger.info(self: Logger, ...: any)
	self:log(Log.Level.Info, ...)
end

function Logger.warn(self: Logger, ...: any)
	self:log(Log.Level.Warn, ...)
end

function Logger.error(self: Logger, ...: any)
	self:log(Log.Level.Error, ...)
end

return Log
