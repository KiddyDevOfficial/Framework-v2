--!strict
--[=[
	@script Server
	Server entry point. Discovers every service under `script.Services`,
	registers any shared components under `ReplicatedStorage.Shared.Components`,
	then boots Atlas in dependency order.

	Drop a service module anywhere inside `script.Services` (any depth).
	Return a plain table with optional `Dependencies`; `Name` defaults to the
	`ModuleScript` name and the Loader registers it automatically.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))

local servicesFolder = script:FindFirstChild("Services")
if servicesFolder then
	Atlas.AddServices(servicesFolder)
end

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local componentsFolder = sharedFolder and sharedFolder:FindFirstChild("Components")
if componentsFolder then
	Atlas.AddComponents(componentsFolder)
end

Atlas.OnStart(function()
	print("[Atlas] Server started.")
end)

Atlas.Start()
