--!strict
--[=[
	@module Networking
	Shared typed networking. Packets are grouped into banks:
	  * `Event<Args>`            - reliable `RemoteEvent`
	  * `UnreliableEvent<Args>`  - `UnreliableRemoteEvent`
	  * `Request<Args, Return>`  - `RemoteFunction`

	Define a bank once in shared code and require it on both sides:

	```lua
	local Networking = require(ReplicatedStorage.Atlas).Networking
	local Bank = Networking.Bank("Player")

	export type UpdateFieldArgs = { Field: string, Value: any }

	return {
	    UpdateField = Bank:Event("UpdateField") :: Networking.Event<UpdateFieldArgs>,
	    GetSnapshot = Bank:Request("GetSnapshot") :: Networking.Request<nil, { [string]: any }>,
	    MoveHint    = Bank:UnreliableEvent("MoveHint") :: Networking.UnreliableEvent<Vector3>,
	}
	```

	Server:
	```lua
	local Net = require(ReplicatedStorage.Shared.Networks.PlayerNet)
	Net.UpdateField:OnServerEvent(function(player, args)
	end)
	Net.GetSnapshot:OnServerInvoke(function(player, _args)
	    return collectSnapshot(player)
	end)
	```

	Client:
	```lua
	local Net = require(ReplicatedStorage.Shared.Networks.PlayerNet)
	Net.UpdateField:FireServer({ Field = "currency", Value = 100 })
	local snap = Net.GetSnapshot:InvokeServer(nil)
	```

	Runtime Instance names are deterministic and obfuscated; code keeps using
	the logical bank and packet names. Server creates remotes lazily, and the
	client waits for them when the bank is required.
]=]

local Bank = require(script.Bank)
local Event = require(script.Event)
local UnreliableEvent = require(script.UnreliableEvent)
local Request = require(script.Request)
local Stats = require(script.Stats)

local Networking = {}

Networking.Bank = Bank.new
Networking.Stats = Stats

export type Bank = Bank.Bank
export type Event<Args> = Event.Event<Args>
export type UnreliableEvent<Args> = UnreliableEvent.UnreliableEvent<Args>
export type Request<Args, Return> = Request.Request<Args, Return>
export type NetworkStats = Stats.Snapshot
export type NetworkPacketStat = Stats.PacketStat

return Networking
