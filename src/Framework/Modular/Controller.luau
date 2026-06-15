--!strict
--[=[
	@module Controller
	Client-side singleton modules. Same as `Service`, except the loader only
	runs a controller's lifecycle when `RunService:IsClient()` is true.

	```lua
	-- src/client/Controllers/HudController.luau
	local HudController = {
	    Dependencies = { "InputController" },
	}

	function HudController:Init() end
	function HudController:Start() end
	function HudController:RenderStep(dt: number) end

	return HudController
	```

	`Name` falls back to the `ModuleScript` name when omitted. The Loader
	stamps and registers the table when it scans a `Controllers` folder, and
	`Framework.CreateController` is still there for manual registration.
]=]

local Symbol = require(script.Parent.Parent.Symbol)
local Lifecycle = require(script.Parent.Lifecycle)
type Hooks = Lifecycle.Hooks

local Controller = {}

local TAG_CONTROLLER = Symbol.unique("Modular.Controller")

export type Definition = {
	Name: string,
	Dependencies: { string }?,
	[any]: any,
}

export type ControllerDef = {
	Name: string,
	Dependencies: { string },
	__tag: typeof(TAG_CONTROLLER),
	[any]: any,
} & Hooks

--[=[
	Stamps `def` as a controller in place and returns it. Same shape as
	`Service.Create`; only the tag and the load-side guard differ.
]=]
function Controller.Create<T>(def: T & Definition): T
	local d: any = def
	assert(type(d) == "table", "Framework.CreateController: definition must be a table")
	assert(
		type(d.Name) == "string" and #d.Name > 0,
		"Framework.CreateController: definition.Name (non-empty string) is required"
	)
	assert(d.__tag == nil, `Framework.CreateController: '{d.Name}' is already a registered modular unit`)

	local deps = d.Dependencies
	if deps == nil then
		d.Dependencies = {}
	else
		assert(type(deps) == "table", `controller '{d.Name}': Dependencies must be a table of names`)
		for i, name in deps do
			assert(
				type(name) == "string" and #name > 0,
				`controller '{d.Name}': Dependencies[{i}] must be a non-empty string`
			)
		end
	end

	d.__tag = TAG_CONTROLLER
	return def
end

--[=[
	Stamps a plain module table as a controller. With `moduleScript` given
	and `Name` missing, `Name` falls back to the `ModuleScript` name. Already-
	stamped tables pass through untouched. The Loader uses this when scanning
	`Controllers` folders.
]=]
function Controller.Prepare(value: any, moduleScript: ModuleScript?): any
	if Controller.Is(value) then
		return value
	end
	assert(type(value) == "table", "Framework: controller module must return a table")
	if moduleScript and (type(value.Name) ~= "string" or #value.Name == 0) then
		value.Name = moduleScript.Name
	end
	return Controller.Create(value)
end

function Controller.Is(value: any): boolean
	return type(value) == "table" and value.__tag == TAG_CONTROLLER
end

function Controller.NameOf(def: any): string
	return def.Name
end

function Controller.DependenciesOf(def: any): { string }
	return def.Dependencies
end

return Controller
