--!nocheck
--[=[
	@module Loader
	Finds modular units (services, controllers, components), sorts them by
	dependency, runs `Init`, spawns `Start`, and wires frame hooks. Services run
	on the server, controllers on the client, and components wherever they are
	registered.

	Server entry point:
	```lua
	local Weave = require(ReplicatedStorage.Weave)
	Weave.AddServices(script.Parent.Services)
	Weave.AddComponents(ReplicatedStorage.Shared.Components)
	Weave.Start()
	```

	Client mirrors with `AddControllers`.
]=]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Service = require(script.Parent.Service)
local Controller = require(script.Parent.Controller)
local Component = require(script.Parent.Component)
local Lifecycle = require(script.Parent.Lifecycle)

local Loader = {}


type ComponentState = {
	def: any,
	instances: { [Instance]: any },
	addedConn: RBXScriptConnection?,
	removedConn: RBXScriptConnection?,
}

type LoaderState = {
	services: { [string]: any },
	controllers: { [string]: any },
	components: { [string]: ComponentState },
	heartbeatTargets: { any },
	steppedTargets: { any },
	renderTargets: { any },
	connections: { RBXScriptConnection },
	onStartListeners: { () -> () },
	started: boolean,
	starting: boolean,
}

local state: LoaderState = {
	services = {},
	controllers = {},
	components = {},
	heartbeatTargets = {},
	steppedTargets = {},
	renderTargets = {},
	connections = {},
	onStartListeners = {},
	started = false,
	starting = false,
}

local function assertNotStarted(api: string)
	if state.started or state.starting then
		error(`Weave.{api}: cannot be called after Start()`, 3)
	end
end

local function warnLifecycle(unit: string, hook: string, err: string)
	warn(`[Weave] {unit}:{hook} errored: {err}`)
end


local function requireModule(module: ModuleScript): any
	local ok, value = pcall(require, module)
	if not ok then
		error(`Weave Loader: failed requiring '{module:GetFullName()}': {value}`, 0)
	end
	return value
end

function Loader.RegisterService(def: any)
	assertNotStarted("RegisterService")
	assert(Service.Is(def), "Weave.RegisterService: argument is not a service")
	local name = Service.NameOf(def)
	assert(state.services[name] == nil, `Weave.RegisterService: duplicate service '{name}'`)
	state.services[name] = def
end

function Loader.RegisterController(def: any)
	assertNotStarted("RegisterController")
	assert(Controller.Is(def), "Weave.RegisterController: argument is not a controller")
	local name = Controller.NameOf(def)
	assert(state.controllers[name] == nil, `Weave.RegisterController: duplicate controller '{name}'`)
	state.controllers[name] = def
end

function Loader.RegisterComponent(def: any)
	assertNotStarted("RegisterComponent")
	assert(Component.Is(def), "Weave.RegisterComponent: argument is not a component")
	local name = Component.NameOf(def)
	assert(state.components[name] == nil, `Weave.RegisterComponent: duplicate component '{name}'`)
	state.components[name] = {
		def = def,
		instances = {},
		addedConn = nil,
		removedConn = nil,
	}
end

local function loadFolder(folder: Instance, handler: (any, ModuleScript) -> ())
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			local value = requireModule(descendant)
			handler(value, descendant)
		end
	end
end

function Loader.AddIn(folder: Instance)
	loadFolder(folder, function(value, moduleScript)
		if type(value) ~= "table" then
			return
		end
		if Service.Is(value) then
			Loader.RegisterService(value)
		elseif Controller.Is(value) then
			Loader.RegisterController(value)
		elseif Component.Is(value) then
			Loader.RegisterComponent(value)
		end
	end)
end

function Loader.AddServicesIn(folder: Instance)
	loadFolder(folder, function(v, moduleScript)
		if type(v) ~= "table" then
			return
		end
		Loader.RegisterService(Service.Prepare(v, moduleScript))
	end)
end

function Loader.AddControllersIn(folder: Instance)
	loadFolder(folder, function(v, moduleScript)
		if type(v) ~= "table" then
			return
		end
		Loader.RegisterController(Controller.Prepare(v, moduleScript))
	end)
end

function Loader.AddComponentsIn(folder: Instance)
	loadFolder(folder, function(v, moduleScript)
		if type(v) ~= "table" then
			return
		end
		Loader.RegisterComponent(Component.Prepare(v, moduleScript))
	end)
end


--[=[
	String-keyed lookup for a registered service. Prefer direct `require` for
	typed access; use this for dynamic cases like debug tools.

	Example:
	```lua
	local Data: DataServiceModule.Class = Weave.GetService("DataService")
	```
]=]
function Loader.GetService<T>(name: string): T
	local s = state.services[name]
	assert(s, `Weave.GetService: '{name}' is not registered`)
	return s :: any
end

--[=[
	String-keyed lookup for a registered controller.
]=]
function Loader.GetController<T>(name: string): T
	local c = state.controllers[name]
	assert(c, `Weave.GetController: '{name}' is not registered`)
	return c :: any
