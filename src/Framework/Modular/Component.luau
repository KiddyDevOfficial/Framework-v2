--!strict
--[=[
	@module Component
	Per-`Instance` modules driven by `CollectionService`. Each tagged
	Instance gets its own lightweight component table that resolves method
	lookups back to the definition - you write method-style code, no `new`
	constructor, no inheritance.

	```lua
	-- src/shared/Components/Turret.luau
	local Turret = {
	    Tag = "Turret",
	    Ancestor = workspace,                       -- optional
	    -- Predicate = function(inst) return ... end,
	}

	function Turret:Construct()
	    -- self.Instance is already set for you
	    self.lastFired = 0
	end

	function Turret:Start() end
	function Turret:Heartbeat(dt: number) end
	function Turret:Stop() end

	return Turret
	```

	`Name` defaults to the `ModuleScript` name; leave `Tag` out and it
	falls back to `Name`. The Loader stamps and registers the table when it
	scans a `Components` folder, and `Framework.CreateComponent` is still
	there for manual registration.

	The loader sets `self.Instance` to the tagged Roblox `Instance` and
	calls every hook with `self` bound to the per-instance table.
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
	Stamps `def` as a component in place and returns it. Sets
	`def.__index = def` so the per-instance tables the loader creates can
	resolve methods through it without you ever touching metatables.
]=]
function Component.Create<T>(def: T & Definition): T
	local d: any = def
	assert(type(d) == "table", "Framework.CreateComponent: definition must be a table")
	assert(
		type(d.Name) == "string" and #d.Name > 0,
		"Framework.CreateComponent: definition.Name (non-empty string) is required"
	)
	assert(
		type(d.Tag) == "string" and #d.Tag > 0,
		`Framework.CreateComponent: component '{d.Name}' requires a non-empty Tag`
	)
	assert(
		d.Ancestor == nil or typeof(d.Ancestor) == "Instance",
		`Framework.CreateComponent: component '{d.Name}' Ancestor must be an Instance`
	)
	assert(
		d.Predicate == nil or type(d.Predicate) == "function",
		`Framework.CreateComponent: component '{d.Name}' Predicate must be a function`
	)
	assert(d.__tag == nil, `Framework.CreateComponent: '{d.Name}' is already a registered modular unit`)

	d.__tag = TAG_COMPONENT
	d.__index = d
	return def
end

--[=[
	Stamps a plain module table as a component. With `moduleScript` given,
	`Name` falls back to the `ModuleScript` name and `Tag` falls back to
	`Name`. Already-stamped tables pass through untouched. The Loader uses
	this when scanning `Components` folders.
]=]
function Component.Prepare(value: any, moduleScript: ModuleScript?): any
	if Component.Is(value) then
		return value
	end
	assert(type(value) == "table", "Framework: component module must return a table")
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

--[=[
	Builds the lightweight per-instance table for a freshly-tagged Instance.
	`def` handles method resolution via `__index`; `Instance` is set up front
	so the `Construct` hook can reach the Roblox object straight away.
]=]
function Component.NewInstance(def: any, instance: Instance): any
	local self = setmetatable({ Instance = instance }, def)
	return self
end

return Component
