--!strict
--[=[
	@module Util.StringUtil
	Text helpers missing from Roblox's base `string` library.
]=]

local StringUtil = {}

function StringUtil.trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function StringUtil.trimStart(s: string): string
	return (s:gsub("^%s+", ""))
end

function StringUtil.trimEnd(s: string): string
	return (s:gsub("%s+$", ""))
end

function StringUtil.startsWith(s: string, prefix: string): boolean
	return string.sub(s, 1, #prefix) == prefix
end

function StringUtil.endsWith(s: string, suffix: string): boolean
	return suffix == "" or string.sub(s, -#suffix) == suffix
end

function StringUtil.contains(s: string, substr: string): boolean
	return string.find(s, substr, 1, true) ~= nil
end

--[=[
	Splits `s` on the literal `separator` (default `","`). Empty segments are
	kept.
]=]
function StringUtil.split(s: string, separator: string?): { string }
	local sep = separator or ","
	if sep == "" then
		local out: { string } = {}
		for i = 1, #s do
			table.insert(out, string.sub(s, i, i))
		end
		return out
	end

	local parts: { string } = {}
	local from = 1
	while true do
		local i, j = string.find(s, sep, from, true)
		if not i then
			break
		end
		table.insert(parts, string.sub(s, from, i - 1))
		from = j + 1
	end
	table.insert(parts, string.sub(s, from))
	return parts
end

function StringUtil.lpad(s: string, width: number, char: string?): string
	local c = char or " "
	local pad = width - #s
	if pad <= 0 then
		return s
	end
	return string.rep(c, pad) .. s
end

function StringUtil.rpad(s: string, width: number, char: string?): string
	local c = char or " "
	local pad = width - #s
	if pad <= 0 then
		return s
	end
	return s .. string.rep(c, pad)
end

--[=[
	Formats a number with thousands separators.
]=]
function StringUtil.formatNumber(n: number, separator: string?): string
	local sep = separator or ","
	local sign = if n < 0 then "-" else ""
	local abs = math.abs(n)
	local intPart, decPart = string.match(tostring(abs), "^(%d+)(%.?%d*)$")
	if not intPart then
		return tostring(n)
	end

	local reversed = string.reverse(intPart)
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1" .. sep)
	local result = string.reverse(grouped)
	if string.sub(result, 1, #sep) == sep then
		result = string.sub(result, #sep + 1)
	end
	return sign .. result .. (decPart or "")
end

--[=[
	Formats seconds as compact `h m s` text.
]=]
function StringUtil.formatDuration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60

	if h > 0 then
		return `{h}h {m}m {sec}s`
	elseif m > 0 then
		return `{m}m {sec}s`
	end
	return `{sec}s`
end

function StringUtil.capitalize(s: string): string
	if s == "" then
		return s
	end
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

function StringUtil.toCamelCase(s: string): string
	local out = string.gsub(s, "[_%- ]+(%w)", function(c)
		return string.upper(c)
	end)
	return string.lower(string.sub(out, 1, 1)) .. string.sub(out, 2)
end

function StringUtil.toSnakeCase(s: string): string
	local out = string.gsub(s, "(%l)(%u)", "%1_%2")
	out = string.gsub(out, "[ %-]", "_")
	return string.lower(out)
end

return StringUtil
