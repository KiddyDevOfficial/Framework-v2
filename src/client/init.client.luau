--!strict
--[=[
	@script Client
	Client entry point. Discovers controllers under `script.Controllers`
	(and, if present, `script.UI/Controllers` + `script.UI/Frames`),
	registers shared components, then boots Weave.

	Layout:
	  Controllers/     - game-logic controllers (e.g. ExampleController)
	  UI/Controllers/  - FrameController, GuiButtonController
	  UI/Frames/       - ExampleFrame, ...
	  UI/Lib/          - FrameStyles, FrameUtil (not auto-registered)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))

local controllersFolder = script:FindFirstChild("Controllers")
if controllersFolder then
	Weave.AddControllers(controllersFolder)
end

local uiFolder = script:FindFirstChild("UI")
if uiFolder then
	local uiControllers = uiFolder:FindFirstChild("Controllers")
	if uiControllers then
		Weave.AddControllers(uiControllers)
	end

	local uiFrames = uiFolder:FindFirstChild("Frames")
	if uiFrames then
		Weave.AddControllers(uiFrames)
	end
end

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local componentsFolder = sharedFolder and sharedFolder:FindFirstChild("Components")
if componentsFolder then
	Weave.AddComponents(componentsFolder)
end

Weave.OnStart(function()
	print("[Weave] Client started.")
end)

Weave.Start()