end

--[=[
	String-keyed lookup for a component definition.
]=]
function Loader.GetComponent<T>(name: string): T
	local c = state.components[name]
	assert(c, `Weave.GetComponent: '{name}' is not registered`)
	return c.def :: any
end

--[=[
	Returns the per-instance component table for a specific `Instance`, or
	`nil` if it is not mounted.

	```lua
	local plot: PlotModule.Class? = Weave.GetComponentInstance("Plot", model)
	```
]=]
function Loader.GetComponentInstance<T>(name: string, instance: Instance): T?
	local c = state.components[name]
	if not c then
		return nil
	end
	return c.instances[instance] :: any
end

--[=[
	Returns every currently-mounted instance of the named component.
]=]
function Loader.GetComponentInstances<T>(name: string): { T }
	local c = state.components[name]
	local out: { T } = {}
	if not c then
		return out
	end
	for _, inst in c.instances do
		table.insert(out, inst :: any)
	end
	return out
end


local function topoSort(items: { [string]: any }, depsOf: (any) -> { string }, kind: string): { any }
	local order: { any } = {}
	local marks: { [string]: "temp" | "perm" } = {}

	local function visit(name: string, trail: { string })
		local mark = marks[name]
		if mark == "perm" then
			return
		end
		if mark == "temp" then
			table.insert(trail, name)
			error(`Weave Loader: cyclic {kind} dependency: {table.concat(trail, " -> ")}`, 0)
		end
		local def = items[name]
		if not def then
			error(`Weave Loader: {kind} '{name}' has missing dependency or is unregistered`, 0)
		end
		marks[name] = "temp"
		table.insert(trail, name)
		for _, depName in depsOf(def) do
			visit(depName, trail)
		end
		table.remove(trail)
		marks[name] = "perm"
		table.insert(order, def)
	end

	for name in items do
		if marks[name] ~= "perm" then
			visit(name, {})
		end
	end

	return order
end


local function runInit(def: any)
	if type(def.Init) ~= "function" then
		return
	end
	local ok, err = pcall(def.Init, def)
	if not ok then
		error(`Weave Loader: {def.Name}:Init failed: {err}`, 0)
	end
end

local function spawnStart(def: any)
	if type(def.Start) ~= "function" then
		return
	end
	task.spawn(function()
		local ok, err = Lifecycle.invoke(def, "Start")
		if not ok then
			warnLifecycle(def.Name, "Start", err :: string)
		end
	end)
end

local function registerFrameHooks(def: any)
	if type(def.Heartbeat) == "function" then
		table.insert(state.heartbeatTargets, def)
	end
	if type(def.Stepped) == "function" then
		table.insert(state.steppedTargets, def)
	end
	if type(def.RenderStep) == "function" and RunService:IsClient() then
		table.insert(state.renderTargets, def)
	end
end


local function componentTryAdd(name: string, cstate: ComponentState, instance: Instance)
	if cstate.instances[instance] then
		return
	end
	local def = cstate.def
	local ancestor = Component.AncestorOf(def)
	if ancestor and not instance:IsDescendantOf(ancestor) then
		return
	end
	local predicate = Component.PredicateOf(def)
	if predicate then
		local ok, allow = pcall(predicate, instance)
		if not ok then
			warn(`[Weave] component '{name}' Predicate errored: {allow}`)
			return
		end
		if not allow then
			return
		end
	end

	local self = Component.NewInstance(def, instance)
	cstate.instances[instance] = self

	if type(self.Construct) == "function" then
		local ok, err = pcall(self.Construct, self)
		if not ok then
			cstate.instances[instance] = nil
			warnLifecycle(name, "Construct", tostring(err))
			return
		end
	end

	if type(self.Start) == "function" then
		task.spawn(function()
			if cstate.instances[instance] ~= self then
				return
			end
			local ok, err = pcall(self.Start, self)
			if not ok then
				warnLifecycle(name, "Start", tostring(err))
			end
		end)
	end
end

local function componentTryRemove(name: string, cstate: ComponentState, instance: Instance)
	local self = cstate.instances[instance]
	if not self then
		return
	end
	cstate.instances[instance] = nil
	if type(self.Stop) == "function" then
		task.spawn(function()
			local ok, err = pcall(self.Stop, self)
			if not ok then
				warnLifecycle(name, "Stop", tostring(err))
			end
		end)
	end
end

local function bindComponent(name: string, cstate: ComponentState)
	local def = cstate.def
	local tag = Component.TagOf(def)

	for _, instance in CollectionService:GetTagged(tag) do
		componentTryAdd(name, cstate, instance)
	end
	cstate.addedConn = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		componentTryAdd(name, cstate, instance)
	end)
	cstate.removedConn = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		componentTryRemove(name, cstate, instance)
	end)
end


