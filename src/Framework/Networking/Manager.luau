--!strict
--[=[
	@module Networking.Manager
	Owns the `ReplicatedStorage._FrameworkNetworking` root folder where
	every Bank parks its remotes. Server lazily creates folders /
	remotes; client `WaitForChild`s them.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Manager = {}

local ROOT_FOLDER_NAME = "_FrameworkNetworking"
local WAIT_TIMEOUT = 30

local function getOrCreate(parent: Instance, name: string, className: string): Instance
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing then
			assert(
				existing.ClassName == className,
				`[Framework.Networking] '{existing:GetFullName()}' exists with class '{existing.ClassName}', expected '{className}'`
			)
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = parent
		return instance
	end

	local existing = parent:WaitForChild(name, WAIT_TIMEOUT)
	assert(existing, `[Framework.Networking] '{parent:GetFullName()}.{name}' did not replicate within {WAIT_TIMEOUT}s`)
	assert(
		existing.ClassName == className,
		`[Framework.Networking] '{existing:GetFullName()}' exists with class '{existing.ClassName}', expected '{className}'`
	)
	return existing
end

function Manager.GetRoot(): Folder
	return getOrCreate(ReplicatedStorage, ROOT_FOLDER_NAME, "Folder") :: Folder
end

function Manager.GetBankFolder(bankName: string): Folder
	return getOrCreate(Manager.GetRoot(), bankName, "Folder") :: Folder
end

function Manager.GetRemoteEvent(bankFolder: Folder, name: string): RemoteEvent
	return getOrCreate(bankFolder, name, "RemoteEvent") :: RemoteEvent
end

function Manager.GetUnreliableRemoteEvent(bankFolder: Folder, name: string): UnreliableRemoteEvent
	return getOrCreate(bankFolder, name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

function Manager.GetRemoteFunction(bankFolder: Folder, name: string): RemoteFunction
	return getOrCreate(bankFolder, name, "RemoteFunction") :: RemoteFunction
end

return Manager
