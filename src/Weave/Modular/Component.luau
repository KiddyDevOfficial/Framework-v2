--!strict
--[=[
	@module Component
	Per-`Instance` modules driven by `CollectionService`. Each tagged Instance
	gets a small component table whose methods resolve back to the definition.

	```lua
	-- src/shared/Components/Turret.luau
	local Turret = {
	    Tag = "Turret",
	    Ancestor = workspace,
	}

	function Turret:Construct()
	    self.lastFired = 0
	end

	function Turret:Start() end
	function Turret:Heartbeat(dt: number) end
	function Turret:Stop() end

	return Turret
	```

	`Name` can fall back to the `ModuleScript` name; `Tag` can fall back to
	`Name`. Use `Weave.CreateComponent` for manual registration.

	Each component instance gets `self.Instance` before `Construct`.
]=]

local Symbol = require(script.Parent.Parent.Symbol)
local Lifecycle = require(script.Parent.Lifecycle)
type ComponentHooks = Lifecycle.ComponentHooks

local Component = {}

local TAG_COMPONENT = Symbol.unique("Modular.Component")

export type Options = {
	Name: string,
	Tag: string,
	Ancestor: Instance?,
	Predicate: ((Instance) -> boolean)?,
}

export type Definition = Options & {
	[any]: any,
}

export type ComponentDef = {
	Name: string,
	Tag: string,
	Ancestor: Instance?,
	Predicate: ((Instance) -> boolean)?,
	__tag: typeof(TAG_COMPONENT),
	__index: any,
	[any]: any,
} & ComponentHooks

--[=[
	Stamps `def` as a component and returns the same table.
]=]
function Component.Create<T>(def: T & Definition): T
	local d: any = def
	assert(type(d) == "table", "Weave.CreateComponent: definition must be a table")
	assert(
		type(d.Name) == "string" and #d.Name > 0,
		"Weave.CreateComponent: definition.Name (non-empty string) is required"
	)
	assert(
		type(d.Tag) == "string" and #d.Tag > 0,
		`Weave.CreateComponent: component '{d.Name}' requires a non-empty Tag`
	)
	assert(
		d.Ancestor == nil or typeof(d.Ancestor) == "Instance",
		`Weave.CreateComponent: component '{d.Name}' Ancestor must be an Instance`
	)
	assert(
		d.Predicate == nil or type(d.Predicate) == "function",
		`Weave.CreateComponent: component '{d.Name}' Predicate must be a function`
	)
	assert(d.__tag == nil, `Weave.CreateComponent: '{d.Name}' is already a registered modular unit`)

	d.__tag = TAG_COMPONENT
	d.__index = d
	return def
end

--[=[
	Prepares a plain module table for the Loader.
]=]
function Component.Prepare(value: any, moduleScript: ModuleScript?): any
	if Component.Is(value) then
		return value
	end
	assert(type(value) == "table", "Weave: component module must return a table")
	if moduleScript and (type(value.Name) ~= "string" or #value.Name == 0) then
		value.Name = moduleScript.Name
	end
	if type(value.Tag) ~= "string" or #value.Tag == 0 then
		value.Tag = value.Name
	end
	return Component.Create(value)
end

function Component.Is(value: any): boolean
	return type(value) == "table" and value.__tag == TAG_COMPONENT
end

function Component.NameOf(def: any): string
	return def.Name
end

function Component.TagOf(def: any): string
	return def.Tag
end

function Component.AncestorOf(def: any): Instance?
	return def.Ancestor
end

function Component.PredicateOf(def: any): ((Instance) -> boolean)?
	return def.Predicate
end

function Component.NewInstance(def: any, instance: Instance): any
	local self = setmetatable({ Instance = instance }, def)
	return self
end

return Component
