--!strict
--[=[
	@module Networking.Stats
	Opt-in counters for the typed networking layer. Every `Event` /
	`UnreliableEvent` / `Request` reports each send and receive here, but only
	when stats are enabled - when they're off, `record` is a single boolean read
	and an early return, so the hot path stays cheap.

	Counts are **logical packet operations**, not bytes: one `FireServer` /
	`FireAllClients` / `InvokeServer` is one outgoing op, one handler invocation
	is one incoming op. Roblox gives no cheap per-packet byte size, so this
	tracks call volume - enough to spot a remote firing far too often.

	```lua
	local Stats = Framework.Networking.Stats

	Stats.setEnabled(true)
	-- ... play for a bit ...
	local snap = Stats.snapshot()
	print(snap.outgoing, snap.incoming)   -- totals since the last reset
	for key, packet in snap.perPacket do
	    print(key, packet.outgoing, packet.incoming)   -- "Bank.Packet"
	end
	Stats.reset()
	```
]=]

local Stats = {}

export type Direction = "out" | "in"

export type PacketStat = {
	outgoing: number,
	incoming: number,
}

export type Snapshot = {
	enabled: boolean,
	outgoing: number,
	incoming: number,
	perPacket: { [string]: PacketStat },
}

local enabled = false
local totalOut = 0
local totalIn = 0
local perPacket: { [string]: PacketStat } = {}

local function bucket(bank: string, name: string): PacketStat
	local key = `{bank}.{name}`
	local stat = perPacket[key]
	if not stat then
		stat = { outgoing = 0, incoming = 0 }
		perPacket[key] = stat
	end
	return stat
end

--[=[
	Records `count` (default 1) operations on `bank.name` in `direction`.
	No-ops instantly while stats are disabled.
]=]
function Stats.record(bank: string, name: string, direction: Direction, count: number?)
	if not enabled then
		return
	end
	local n = count or 1
	if direction == "out" then
		totalOut += n
		bucket(bank, name).outgoing += n
	else
		totalIn += n
		bucket(bank, name).incoming += n
	end
end

function Stats.setEnabled(value: boolean)
	enabled = value
end

function Stats.isEnabled(): boolean
	return enabled
end

--[=[
	Cloned point-in-time copy of the counters. Safe to read / iterate without
	racing later mutations.
]=]
function Stats.snapshot(): Snapshot
	local packets: { [string]: PacketStat } = {}
	for key, stat in perPacket do
		packets[key] = { outgoing = stat.outgoing, incoming = stat.incoming }
	end
	return {
		enabled = enabled,
		outgoing = totalOut,
		incoming = totalIn,
		perPacket = packets,
	}
end

--[=[
	Zeroes every counter. Call it on an interval to turn the running totals
	into a per-window rate (e.g. ops/sec).
]=]
function Stats.reset()
	totalOut = 0
	totalIn = 0
	table.clear(perPacket)
end

return Stats
