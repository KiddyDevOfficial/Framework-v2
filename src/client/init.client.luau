--!strict
--[=[
	@script Client
	Client entry point. Discovers controllers under `script.Controllers`
	(and, if present, `script.UI/Controllers` + `script.UI/Frames`),
	registers shared components, then boots Atlas.

	Layout:
	  Controllers/     - game-logic controllers (e.g. ExampleController)
	  UI/Controllers/  - FrameController, GuiButtonController
	  UI/Frames/       - ExampleFrame, ...
	  UI/Lib/          - FrameStyles, FrameUtil (not auto-registered)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atlas = require(ReplicatedStorage:WaitForChild("Atlas"))

local controllersFolder = script:FindFirstChild("Controllers")
if controllersFolder then
	Atlas.AddControllers(controllersFolder)
end

local uiFolder = script:FindFirstChild("UI")
if uiFolder then
	local uiControllers = uiFolder:FindFirstChild("Controllers")
	if uiControllers then
		Atlas.AddControllers(uiControllers)
	end

	local uiFrames = uiFolder:FindFirstChild("Frames")
	if uiFrames then
		Atlas.AddControllers(uiFrames)
	end
end

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local componentsFolder = sharedFolder and sharedFolder:FindFirstChild("Components")
if componentsFolder then
	Atlas.AddComponents(componentsFolder)
end

Atlas.OnStart(function()
	print("[Atlas] Client started.")
end)

Atlas.Start()
