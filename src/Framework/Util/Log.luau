--!strict
--[=[
	@module Util.Log
	Leveled, tagged logging. Make one logger per system, give it a tag, and
	call `:info` / `:debug` / ... - output is prefixed `[LEVEL][Tag]` and routed
	through `print` (trace/debug/info) or `warn` (warn/error). A global minimum
	level (with optional per-tag overrides) decides what actually prints, so you
	can leave `debug` calls in the code and turn them on only when you need them.

	```lua
	local Log = Framework.Log

	local log = Log.new("Combat")
	log:info("hit", target.Name, "for", damage)   -- [INFO][Combat] hit Rig for 12
	log:debug("internal state", state)              -- hidden unless level <= Debug

	Log.setLevel(Log.Level.Debug)                   -- globally show debug and up
	Log.setTagLevel("Combat", Log.Level.Trace)      -- but trace just for Combat
	```

	## FFlag-gated verbosity

	`Log` never hard-depends on `FFlags`; it only needs something with an
	`observe(name, handler)` method. Pass either side of `Framework.FFlags` and
	the global level tracks the flag live:

	```lua
	-- server: Log.useFFlag(Framework.FFlags.server, "LogLevel")
	-- client: Log.useFFlag(Framework.FFlags.client, "LogLevel")
	-- flag value may be a level name ("debug") or a number (20).
	local unbind = Log.useFFlag(Framework.FFlags.client, "LogLevel")
	```
]=]

local Log = {}

export type Level = number

-- Ordered so a numeric compare decides visibility. `None` mutes everything.
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
	Sets the minimum level that prints across every logger without its own
	override.
]=]
function Log.setLevel(level: Level)
	globalLevel = level
end

function Log.getLevel(): Level
	return globalLevel
end

--[=[
	Per-tag minimum level. Pass `nil` to clear the override and fall back to
	the global level.
]=]
function Log.setTagLevel(tag: string, level: Level?)
	tagLevels[tag] = level
end

--[=[
	Redirects every emitted line through `fn` instead of `print` / `warn` -
	handy for piping logs into a debug overlay or a remote collector. Pass
	`nil` to restore the default console output.
]=]
function Log.setSink(fn: Sink?)
	sink = fn
end

--[=[
	Resolves an FFlag value to a level. Accepts a level name (`"debug"`,
	case-insensitive), a raw number, or falls back to `Info`.
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
	Binds the global level to an FFlag. `fflags` is anything exposing
	`observe(name, handler)` (both `Framework.FFlags.server` and `.client`
	qualify). Returns the unsubscribe function from `observe`.
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
	New logger tagged `tag`. Pass `level` to give it a private minimum that
	ignores the global / per-tag settings.
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
