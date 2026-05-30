--!strict
--[=[
	@script Client
	Client entry point. Discovers controllers under `script.Controllers`
	(and, if present, `script.UI/Controllers` + `script.UI/Frames`),
	registers shared components, then boots the framework.

	Layout:
	  Controllers/     - game-logic controllers
	  UI/Controllers/  - UI system controllers (optional)
	  UI/Frames/       - per-frame GUI modules (optional)
	  UI/Lib/          - helpers, not auto-registered (optional)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local controllersFolder = script:FindFirstChild("Controllers")
if controllersFolder then
	Framework.AddControllers(controllersFolder)
end

local uiFolder = script:FindFirstChild("UI")
if uiFolder then
	local uiControllers = uiFolder:FindFirstChild("Controllers")
	if uiControllers then
		Framework.AddControllers(uiControllers)
	end

	local uiFrames = uiFolder:FindFirstChild("Frames")
	if uiFrames then
		Framework.AddControllers(uiFrames)
	end
end

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local componentsFolder = sharedFolder and sharedFolder:FindFirstChild("Components")
if componentsFolder then
	Framework.AddComponents(componentsFolder)
end

Framework.OnStart(function()
	print("[Framework] Client started.")
end)

Framework.Start()
