--!strict
--[=[
	@module Modular
	Pulls the modular subsystem (`Service`, `Controller`, `Component`,
	`Loader`, `Lifecycle`) together behind one façade. The parent `Weave`
	module re-exports these as flat top-level functions, so most callers never
	touch `Weave.Modular` directly.
]=]

local Service = require(script.Service)
local Controller = require(script.Controller)
local Component = require(script.Component)
local Loader = require(script.Loader)
local Lifecycle = require(script.Lifecycle)

local Modular = {}

Modular.CreateService = Service.Create
Modular.CreateController = Controller.Create
Modular.CreateComponent = Component.Create

Modular.IsService = Service.Is
Modular.IsController = Controller.Is
Modular.IsComponent = Component.Is

Modular.AddIn = Loader.AddIn
Modular.AddServices = Loader.AddServicesIn
Modular.AddControllers = Loader.AddControllersIn
Modular.AddComponents = Loader.AddComponentsIn

Modular.RegisterService = Loader.RegisterService
Modular.RegisterController = Loader.RegisterController
Modular.RegisterComponent = Loader.RegisterComponent

Modular.GetService = Loader.GetService
Modular.GetController = Loader.GetController
Modular.GetComponent = Loader.GetComponent
Modular.GetComponentInstance = Loader.GetComponentInstance
Modular.GetComponentInstances = Loader.GetComponentInstances

Modular.Start = Loader.Start
Modular.Stop = Loader.Stop
Modular.IsStarted = Loader.IsStarted
Modular.OnStart = Loader.OnStart

export type ServiceDef = Service.ServiceDef
export type ControllerDef = Controller.ControllerDef
export type ComponentDef = Component.ComponentDef
export type ComponentOptions = Component.Options
export type ServiceDefinition = Service.Definition
export type ControllerDefinition = Controller.Definition
export type ComponentDefinition = Component.Definition
export type LifecycleHooks = Lifecycle.Hooks
export type ComponentLifecycleHooks = Lifecycle.ComponentHooks

return Modular
