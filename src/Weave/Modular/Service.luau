--!strict
--[=[
	@module Service
	Server-side singleton modules. A service is a plain table with optional
	lifecycle methods; `self` inside each hook is that same table.

	```lua
	-- src/server/Services/PlayerService.luau
	local PlayerService = {
	    Dependencies = { "DataService" },
	    JoinCount = 0,
	}

	function PlayerService:Init()
	    self.JoinCount = 0
	end

	function PlayerService:Start()
	    game:GetService("Players").PlayerAdded:Connect(function()
	        self.JoinCount += 1
	    end)
	end

	return PlayerService
	```

	`Name` can fall back to the `ModuleScript` name when the Loader scans a
	`Services` folder. Use `Weave.CreateService` for manual registration.
]=]

local Symbol = require(script.Parent.Parent.Symbol)
local Lifecycle = require(script.Parent.Lifecycle)
type Hooks = Lifecycle.Hooks

local Service = {}

local TAG_SERVICE = Symbol.unique("Modular.Service")

export type Definition = {
	Name: string,
	Dependencies: { string }?,
	[any]: any,
}

export type ServiceDef = {
	Name: string,
	Dependencies: { string },
	__tag: typeof(TAG_SERVICE),
	[any]: any,
} & Hooks

--[=[
	Stamps `def` as a service and returns the same table, preserving its type.
]=]
function Service.Create<T>(def: T & Definition): T
	local d: any = def
	assert(type(d) == "table", "Weave.CreateService: definition must be a table")
	assert(
		type(d.Name) == "string" and #d.Name > 0,
		"Weave.CreateService: definition.Name (non-empty string) is required"
	)
	assert(d.__tag == nil, `Weave.CreateService: '{d.Name}' is already a registered modular unit`)

	local deps = d.Dependencies
	if deps == nil then
		d.Dependencies = {}
	else
		assert(type(deps) == "table", `service '{d.Name}': Dependencies must be a table of names`)
		for i, name in deps do
			assert(
				type(name) == "string" and #name > 0,
				`service '{d.Name}': Dependencies[{i}] must be a non-empty string`
			)
		end
	end

	d.__tag = TAG_SERVICE
	return def
end

--[=[
	Prepares a plain module table for the Loader.
]=]
function Service.Prepare(value: any, moduleScript: ModuleScript?): any
	if Service.Is(value) then
		return value
	end
	assert(type(value) == "table", "Weave: service module must return a table")
	if moduleScript and (type(value.Name) ~= "string" or #value.Name == 0) then
		value.Name = moduleScript.Name
	end
	return Service.Create(value)
end

function Service.Is(value: any): boolean
	return type(value) == "table" and value.__tag == TAG_SERVICE
end

function Service.NameOf(def: any): string
	return def.Name
end

function Service.DependenciesOf(def: any): { string }
	return def.Dependencies
end

return Service
