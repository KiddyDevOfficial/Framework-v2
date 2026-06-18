--!strict
--[=[
	@module ExampleNet
	Starter shared Bank - one place defines the remotes, both sides require
	this module to get the fully-typed handles. Delete or copy this file to
	start your own banks.

	```lua
	local Net = require(ReplicatedStorage.Shared.Networks.ExampleNet)
	-- server: Net.Ping:OnServerEvent(function(player, msg) ... end)
	-- client: Net.Ping:FireServer("hello")
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local Networking = Weave.Networking

local Bank = Networking.Bank("Example")

export type EchoResponse = {
	Message: string,
	ServerTime: number,
}

return {
	--Ping = Bank:Event("Ping") :: Weave.NetworkEvent<string>,
	--Echo = Bank:Request("Echo") :: Weave.NetworkRequest<string, EchoResponse>,
}
