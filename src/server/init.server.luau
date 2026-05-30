--!strict
--[=[
	@script Server
	Server entry point. Discovers every service under `script.Services`,
	registers any shared components under `ReplicatedStorage.Shared.Components`,
	then boots the framework in dependency order.

	Drop a service module anywhere inside `script.Services` (any depth).
	Return a plain table with optional `Dependencies`; `Name` defaults to the
	`ModuleScript` name and the Loader registers it automatically.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local servicesFolder = script:FindFirstChild("Services")
if servicesFolder then
	Framework.AddServices(servicesFolder)
end

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local componentsFolder = sharedFolder and sharedFolder:FindFirstChild("Components")
if componentsFolder then
	Framework.AddComponents(componentsFolder)
end

Framework.OnStart(function()
	print("[Framework] Server started.")
end)

Framework.Start()
