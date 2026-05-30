--!strict
--[=[
	@module Lifecycle
	Defines the lifecycle hooks every modular unit may opt into. Hooks are
	called as methods (`module:Hook(...)`), so `self` is always the module's
	own table - no classes, no metatable trickery for services or controllers,
	just plain tables with methods.

	## Service / Controller hooks

	| Hook | When | Yield? |
	| --- | --- | --- |
	| `Init(self)`          | Sequential, in dependency order, before any `Start`. | No. |
	| `Start(self)`         | Parallel, post-init. Each call is `task.spawn`'d.    | Yes. |
	| `Heartbeat(self, dt)` | Bound to `RunService.Heartbeat`.                     | No.  |
	| `Stepped(self, dt)`   | Bound to `RunService.Stepped` (physics tick).        | No.  |
	| `RenderStep(self,dt)` | Bound to `RunService.RenderStepped` (client only).   | No.  |
	| `Stop(self)`          | Called by `Loader.Stop()`.                           | No.  |

	## Component hooks (per-Instance)

	| Hook | When | Yield? |
	| --- | --- | --- |
	| `Construct(self)`     | Right after the per-instance table is created. | No. |
	| `Start(self)`         | Spawned after `Construct`.                     | Yes. |
	| `Heartbeat(self, dt)` | Every frame while mounted.                     | No. |
	| `Stepped(self, dt)`   | Physics tick while mounted.                    | No. |
	| `RenderStep(self,dt)` | Render step (client only) while mounted.       | No. |
	| `Stop(self)`          | Instance unmounted or loader shut down.        | No. |
]=]

local Lifecycle = {}

export type Hooks = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	Heartbeat: ((self: any, dt: number) -> ())?,
	Stepped: ((self: any, dt: number) -> ())?,
	RenderStep: ((self: any, dt: number) -> ())?,
	Stop: ((self: any) -> ())?,
}

export type ComponentHooks = {
	Construct: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	Heartbeat: ((self: any, dt: number) -> ())?,
	Stepped: ((self: any, dt: number) -> ())?,
	RenderStep: ((self: any, dt: number) -> ())?,
	Stop: ((self: any) -> ())?,
}

Lifecycle.MODULE_HOOKS = {
	"Init",
	"Start",
	"Heartbeat",
	"Stepped",
	"RenderStep",
	"Stop",
} :: { string }

Lifecycle.COMPONENT_HOOKS = {
	"Construct",
	"Start",
	"Heartbeat",
	"Stepped",
	"RenderStep",
	"Stop",
} :: { string }

--[=[
	Safely invokes a hook with the module as `self`. Errors are caught and
	returned so callers can log without crashing the loader.
]=]
function Lifecycle.invoke(target: any, hookName: string, ...: any): (boolean, string?)
	local hook = target[hookName]
	if type(hook) ~= "function" then
		return true, nil
	end
	local ok, err = pcall(hook, target, ...)
	if ok then
		return true, nil
	end
	return false, tostring(err)
end

return Lifecycle
