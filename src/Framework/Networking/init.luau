--!strict
--[=[
	@module Networking
	Shared typed networking layer. Packets are grouped into **Banks**;
	each packet is one of:
	  * `Event<Args>`            - reliable `RemoteEvent`
	  * `UnreliableEvent<Args>`  - `UnreliableRemoteEvent`
	  * `Request<Args, Return>`  - `RemoteFunction`

	Define a bank once in a shared module, require it on both sides:

	```lua
	-- src/shared/Networks/PlayerNet.luau
	local Networking = require(ReplicatedStorage.Framework).Networking
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
	    -- args: { Field: string, Value: any }
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

	All remotes live under `ReplicatedStorage._FrameworkNetworking/<BankName>/`.
	Server lazily creates each remote; client `WaitForChild`s it the
	first time the bank is required, so order of require is safe.
]=]

local Bank = require(script.Bank)
local Event = require(script.Event)
local UnreliableEvent = require(script.UnreliableEvent)
local Request = require(script.Request)

local Networking = {}

Networking.Bank = Bank.new

export type Bank = Bank.Bank
export type Event<Args> = Event.Event<Args>
export type UnreliableEvent<Args> = UnreliableEvent.UnreliableEvent<Args>
export type Request<Args, Return> = Request.Request<Args, Return>

return Networking
