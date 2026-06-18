--!strict
--[=[
	@module Networking.Stats
	Opt-in counters for typed networking. Events and requests report sends and
	receives here only while stats are enabled, keeping the normal path cheap.

	Counts are **logical packet operations**, not bytes: one `FireServer` /
	`FireAllClients` / `InvokeServer` is one outgoing op, one handler invocation
	is one incoming op. Roblox gives no cheap per-packet byte size, so this
	tracks call volume - enough to spot a remote firing far too often.

	```lua
	local Stats = Weave.Networking.Stats

	Stats.setEnabled(true)
	local snap = Stats.snapshot()
	print(snap.outgoing, snap.incoming)
	for key, packet in snap.perPacket do
	    print(key, packet.outgoing, packet.incoming)
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
	Records packet operations. No-ops while stats are disabled.
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
	Cloned point-in-time copy of the counters.
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
	Zeroes every counter; useful for per-window rates.
]=]
function Stats.reset()
	totalOut = 0
	totalIn = 0
	table.clear(perPacket)
end

return Stats
