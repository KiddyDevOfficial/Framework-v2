--!strict
--[=[
	@module Networking.UnreliableEvent
	Unreliable typed packet (wraps `UnreliableRemoteEvent`). Same API
	shape as `Event<Args>`, but messages can drop or arrive out of order;
	use it for high-frequency low-stakes traffic - movement hints, particle
	bursts, that sort of thing.
]=]

local Players = game:GetService("Players")

local Manager = require(script.Parent.Manager)

local UnreliableEvent = {}
UnreliableEvent.__index = UnreliableEvent

export type UnreliableEvent<Args> = {
	Name: string,
	Bank: string,
	_remote: UnreliableRemoteEvent,
	FireServer: (self: UnreliableEvent<Args>, args: Args) -> (),
	FireClient: (self: UnreliableEvent<Args>, player: Player, args: Args) -> (),
	FireAllClients: (self: UnreliableEvent<Args>, args: Args) -> (),
	FireClients: (self: UnreliableEvent<Args>, players: { Player }, args: Args) -> (),
	FireAllClientsExcept: (self: UnreliableEvent<Args>, excluded: Player, args: Args) -> (),
	OnServerEvent: (
		self: UnreliableEvent<Args>,
		handler: (player: Player, args: Args) -> ()
	) -> RBXScriptConnection,
	OnClientEvent: (self: UnreliableEvent<Args>, handler: (args: Args) -> ()) -> RBXScriptConnection,
}

function UnreliableEvent.new<Args>(bankFolder: Folder, bankName: string, name: string): UnreliableEvent<Args>
	local self = setmetatable({
		Name = name,
		Bank = bankName,
		_remote = Manager.GetUnreliableRemoteEvent(bankFolder, name),
	}, UnreliableEvent)
	return self :: any
end

function UnreliableEvent.FireServer<Args>(self: UnreliableEvent<Args>, args: Args)
	self._remote:FireServer(args)
end

function UnreliableEvent.FireClient<Args>(self: UnreliableEvent<Args>, player: Player, args: Args)
	self._remote:FireClient(player, args)
end

function UnreliableEvent.FireAllClients<Args>(self: UnreliableEvent<Args>, args: Args)
	self._remote:FireAllClients(args)
end

function UnreliableEvent.FireClients<Args>(self: UnreliableEvent<Args>, players: { Player }, args: Args)
	for _, player in players do
		self._remote:FireClient(player, args)
	end
end

function UnreliableEvent.FireAllClientsExcept<Args>(self: UnreliableEvent<Args>, excluded: Player, args: Args)
	for _, player in Players:GetPlayers() do
		if player ~= excluded then
			self._remote:FireClient(player, args)
		end
	end
end

function UnreliableEvent.OnServerEvent<Args>(
	self: UnreliableEvent<Args>,
	handler: (player: Player, args: Args) -> ()
): RBXScriptConnection
	return self._remote.OnServerEvent:Connect(function(player: Player, args: any)
		handler(player, args :: Args)
	end)
end

function UnreliableEvent.OnClientEvent<Args>(
	self: UnreliableEvent<Args>,
	handler: (args: Args) -> ()
): RBXScriptConnection
	return self._remote.OnClientEvent:Connect(function(args: any)
		handler(args :: Args)
	end)
end

return UnreliableEvent
