--!strict
--[=[
	@module Framework
	
	Main entry point:
	  * `CreateService`     - server singleton modules (`:Init`, `:Start`, ...).
	  * `CreateController`  - client singleton modules.
	  * `CreateComponent`   - per-`Instance` modules bound by tag.
	  * `Signal`            - generic, type-safe event streams.
	  * `GlobalSignals`     - shared in-process signal banks for scripts in
	                          the same server/client VM.
	  * `Networking`        - typed packet/bank remotes (RemoteEvent /
	                          UnreliableRemoteEvent / RemoteFunction).
	  * `Monetization`      - `MarketplaceService` wrapper: developer
	                          products, game passes, ProcessReceipt routing
	                          (`Monetization.server` / `Monetization.client`).
	  * `GlobalMessaging`   - cross-server `MessagingService` subscribe /
	                          publish (`GlobalMessaging.server`, server-only).
	  * `FFlags`            - global runtime flags synchronized across live
	                          servers through `GlobalMessaging`.
	  * `Leaderstats`       - sync configured `DataService` values into
	                          player leaderstats folders.
	  * `Symbol`            - opaque identity tokens.
	  * `Enum`              - immutable, comparable enumerations.
	  * `Types`             - `Option<T>`, `Result<T, E>`, helpers.
	  * `Util`              - `Trove`, `TableUtil`, `StringUtil`,
	                          `NumberUtil`, `Debounce`, `Timer`, `Promise`,
	                          `StateMachine`, `Input`, `AssetPreloader`,
	                          `GuiButton` (also re-exported at top level).

	Every framework module returns its typed singleton, so require the unit you
	need directly.

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
local GlobalSignals = require(script.GlobalSignals)
local Symbol = require(script.Symbol)
local Enum = require(script.Enum)
local Types = require(script.Types)
local DataService = require(script.Data)
local DataAdapter = require(script.Adapters.Data)
local MonetizationAdapter = require(script.Adapters.Monetization)
local GlobalMessagingAdapter = require(script.Adapters.GlobalMessaging)
local FFlagsAdapter = require(script.Adapters.FFlags)
local LeaderstatsAdapter = require(script.Adapters.Leaderstats)
local Networking = require(script.Networking)
local Monetization = require(script.Monetization)
local GlobalMessaging = require(script.GlobalMessaging)
local FFlags = require(script.FFlags)
local Leaderstats = require(script.Leaderstats)
local Util = require(script.Util)

local Framework = {}

Framework.CreateService = Modular.CreateService
Framework.CreateController = Modular.CreateController
Framework.CreateComponent = Modular.CreateComponent
Framework.CreateDataService = DataAdapter.CreateService
Framework.CreateDataController = DataAdapter.CreateController
Framework.CreateMonetizationService = MonetizationAdapter.CreateService
Framework.CreateMonetizationController = MonetizationAdapter.CreateController
Framework.CreateGlobalMessagingService = GlobalMessagingAdapter.CreateService
Framework.CreateFFlagsService = FFlagsAdapter.CreateService
Framework.CreateFFlagsController = FFlagsAdapter.CreateController
Framework.CreateLeaderstatsService = LeaderstatsAdapter.CreateService

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
Framework.GlobalSignals = GlobalSignals
Framework.Symbol = Symbol
Framework.Enum = Enum
Framework.Types = Types
Framework.DataService = DataService
Framework.Networking = Networking
Framework.Monetization = Monetization
Framework.GlobalMessaging = GlobalMessaging
Framework.FFlags = FFlags
Framework.Leaderstats = Leaderstats

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
Framework.StateMachine = Util.StateMachine
Framework.Spring = Util.Spring
Framework.Queue = Util.Queue
Framework.Cache = Util.Cache
Framework.Input = Util.Input
Framework.AssetPreloader = Util.AssetPreloader
Framework.Log = Util.Log
Framework.DebugOverlay = Util.DebugOverlay
Framework.Sound = Util.Sound

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection
export type GlobalSignal<T...> = GlobalSignals.Signal<T...>
export type GlobalSignalBank = GlobalSignals.Bank
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
export type AnyDataPath = DataAdapter.AnyPath
export type AnyDataArrayPath = DataAdapter.AnyArrayPath
export type DataServiceOptions<T = { [string]: any }> = DataAdapter.ServerOptions<T>
export type DataControllerOptions<T = { [string]: any }> = DataAdapter.ClientOptions<T>
export type DataServiceClass<
	T = { [string]: any },
	TPath = AnyDataPath,
	TArrayPath = AnyDataArrayPath
> = DataAdapter.ServerClass<T, TPath, TArrayPath>
export type DataControllerClass<
	T = { [string]: any },
	TPath = AnyDataPath,
	TArrayPath = AnyDataArrayPath
> = DataAdapter.ClientClass<T, TPath, TArrayPath>
export type NetworkBank = Networking.Bank
export type NetworkEvent<Args> = Networking.Event<Args>
export type NetworkUnreliableEvent<Args> = Networking.UnreliableEvent<Args>
export type NetworkRequest<Args, Return> = Networking.Request<Args, Return>
export type MonetizationServer = Monetization.Server
export type MonetizationClient = Monetization.Client
export type MonetizationServiceClass = MonetizationAdapter.ServiceClass
export type MonetizationControllerClass = MonetizationAdapter.ControllerClass
export type MonetizationServiceOptions = MonetizationAdapter.ServerOptions
export type MonetizationControllerOptions = MonetizationAdapter.ClientOptions
export type ProductHandler = Monetization.ProductHandler
export type GamePassHandler = Monetization.GamePassHandler
export type ReceiptInfo = Monetization.ReceiptInfo
export type PurchaseRecorder = Monetization.PurchaseRecorder
export type SubscriptionStatus = Monetization.SubscriptionStatus
export type SubscriptionStatusHandler = Monetization.SubscriptionStatusHandler
export type GlobalMessagingServer = GlobalMessaging.Server
export type GlobalMessagingServiceClass = GlobalMessagingAdapter.ServiceClass
export type GlobalMessagingServiceOptions = GlobalMessagingAdapter.ServerOptions
export type GlobalMessage = GlobalMessaging.Message
export type GlobalMessageHandler = GlobalMessaging.MessageHandler
export type GlobalMessagingBank = GlobalMessaging.Bank
export type GlobalMessageTopic<Args> = GlobalMessaging.Topic<Args>
export type GlobalMessageTopicMessage<Args> = GlobalMessaging.TopicMessage<Args>
export type FFlagsServer = FFlags.Server
export type FFlagsClient = FFlags.Client
export type FFlagsServiceClass = FFlagsAdapter.ServiceClass
export type FFlagsControllerClass = FFlagsAdapter.ControllerClass
export type FFlagsServiceOptions = FFlagsAdapter.ServerOptions
export type FFlagsControllerOptions = FFlagsAdapter.ClientOptions
export type FFlagValue = FFlags.FlagValue
export type FFlagChangeSource = FFlags.ChangeSource
export type FFlagChangeHandler = FFlags.ChangeHandler
export type LeaderstatsServer = Leaderstats.Server
export type LeaderstatsServiceClass = LeaderstatsAdapter.ServiceClass
export type LeaderstatsServiceOptions = LeaderstatsAdapter.ServerOptions
export type LeaderstatEntry = Leaderstats.Entry
export type Trove = Util.Trove
export type Timer = Util.Timer
export type Promise<T> = Util.Promise<T>
export type Observer<T> = Util.Observer<T>
export type StateMachine<D> = Util.StateMachine<D>
export type StateConfig<D> = Util.StateConfig<D>
export type StateContext<D> = Util.StateContext<D>
export type StateMachineConfig<D> = Util.StateMachineConfig<D>
export type StateMachineGroup<K, D> = Util.StateMachineGroup<K, D>
export type InputMap = Util.InputMap
export type InputButton = Util.InputButton
export type InputDevice = Util.InputDevice
export type InputOptions = Util.InputOptions
export type Preloader = Util.Preloader
export type PreloadContent = Util.PreloadContent
export type Logger = Util.Logger
export type LogLevel = Util.LogLevel
export type LogSink = Util.LogSink
export type DebugOverlay = Util.DebugOverlay
export type DebugOverlayOptions = Util.DebugOverlayOptions
export type SoundPlayer = Util.SoundPlayer
export type SoundOptions = Util.SoundOptions
export type SoundPlayProps = Util.SoundPlayProps
export type NetworkStats = Networking.NetworkStats
export type NetworkPacketStat = Networking.NetworkPacketStat
export type DataMigrator = DataAdapter.DataMigrator

table.freeze(Framework)
return Framework
