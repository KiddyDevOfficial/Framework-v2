--!strict
--[=[
	@module Networking.Request
	Request/response typed packet (wraps `RemoteFunction`). Generic in
	`Args` (sent on invoke) and `Return` (handler result). `OnServerInvoke`
	and `OnClientInvoke` are callback properties; one handler per side at a
	time, same as the native `RemoteFunction`.
]=]

local Manager = require(script.Parent.Manager)

local Request = {}
Request.__index = Request

export type Request<Args, Return> = {
	Name: string,
	Bank: string,
	_remote: RemoteFunction,
	InvokeServer: (self: Request<Args, Return>, args: Args) -> Return,
	InvokeClient: (self: Request<Args, Return>, player: Player, args: Args) -> Return,
	OnServerInvoke: (self: Request<Args, Return>, handler: (player: Player, args: Args) -> Return) -> (),
	OnClientInvoke: (self: Request<Args, Return>, handler: (args: Args) -> Return) -> (),
}

function Request.new<Args, Return>(bankFolder: Folder, bankName: string, name: string): Request<Args, Return>
	local self = setmetatable({
		Name = name,
		Bank = bankName,
		_remote = Manager.GetRemoteFunction(bankFolder, name),
	}, Request)
	return self :: any
end

function Request.InvokeServer<Args, Return>(self: Request<Args, Return>, args: Args): Return
	return self._remote:InvokeServer(args) :: Return
end

function Request.InvokeClient<Args, Return>(self: Request<Args, Return>, player: Player, args: Args): Return
	return self._remote:InvokeClient(player, args) :: Return
end

function Request.OnServerInvoke<Args, Return>(
	self: Request<Args, Return>,
	handler: (player: Player, args: Args) -> Return
)
	self._remote.OnServerInvoke = function(player: Player, args: any)
		return handler(player, args :: Args)
	end
end

function Request.OnClientInvoke<Args, Return>(self: Request<Args, Return>, handler: (args: Args) -> Return)
	self._remote.OnClientInvoke = function(args: any)
		return handler(args :: Args)
	end
end

return Request
