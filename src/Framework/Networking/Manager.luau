--!strict
--[=[
	@module Networking.Manager
	Owns the ReplicatedStorage folder where every Bank parks its remotes.
	Runtime Instance names are deterministic obfuscations of the logical
	bank / packet names using the current server job id as a seed. Server
	lazily creates folders / remotes; client `WaitForChild`s them.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Manager = {}

local ROOT_FOLDER_NAME = "_FrameworkNetworking"
local WAIT_TIMEOUT = 30
local HASH_MOD = 2147483647
local HASH_A = 33
local HASH_B = 131
local HASH_PREFIX = "n"

local function seed(): string
	local jobId = game.JobId
	if jobId ~= "" then
		return jobId
	end
	return `{game.PlaceId}:{game.PrivateServerId}:studio`
end

local function hash(input: string, multiplier: number): number
	local value = multiplier
	for i = 1, #input do
		value = (value * multiplier + string.byte(input, i)) % HASH_MOD
	end
	return value
end

local function toBase36(value: number): string
	local alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
	if value == 0 then
		return "0"
	end

	local out = ""
	while value > 0 do
		local digit = (value % 36) + 1
		out = string.sub(alphabet, digit, digit) .. out
		value = math.floor(value / 36)
	end
	return out
end

local function obfuscate(kind: string, logicalName: string): string
	local input = `{seed()}|{kind}|{logicalName}`
	return `{HASH_PREFIX}{toBase36(hash(input, HASH_A))}{toBase36(hash(input, HASH_B))}`
end

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
	return getOrCreate(ReplicatedStorage, obfuscate("root", ROOT_FOLDER_NAME), "Folder") :: Folder
end

function Manager.GetBankFolder(bankName: string): Folder
	return getOrCreate(Manager.GetRoot(), obfuscate("bank", bankName), "Folder") :: Folder
end

function Manager.GetRemoteEvent(bankFolder: Folder, name: string): RemoteEvent
	return getOrCreate(bankFolder, obfuscate("event", name), "RemoteEvent") :: RemoteEvent
end

function Manager.GetUnreliableRemoteEvent(bankFolder: Folder, name: string): UnreliableRemoteEvent
	return getOrCreate(bankFolder, obfuscate("unreliableEvent", name), "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

function Manager.GetRemoteFunction(bankFolder: Folder, name: string): RemoteFunction
	return getOrCreate(bankFolder, obfuscate("request", name), "RemoteFunction") :: RemoteFunction
end

return Manager
