--!strict
--[=[
	@module Networking.Event
	Reliable typed packet (wraps a `RemoteEvent`). Methods are generic
	in `Args`; declare the bank's packet as `Networking.Event<MyArgsType>`
	and you get autocomplete and type checks on every `:FireServer`,
	`:OnServerEvent`, and so on.
]=]

local Players = game:GetService("Players")

local Manager = require(script.Parent.Manager)

local Event = {}
Event.__index = Event

export type Event<Args> = {
	Name: string,
	Bank: string,
	_remote: RemoteEvent,
	FireServer: (self: Event<Args>, args: Args) -> (),
	FireClient: (self: Event<Args>, player: Player, args: Args) -> (),
	FireAllClients: (self: Event<Args>, args: Args) -> (),
	FireClients: (self: Event<Args>, players: { Player }, args: Args) -> (),
	FireAllClientsExcept: (self: Event<Args>, excluded: Player, args: Args) -> (),
	OnServerEvent: (self: Event<Args>, handler: (player: Player, args: Args) -> ()) -> RBXScriptConnection,
	OnClientEvent: (self: Event<Args>, handler: (args: Args) -> ()) -> RBXScriptConnection,
}

function Event.new<Args>(bankFolder: Folder, bankName: string, name: string): Event<Args>
	local self = setmetatable({
		Name = name,
		Bank = bankName,
		_remote = Manager.GetRemoteEvent(bankFolder, name),
	}, Event)
	return self :: any
end

function Event.FireServer<Args>(self: Event<Args>, args: Args)
	self._remote:FireServer(args)
end

function Event.FireClient<Args>(self: Event<Args>, player: Player, args: Args)
	self._remote:FireClient(player, args)
end

function Event.FireAllClients<Args>(self: Event<Args>, args: Args)
	self._remote:FireAllClients(args)
end

function Event.FireClients<Args>(self: Event<Args>, players: { Player }, args: Args)
	for _, player in players do
		self._remote:FireClient(player, args)
	end
end

function Event.FireAllClientsExcept<Args>(self: Event<Args>, excluded: Player, args: Args)
	for _, player in Players:GetPlayers() do
		if player ~= excluded then
			self._remote:FireClient(player, args)
		end
	end
end

function Event.OnServerEvent<Args>(
	self: Event<Args>,
	handler: (player: Player, args: Args) -> ()
): RBXScriptConnection
	return self._remote.OnServerEvent:Connect(function(player: Player, args: any)
		handler(player, args :: Args)
	end)
end

function Event.OnClientEvent<Args>(self: Event<Args>, handler: (args: Args) -> ()): RBXScriptConnection
	return self._remote.OnClientEvent:Connect(function(args: any)
		handler(args :: Args)
	end)
end

return Event
