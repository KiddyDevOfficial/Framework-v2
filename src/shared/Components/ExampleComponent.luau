--!strict
--[=[
	@component ExampleComponent
	Starter component. Binds to every `Instance` tagged `ExampleComponent`
	via CollectionService (server + client). Return a plain table with a
	`Tag`; the Loader infers the name from the ModuleScript otherwise.

	Lifecycle (all optional): `Construct` -> `Start` -> `Heartbeat` -> `Stop`.

	```lua
	local ExampleComponent = require(ReplicatedStorage.Shared.Components.ExampleComponent)
	local inst: ExampleComponent.Class? =
	    Weave.GetComponentInstance("ExampleComponent", someInstance)
	```
]=]

export type Class = {
	Instance: Instance,
}

local ExampleComponent = {
	Tag = "ExampleComponent",
}

function ExampleComponent:Construct()
	-- `self.Instance` is the tagged Instance. Set up per-instance state here.
end

function ExampleComponent:Start()
	-- Runs after Construct, once the component is live.
end

function ExampleComponent:Stop()
	-- Clean up connections/objects when the Instance is untagged/destroyed.
end

return ExampleComponent
