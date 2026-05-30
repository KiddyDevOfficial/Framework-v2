--!strict
--[=[
	@module Framework
	Type-first, modular framework for Roblox/Luau. No classes, no
	inheritance, no abstract methods - just tables with `:Init` / `:Start`
	style methods, dependency ordering, and a CollectionService-driven
	component runtime.

	Pillars:
	  * `CreateService`     - server singleton modules (`:Init`, `:Start`, ...).
	  * `CreateController`  - client singleton modules.
	  * `CreateComponent`   - per-`Instance` modules bound by tag.
	  * `Signal`            - generic, type-safe event streams.
	  * `Networking`        - typed packet/bank remotes (RemoteEvent /
	                          UnreliableRemoteEvent / RemoteFunction).
	  * `Monetization`      - `MarketplaceService` wrapper: developer
	                          products, game passes, ProcessReceipt routing
	                          (`Monetization.server` / `Monetization.client`).
	  * `Symbol`            - opaque identity tokens.
	  * `Enum`              - immutable, comparable enumerations.
	  * `Types`             - `Option<T>`, `Result<T, E>`, helpers.
	  * `Util`              - `Trove`, `TableUtil`, `StringUtil`,
	                          `NumberUtil`, `Debounce`, `Timer`, `Promise`,
	                          `GuiButton` (also re-exported at top level).

	Typed fetch pattern (canonical): every framework unit module already
	returns its typed singleton, so just `require` it directly - no
	`Framework.GetService(name)` annotation needed.

	```lua
	local DataService = require(ServerScriptService.Server.Services.DataService)
	DataService:Update(player, "currency", function(c) return c + 100 end)
	```

	Typical server entry point:
	```lua
	local Framework = require(game:GetService("ReplicatedStorage").Framework)

	Framework.AddServices(script.Parent.Services)
	Framework.AddComponents(game:GetService("ReplicatedStorage").Shared.Components)
	Framework.Start() 
	```

	Typical client entry point:
	```lua
	local Framework = require(game:GetService("ReplicatedStorage").Framework)

	Framework.AddControllers(script.Parent.Controllers)
	Framework.AddComponents(game:GetService("ReplicatedStorage").Shared.Components)
	Framework.Start()
	```
]=]

local Modular = require(script.Modular)
local Signal = require(script.Signal)
local Symbol = require(script.Symbol)
local Enum = require(script.Enum)
local Types = require(script.Types)
local DataService = require(script.DataService)
local DataAdapter = require(script.Adapters.Data)
local Networking = require(script.Networking)
local Monetization = require(script.Monetization)
local Util = require(script.Util)

local Framework = {}

Framework.CreateService = Modular.CreateService
Framework.CreateController = Modular.CreateController
Framework.CreateComponent = Modular.CreateComponent
Framework.CreateDataService = DataAdapter.CreateService
Framework.CreateDataController = DataAdapter.CreateController

Framework.IsService = Modular.IsService
Framework.IsController = Modular.IsController
Framework.IsComponent = Modular.IsComponent

Framework.AddIn = Modular.AddIn
Framework.AddServices = Modular.AddServices
Framework.AddControllers = Modular.AddControllers
Framework.AddComponents = Modular.AddComponents

Framework.RegisterService = Modular.RegisterService
Framework.RegisterController = Modular.RegisterController
Framework.RegisterComponent = Modular.RegisterComponent

Framework.GetService = Modular.GetService
Framework.GetController = Modular.GetController
Framework.GetComponent = Modular.GetComponent
Framework.GetComponentInstance = Modular.GetComponentInstance
Framework.GetComponentInstances = Modular.GetComponentInstances

Framework.Start = Modular.Start
Framework.Stop = Modular.Stop
Framework.IsStarted = Modular.IsStarted
Framework.OnStart = Modular.OnStart

Framework.Modular = Modular
Framework.Signal = Signal
Framework.Symbol = Symbol
Framework.Enum = Enum
Framework.Types = Types
Framework.DataService = DataService
Framework.Networking = Networking
Framework.Monetization = Monetization

Framework.Util = Util
Framework.Trove = Util.Trove
Framework.TableUtil = Util.TableUtil
Framework.StringUtil = Util.StringUtil
Framework.NumberUtil = Util.NumberUtil
Framework.Debounce = Util.Debounce
Framework.Timer = Util.Timer
Framework.Promise = Util.Promise
Framework.GuiButton = Util.GuiButton
Framework.Observer = Util.Observer

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection
export type Symbol = Symbol.Symbol
export type Option<T> = Types.Option<T>
export type Result<T, E> = Types.Result<T, E>
export type ServiceDef = Modular.ServiceDef
export type ControllerDef = Modular.ControllerDef
export type ComponentDef = Modular.ComponentDef
export type ComponentOptions = Modular.ComponentOptions
export type ServiceDefinition = Modular.ServiceDefinition
export type ControllerDefinition = Modular.ControllerDefinition
export type ComponentDefinition = Modular.ComponentDefinition
export type LifecycleHooks = Modular.LifecycleHooks
export type ComponentLifecycleHooks = Modular.ComponentLifecycleHooks
export type DataServiceOptions = DataAdapter.ServerOptions
export type DataControllerOptions = DataAdapter.ClientOptions
export type DataServiceClass = DataAdapter.ServerClass
export type DataControllerClass = DataAdapter.ClientClass
export type NetworkBank = Networking.Bank
export type NetworkEvent<Args> = Networking.Event<Args>
export type NetworkUnreliableEvent<Args> = Networking.UnreliableEvent<Args>
export type NetworkRequest<Args, Return> = Networking.Request<Args, Return>
export type MonetizationServer = Monetization.Server
export type MonetizationClient = Monetization.Client
export type ProductHandler = Monetization.ProductHandler
export type ReceiptInfo = Monetization.ReceiptInfo
export type PurchaseRecorder = Monetization.PurchaseRecorder
export type Trove = Util.Trove
export type Timer = Util.Timer
export type Promise<T> = Util.Promise<T>
export type Observer<T> = Util.Observer<T>

table.freeze(Framework)
return Framework