local function bindFrameLoops()
	if #state.heartbeatTargets > 0 or next(state.components) ~= nil then
		table.insert(
			state.connections,
			RunService.Heartbeat:Connect(function(dt)
				for _, def in state.heartbeatTargets do
					local ok, err = pcall(def.Heartbeat, def, dt)
					if not ok then
						warnLifecycle(def.Name, "Heartbeat", tostring(err))
					end
				end
				for cname, c in state.components do
					for _, self in c.instances do
						local hb = self.Heartbeat
						if type(hb) == "function" then
							local ok, err = pcall(hb, self, dt)
							if not ok then
								warnLifecycle(cname, "Heartbeat", tostring(err))
							end
						end
					end
				end
			end)
		)
	end

	if #state.steppedTargets > 0 or next(state.components) ~= nil then
		table.insert(
			state.connections,
			RunService.Stepped:Connect(function(_, dt)
				for _, def in state.steppedTargets do
					local ok, err = pcall(def.Stepped, def, dt)
					if not ok then
						warnLifecycle(def.Name, "Stepped", tostring(err))
					end
				end
				for cname, c in state.components do
					for _, self in c.instances do
						local st = self.Stepped
						if type(st) == "function" then
							local ok, err = pcall(st, self, dt)
							if not ok then
								warnLifecycle(cname, "Stepped", tostring(err))
							end
						end
					end
				end
			end)
		)
	end

	if RunService:IsClient() and (#state.renderTargets > 0 or next(state.components) ~= nil) then
		table.insert(
			state.connections,
			RunService.RenderStepped:Connect(function(dt)
				for _, def in state.renderTargets do
					local ok, err = pcall(def.RenderStep, def, dt)
					if not ok then
						warnLifecycle(def.Name, "RenderStep", tostring(err))
					end
				end
				for cname, c in state.components do
					for _, self in c.instances do
						local rs = self.RenderStep
						if type(rs) == "function" then
							local ok, err = pcall(rs, self, dt)
							if not ok then
								warnLifecycle(cname, "RenderStep", tostring(err))
							end
						end
					end
				end
			end)
		)
	end
end


--[=[
	Starts registered units in dependency order and mounts tagged components.
]=]
function Loader.Start()
	if state.started or state.starting then
		return
	end
	state.starting = true

	local isServer = RunService:IsServer()
	local isClient = RunService:IsClient()

	local servicesOrder = topoSort(state.services, Service.DependenciesOf, "service")
	local controllersOrder = topoSort(state.controllers, Controller.DependenciesOf, "controller")

	if isServer then
		for _, def in servicesOrder do
			runInit(def)
			registerFrameHooks(def)
		end
	end

	if isClient then
		for _, def in controllersOrder do
			runInit(def)
			registerFrameHooks(def)
		end
	end

	for name, cstate in state.components do
		bindComponent(name, cstate)
	end

	bindFrameLoops()

	if isServer then
		for _, def in servicesOrder do
			spawnStart(def)
		end
	end
	if isClient then
		for _, def in controllersOrder do
			spawnStart(def)
		end
	end

	state.started = true
	state.starting = false

	local listeners = state.onStartListeners
	state.onStartListeners = {}
	for _, fn in listeners do
		task.spawn(fn)
	end
end

--[=[
	Disconnects live hooks and calls `Stop` while unmounting.
]=]
function Loader.Stop()
	if not state.started then
		return
	end
	for _, conn in state.connections do
		conn:Disconnect()
	end
	table.clear(state.connections)
	table.clear(state.heartbeatTargets)
	table.clear(state.steppedTargets)
	table.clear(state.renderTargets)

	for cname, cstate in state.components do
		if cstate.addedConn then
			cstate.addedConn:Disconnect()
			cstate.addedConn = nil
		end
		if cstate.removedConn then
			cstate.removedConn:Disconnect()
			cstate.removedConn = nil
		end
		for instance, self in cstate.instances do
			cstate.instances[instance] = nil
			if type(self.Stop) == "function" then
				local ok, err = pcall(self.Stop, self)
				if not ok then
					warnLifecycle(cname, "Stop", tostring(err))
				end
			end
		end
	end

	local function stopAll(items: { [string]: any }, kind: string)
		for _, def in items do
			if type(def.Stop) == "function" then
				local ok, err = pcall(def.Stop, def)
				if not ok then
					warnLifecycle(`{kind}:{def.Name}`, "Stop", tostring(err))
				end
			end
		end
	end
	if RunService:IsServer() then
		stopAll(state.services, "service")
	end
	if RunService:IsClient() then
		stopAll(state.controllers, "controller")
	end

	state.started = false
end

function Loader.IsStarted(): boolean
	return state.started
end

--[=[
	Runs `callback` after `Start()` finishes, or immediately if already started.
]=]
function Loader.OnStart(callback: () -> ())
	assert(type(callback) == "function", "Weave.OnStart: callback must be a function")
	if state.started then
		task.spawn(callback)
		return
	end
	table.insert(state.onStartListeners, callback)
end

return Loader
