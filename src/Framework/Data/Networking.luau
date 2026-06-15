--!strict
--[=[
	@module Data.Networking
	Tiny RemoteEvent / RemoteFunction broker for the framework DataService.

	The server drops a `Folder` (`_FrameworkDataService`) under
	`ReplicatedStorage` holding:

	  * `Replicate` - `RemoteEvent`, server -> client snapshot + mutation
	    actions (see `Data.Utils.Action`).
	  * `Fetch`     - `RemoteFunction`, client -> server pull (used by
	    `Client:fetch(path)`).

	Both sides look the instances up by name; the client uses `WaitForChild`
	so it's safe to call before the server has finished setting things up.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Networking = {}


local FOLDER_NAME = "_FrameworkDataService"
local EVENT_NAME = "Replicate"
local FUNCTION_NAME = "Fetch"

local function ensureChild<T>(parent: Instance, name: string, className: string): T
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created :: any
end

--[=[
	Builds the network plumbing. Server only.
	Returns `(replicateEvent, fetchFunction)`.
]=]
function Networking.buildServer(): (RemoteEvent, RemoteFunction)
	assert(RunService:IsServer(), "Networking.buildServer can only run on the server")

	local folder = ensureChild(ReplicatedStorage, FOLDER_NAME, "Folder") :: Folder
	local event = ensureChild(folder, EVENT_NAME, "RemoteEvent") :: RemoteEvent
	local fn = ensureChild(folder, FUNCTION_NAME, "RemoteFunction") :: RemoteFunction
	return event, fn
end

--[=[
	Resolves the plumbing on the client; yields until it's there.
	Returns `(replicateEvent, fetchFunction)`.
]=]
function Networking.buildClient(): (RemoteEvent, RemoteFunction)
	assert(RunService:IsClient(), "Networking.buildClient can only run on the client")

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	local event = folder:WaitForChild(EVENT_NAME) :: RemoteEvent
	local fn = folder:WaitForChild(FUNCTION_NAME) :: RemoteFunction
	return event, fn
end

return Networking
