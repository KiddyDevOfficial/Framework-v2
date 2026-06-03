--!strict
--[=[
	@module Adapters.Leaderstats
	Framework service binding for DataService-driven leaderstats.
]=]

local RunService = game:GetService("RunService")

local Service = require(script.Parent.Parent.Modular.Service)
local LeaderstatsPackage = require(script.Parent.Parent.Leaderstats)
local LeaderstatsTypes = require(script.Parent.Parent.Leaderstats.Types)

local LeaderstatsAdapter = {}

export type ServerOptions = {
	Name: string?,
	Dependencies: { string }?,
	Entries: { LeaderstatsTypes.Entry },
	DataService: LeaderstatsTypes.DataServiceLike,
	FolderName: string?,
}

export type ServiceClass = {
	Server: (self: ServiceClass) -> LeaderstatsTypes.ServerClass,
	MountPlayer: (self: ServiceClass, player: Player) -> (),
	UnmountPlayer: (self: ServiceClass, player: Player) -> (),
}

function LeaderstatsAdapter.CreateService(options: ServerOptions): ServiceClass
	assert(type(options.Entries) == "table", "Framework.CreateLeaderstatsService: Entries table is required")
	assert(options.DataService ~= nil, "Framework.CreateLeaderstatsService: DataService is required")

	local name = options.Name or "LeaderstatsService"
	local dependencies = options.Dependencies or { "DataService" }

	local def: any = Service.Create({
		Name = name,
		Dependencies = dependencies,
	})

	function def:Init()
		if not RunService:IsServer() then
			return
		end

		local server = LeaderstatsPackage.server
		server:init({
			Entries = options.Entries,
			DataService = options.DataService,
			FolderName = options.FolderName,
		})
		self._server = server
	end

	function def:Stop()
		if self._server then
			self._server:destroy()
			self._server = nil
		end
	end

	function def:Server(): LeaderstatsTypes.ServerClass
		return self._server
	end

	function def:MountPlayer(player: Player)
		return self._server:mountPlayer(player)
	end

	function def:UnmountPlayer(player: Player)
		return self._server:unmountPlayer(player)
	end

	return def :: ServiceClass
end

return LeaderstatsAdapter
