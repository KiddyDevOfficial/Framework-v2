--!strict
--[=[
	@script Server
	Server entry point. Discovers every service under `script.Services`,
	registers any shared components under `ReplicatedStorage.Shared.Components`,
	then boots Weave in dependency order.

	Drop a service module anywhere inside `script.Services` (any depth).
	Return a plain table with optional `Dependencies`; `Name` defaults to the
	`ModuleScript` name and the Loader registers it automatically.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))

local servicesFolder = script:FindFirstChild("Services")
if servicesFolder then
	Weave.AddServices(servicesFolder)
end

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local componentsFolder = sharedFolder and sharedFolder:FindFirstChild("Components")
if componentsFolder then
	Weave.AddComponents(componentsFolder)
end

Weave.OnStart(function()
	print("[Weave] Server started.")
end)

Weave.Start()
