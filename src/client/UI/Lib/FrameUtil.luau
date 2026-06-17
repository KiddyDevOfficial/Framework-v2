--!strict
--[=[
	Shared helpers for frame interaction controllers under `UI/Frames`.

	Optional button attributes:
	  - `FrameTarget` (string) - frame name under `PlayerGui/Frames`
	  - `FrameAction` (string) - `Open`, `Close`, or `Toggle` (default)

	You can also pass buttons directly to `wireOpen`, `wireClose`, or
	`wireToggle`.
]=]

local FrameUtil = {}

export type FrameApi = {
	Open: (self: FrameApi, name: string) -> (),
	Close: (self: FrameApi, name: string) -> (),
	Toggle: (self: FrameApi, name: string) -> (),
}

local FRAME_TARGET_ATTR = "FrameTarget"
local FRAME_ACTION_ATTR = "FrameAction"

function FrameUtil.getFramesRoot(playerGui: PlayerGui): Instance
	return playerGui:WaitForChild("Frames")
end

function FrameUtil.getFrame(playerGui: PlayerGui, frameName: string): GuiObject
	return FrameUtil.getFramesRoot(playerGui):WaitForChild(frameName) :: GuiObject
end

local function runAction(frames: FrameApi, frameName: string, action: string)
	if action == "Open" then
		frames:Open(frameName)
	elseif action == "Close" then
		frames:Close(frameName)
	else
		frames:Toggle(frameName)
	end
end

function FrameUtil.wireButton(
	button: GuiButton,
	frames: FrameApi,
	frameName: string,
	action: "Open" | "Close" | "Toggle"
): RBXScriptConnection
	return button.Activated:Connect(function()
		runAction(frames, frameName, action)
	end)
end

local function wireButtons(
	frames: FrameApi,
	frameName: string,
	action: "Open" | "Close" | "Toggle",
	...: GuiButton
): { RBXScriptConnection }
	local out: { RBXScriptConnection } = {}
	for i = 1, select("#", ...) do
		local button = select(i, ...)
		table.insert(out, FrameUtil.wireButton(button, frames, frameName, action))
	end
	return out
end

function FrameUtil.wireOpen(frames: FrameApi, frameName: string, ...: GuiButton): { RBXScriptConnection }
	return wireButtons(frames, frameName, "Open", ...)
end

function FrameUtil.wireClose(frames: FrameApi, frameName: string, ...: GuiButton): { RBXScriptConnection }
	return wireButtons(frames, frameName, "Close", ...)
end

function FrameUtil.wireToggle(frames: FrameApi, frameName: string, ...: GuiButton): { RBXScriptConnection }
	return wireButtons(frames, frameName, "Toggle", ...)
end

--[=[
	Wires every `GuiButton` under `root` that has a `FrameTarget` attribute.
	Use `filterFrameName` to bind one frame's controls.
]=]
function FrameUtil.wireAttributed(
	root: Instance,
	frames: FrameApi,
	filterFrameName: string?
): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}

	local function bind(instance: Instance)
		if not instance:IsA("GuiButton") then
			return
		end
		local target = instance:GetAttribute(FRAME_TARGET_ATTR)
		if type(target) ~= "string" or target == "" then
			return
		end
		if filterFrameName and target ~= filterFrameName then
			return
		end
		table.insert(
			connections,
			instance.Activated:Connect(function()
				local rawAction = instance:GetAttribute(FRAME_ACTION_ATTR)
				local action = if type(rawAction) == "string" then rawAction else "Toggle"
				runAction(frames, target, action)
			end)
		)
	end

	for _, descendant in root:GetDescendants() do
		bind(descendant)
	end

	table.insert(connections, root.DescendantAdded:Connect(bind))

	return connections
end

return FrameUtil
