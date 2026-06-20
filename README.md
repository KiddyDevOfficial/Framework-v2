# Atlas

Atlas is a type-first toolkit for Roblox games. It takes the stuff you end up rewriting on every project (service bootstrapping, player data, typed remotes, monetization hooks) and folds it into one Luau package with no classes, no inheritance, and no external dependencies.

If you've written the same singleton loader one too many times and just want to get to the fun part, this is for you.

Everything you build is just a **table**. Hand Atlas a table with `:Init` / `:Start` methods and it handles the rest.

---

## Install

### Quick install (recommended)

From this repo, point the installer at any Rojo project (`.` works for the current folder):

```powershell
# Windows
.\install.ps1 C:\path\to\your-game
```

```bash
# macOS / Linux
chmod +x scripts/install-atlas.sh
./scripts/install-atlas.sh /path/to/your-game
```

| Mode | Flag | What it does |
|------|------|----------------|
| **wally** (default) | `-Mode wally` | Adds `kiddydevofficial/atlas` to `wally.toml`, mounts `Packages` in Rojo, runs `wally install`. |
| **local** | `-Mode local` | Links this repo directly into your project. |
| **rbxm** | `-Mode rbxm` | Builds `atlas.rbxm` into `your-game/vendor/`. |

Requires [Rojo](https://github.com/rojo-rbx/rojo) and, for Wally modes, [Wally](https://github.com/UpliftGames/wally) on your PATH. Run `aftman install` in this repo to get both.

Then require it:

```lua
local Atlas = require(game:GetService("ReplicatedStorage").Packages.Atlas)
```

### Wally (manual)

```toml
# wally.toml
[dependencies]
Atlas = "kiddydevofficial/atlas@^0.4.0"
```

```lua
local Atlas = require(game:GetService("ReplicatedStorage").Packages.Atlas)
```

### Rojo (manual)

Drop `src/Atlas/` under `ReplicatedStorage` in your project:

```lua
local Atlas = require(game:GetService("ReplicatedStorage").Atlas)
```

### Standalone build

```bash
rojo build package.project.json -o atlas.rbxm
```

---

## Basic usage

The pattern is the same on server and client: require Atlas, register your modules, call `Start()`.

**Server:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Atlas = require(ReplicatedStorage.Atlas)

Atlas.AddServices(script.Parent.Services)
Atlas.AddComponents(ReplicatedStorage.Shared.Components)
Atlas.Start()
```

**Client:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Atlas = require(ReplicatedStorage.Atlas)

Atlas.AddControllers(script.Parent.Controllers)
Atlas.AddComponents(ReplicatedStorage.Shared.Components)
Atlas.Start()
```

`Atlas.AddIn(folder)` is a shortcut that scans a folder and registers whatever it finds: services, controllers, or components.

That's enough to boot. Nothing interesting happens until you add modules. Let's fix that.

### A simple service

A service is just a table Atlas calls on a schedule. No metatables, no base class. `self` is always that same table.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Atlas = require(ReplicatedStorage.Atlas)

local PlayerService = Atlas.CreateService({
    Name = "PlayerService",
    JoinCount = 0,
})

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

Drop that in your `Services` folder and the loader picks it up automatically. `Name` defaults to the module name if you leave it out.

### A controller

Controllers are the client-side twin of services: same shape, same lifecycle hooks, just only runs when `RunService:IsClient()`.

```lua
local HudController = Atlas.CreateController({
    Name = "HudController",
})

function HudController:Init() end

function HudController:Start()
    -- wire up UI
end

function HudController:RenderStep(dt: number)
    -- per-frame client work
end

return HudController
```

### Components

Components attach to individual `Instance`s via CollectionService tags. Each tagged instance gets its own lightweight table.

Place modules under `ReplicatedStorage.Shared.Components` and call `Atlas.AddComponents(thatFolder)`. The loader stamps `Name` and `Tag` from the module name automatically.

```lua
-- Shared/Components/Turret.luau
local Turret = { Tag = "Turret" }

function Turret:Construct()
    -- self.Instance is already set
    self.lastFired = 0
end

function Turret:Start() end
function Turret:Heartbeat(dt: number) end
function Turret:Stop() end

return Turret
```

Tag a model in Studio with `"Turret"` and Atlas creates a component for it. When the instance is removed, `:Stop` runs and everything cleans up.

### Dependencies

Services and controllers can declare what they need to load first:

```lua
Atlas.CreateService({
    Name = "ShopService",
    Dependencies = { "DataService", "MonetizationService" },
})
```

The loader topologically sorts modules and errors clearly if you create a cycle.

### Lifecycle hooks

| Hook | When | May yield? |
| --- | --- | --- |
| `Init(self)` | Sequential, dependency order, before any `Start`. | No |
| `Start(self)` | Parallel (`task.spawn`), after all inits finish. | Yes |
| `Heartbeat(self, dt)` | Every `RunService.Heartbeat`. | No |
| `Stepped(self, dt)` | Physics tick. | No |
| `RenderStep(self, dt)` | `RenderStepped` (client only). | No |
| `Stop(self)` | `Atlas.Stop()` shutdown. | No |

Components add `Construct(self)` before `Start`, and all frame hooks only run while the instance is mounted.

### Accessing modules

```lua
local PlayerService = Atlas.GetService("PlayerService")
local HudController = Atlas.GetController("HudController")
local turret        = Atlas.GetComponentInstance("Turret", workspace.SomeModel)
```

**Tip:** prefer `require(path.to.YourService)` over `GetService("YourService")` when you can, so Luau will infer your methods without casts.

---

## What's included

Atlas is a **gameplay framework**, not an ECS or a custom replication engine. It's built for the common case: typed server/client singletons, per-instance components, and player data that just works.

| Piece | What it does |
| --- | --- |
| **Service / Controller / Component** | Modular lifecycle (`:Init`, `:Start`, frame hooks). |
| **Loader** | Discovery, dependency sorting, bootstrap. |
| **DataService** | Persistent, replicated player data via vendored [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore). |
| **Networking** | Typed remote banks (`Event`, `UnreliableEvent`, `Request`). |
| **Monetization** | `MarketplaceService` wrapper for products, passes, and subscriptions. |
| **GlobalMessaging** | Cross-server [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService) topics. |
| **FFlags** | Live runtime flags synced across servers. |
| **Leaderstats** | Mirrors `DataService` paths into leaderstats folders. |
| **Analytics** | Crash-safe `AnalyticsService` wrapper (economy, progression, funnels). |
| **GlobalSignals** | In-process signal banks (same VM, not remotes). |
| **Util** | Trove, Promise, StateMachine, Spring, Input, Sound, and more. |
| **Signal / Enum / Symbol / Types** | Core primitives (`Option<T>`, `Result<T, E>`, type-safe events). |

Fully `--!strict`. Passes `luau-lsp analyze` with zero warnings.

### API at a glance

Everything lives on the root `Atlas` table:

| Category | Key entry points |
| --- | --- |
| **Modular** | `CreateService`, `CreateController`, `CreateComponent`, `AddServices`, `AddControllers`, `AddComponents`, `Start`, `Stop`, `GetService`, `GetController` |
| **Data** | `CreateDataService`, `CreateDataController` |
| **Networking** | `Networking.Bank`, `Bank:Event`, `Bank:Request`, `Bank:UnreliableEvent` |
| **Monetization** | `CreateMonetizationService`, `CreateMonetizationController`, `RegisterProduct`, `RegisterGamePass` |
| **GlobalMessaging** | `CreateGlobalMessagingService`, `GlobalMessaging.Bank` |
| **FFlags** | `CreateFFlagsService`, `CreateFFlagsController` |
| **Leaderstats** | `CreateLeaderstatsService` |
| **Analytics** | `CreateAnalyticsService`, `Analytics.server` |
| **Util** | `Trove`, `Promise`, `StateMachine`, `Spring`, `Zone`, `Input`, `Sound`, `Log`, `DebugOverlay`, … |

> **Runtime note:** generic call syntax like `CreateDataService<T>({ ... })` is type-checker only. At runtime, annotate the result instead: `local svc: Class = Atlas.CreateDataService({ ... })`.

---

## Player data

The built-in DataService gives you a per-player reactive `Data` tree (path reads/writes + change signals) with a single replication channel under `ReplicatedStorage/_AtlasDataService`. Persistence is handled by [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (vendored in-tree), so session locking, auto-save, template reconciliation, and `BindToClose` flushing all come for free.

### Server

```lua
-- server/Services/DataService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Atlas = require(ReplicatedStorage.Atlas)
local DataTemplate = require(ReplicatedStorage.Shared.DataTemplate)

type PlayerData = DataTemplate.DataTemplate
export type Class = Atlas.DataServiceClass<PlayerData, DataTemplate.Path, DataTemplate.ArrayPath>

local DataService: Class = Atlas.CreateDataService({
    Name = "DataService",
    Template = DataTemplate,
    ProfileStoreIndex = "PlayerData",
    -- UseMock = true,  -- handy in Studio
})

return DataService
```

Other services list `"DataService"` in `Dependencies` and it's guaranteed live before their own `:Init` runs.

```lua
local DataService = require(ServerScriptService.Server.Services.DataService)

local currency = DataService:Get(player, "currency")
DataService:Update(player, "currency", function(c) return c + 100 end)
DataService:GetChangedSignal(player, "currency"):connect(function(new) print(new) end)
```

Define your schema once in `Shared/DataTemplate.luau`. The `export type DataTemplate` there drives compile-time path autocomplete on both server and client.

### Client

```lua
-- client/Controllers/DataController.luau
return Atlas.CreateDataController({
    Name = "DataController",
    Template = require(ReplicatedStorage.Shared.DataTemplate),
})
```

```lua
local Data = require(StarterPlayerScripts.Client.Controllers.DataController)
Data:WaitForData()
print("currency:", Data:Get("currency"))
```

### Migrations

When you change saved data after launch, register `Migrations` so old profiles upgrade on load:

```lua
Atlas.CreateDataService({
    Template = DataTemplate,
    Migrations = {
        -- v0 -> v1
        function(data)
            data.wallet = { coins = data.coins or 0 }
            data.coins = nil
        end,
    },
})
```

Each migrator upgrades from version `i-1` to `i`. New players start at the target version and skip migration entirely.

### Cross-server gifts

ProfileStore's message queue is wired up for per-player offline delivery:

```lua
Data:AddGlobalCallback("GiftGems", function(player, payload)
    Data:Update(player, "currency", function(c) return c + payload.amount end)
    return true  -- consume the message
end)

Data:SendGlobalMessage("GiftGems", targetUserId, { amount = 500 })
```

---

## Networking

Define remotes once in a shared module, require on server and client. Remote instance names are obfuscated from `game.GameId` / `game.PlaceId`, but your code uses logical bank and packet names.

```lua
-- Shared/Networks/PlayerNet.luau
local Networking = require(ReplicatedStorage.Atlas).Networking
local Bank = Networking.Bank("Player")

export type UpdateFieldArgs = { Field: string, Value: any }

return {
    UpdateField = Bank:Event("UpdateField") :: Networking.Event<UpdateFieldArgs>,
    GetSnapshot = Bank:Request("GetSnapshot") :: Networking.Request<nil, { [string]: any }>,
    MoveHint    = Bank:UnreliableEvent("MoveHint") :: Networking.UnreliableEvent<Vector3>,
}
```

```lua
-- Server
local Net = require(ReplicatedStorage.Shared.Networks.PlayerNet)
Net.UpdateField:OnServerEvent(function(player, args) ... end)

-- Client
Net.UpdateField:FireServer({ Field = "currency", Value = 100 })
local snap = Net.GetSnapshot:InvokeServer(nil)
```

Opt into traffic counters with `Networking.Stats`, useful for spotting remotes that fire too often. `DebugOverlay` turns this on automatically while visible.

---

## Monetization

A thin `MarketplaceService` layer for developer products, game passes, and [subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions). Define your catalog once under `Shared/Lists/`:

```lua
-- Shared/Lists/Products.luau
Products.Products = {
    {
        id = 112213,
        name = "Starter Pack",
        handler = function(player, receipt)
            -- grant + persist, then return true
            return true
        end,
    },
}
```

The shipped `MonetizationService` auto-registers every list entry on `:Init`. Game pass handlers should be **idempotent**: they run on purchase *and* when a player joins if they already own the pass.

```lua
local Monetization = require(ServerScriptService.Server.Services.MonetizationService)
Monetization:PromptProductPurchase(player, 112213)
Monetization.ProductPurchased:connect(function(player, productId) ... end)
```

On the client, `CreateMonetizationController` exposes prompt helpers and purchase-finished signals.

---

## Global messaging & FFlags

**GlobalMessaging** wraps [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService) for cross-server topics. Delivery is best-effort; payloads must stay under 1 KB. Define topics in banks, same pattern as Networking:

```lua
local GlobalMessaging = require(ReplicatedStorage.Atlas).GlobalMessaging
local Bank = GlobalMessaging.Bank("Events")

return {
    Announcement = Bank:Event("Announcement") :: GlobalMessaging.Topic<{ text: string }>,
}
```

Use **DataService global messages** when you need per-player offline queues. Use **GlobalMessaging** for live-server broadcasts.

**FFlags** are server-owned runtime values synced across live servers through GlobalMessaging. Clients get a read-only snapshot.

```lua
-- Shared/FFlags.luau
return { DoubleXP = false, EventMultiplier = 1 }

-- server
local FFlags = require(ServerScriptService.Server.Services.FFlagsService)
FFlags:Set("EventMultiplier", 2)   -- propagates to all live servers
FFlags:Observe("DoubleXP", function(value) ... end)
```

---

## Leaderstats

Mirror selected `DataService` paths into each player's leaderstats folder. Configure entries in `Shared/Leaderstats.luau`:

```lua
Leaderstats.Entries = {
    { Path = "currency", Name = "Coins", Class = "IntValue" },
    { Path = "level", Name = "Level", Class = "IntValue" },
}
```

Values update automatically whenever data changes through `DataService`.

---

## Analytics

A crash-proof wrapper over Roblox [AnalyticsService](https://create.roblox.com/docs/production/analytics/analytics-events). Every log call is wrapped in `pcall`, so a telemetry failure never propagates into gameplay code, and each returns whether the call landed. Flow and progression fields accept a string *or* the matching `EnumItem`. Server-only.

```lua
-- server/Services/AnalyticsService.luau
return Atlas.CreateAnalyticsService({ Name = "AnalyticsService" })
```

```lua
local Analytics = require(ServerScriptService.Server.Services.AnalyticsService)

-- Economy: track currency sources and sinks.
Analytics:LogEconomyEvent(player, {
    flowType = "Sink",            -- or Enum.AnalyticsEconomyFlowType.Sink
    currencyType = "Coins",
    amount = 100,
    endingBalance = 400,
    transactionType = "Shop",     -- Gameplay | Shop | IAP | TimedReward | ...
    itemSku = "SwordOfTruth",
})

-- Progression: where players start, complete, or drop off.
Analytics:LogProgressionEvent(player, {
    path = "Tutorial",
    status = "Complete",          -- Start | Complete | Fail | Custom
    level = 1,
})

-- Funnels, onboarding steps, and arbitrary custom events.
Analytics:LogFunnelStep(player, { funnelName = "Shop", step = 2, stepName = "OpenedCart" })
Analytics:LogOnboardingStep(player, { step = 1, stepName = "PickedAvatar" })
Analytics:LogCustomEvent(player, { name = "BossDefeated", value = 1 })
```

Unknown enum strings are reported (toggle with the `WarnOnError` option) and the call is skipped rather than thrown.

---

## Global signals

Lightweight in-process events for modules in the same server or client VM. Not remotes. Use `Networking` for client/server and `GlobalMessaging` for cross-server.

```lua
local GlobalSignals = require(ReplicatedStorage.Atlas).GlobalSignals
local Bank = GlobalSignals.Bank("Game")

return {
    RoundStarted = Bank:Signal("RoundStarted") :: GlobalSignals.Signal<string>,
}
```

```lua
Signals.RoundStarted:connect(function(mapName) print("go!", mapName) end)
Signals.RoundStarted:fire("Arena")
```

---

## Utilities

Re-exported on `Atlas` and grouped under `Atlas.Util`. A few you'll reach for often:

**Trove** for connection and instance cleanup:

```lua
local trove = Atlas.Trove.new()
trove:add(workspace.ChildAdded:Connect(...))
-- trove:destroy() disconnects everything
```

**StateMachine** for typed finite state machines with per-entity `group` support:

```lua
local fsm = Atlas.StateMachine.new({
    initial = "Idle",
    data = { ticks = 0 },
    states = {
        Idle   = { transitions = { "Active" } },
        Active = { transitions = { "Idle" }, onEnter = function(ctx) ctx.data.ticks += 1 end },
    },
})
fsm:transition("Active")
```

**Spring** for physics-based interpolation (camera follow, UI bounce, recoil):

```lua
local cam = Atlas.Spring.new(Vector3.zero, 4, 1)
cam:setTarget(targetPosition)
-- call cam:step(dt) each frame
```

**Zone** for spatial triggers. Hand it a part, a list of parts, or a model/folder of parts and it polls the region on an interval, firing signals as players (and any instances you explicitly `watch`) enter and leave. Detection uses an Include-filtered `OverlapParams`, so each poll only tests the characters you care about. Works on server or client.

```lua
local zone = Atlas.Zone.new(workspace.SafeRoom)
zone.playerEntered:connect(function(player) print(player.Name, "entered") end)
zone.playerExited:connect(function(player) print(player.Name, "left") end)

-- Or define a region with no part at all:
local box = Atlas.Zone.fromBox(CFrame.new(0, 5, 0), Vector3.new(20, 10, 20))
-- zone:destroy() when done
```

**Input** is a device-agnostic action map with rebind support. The shipped `InputController` wraps a shared map as a singleton.

| Module | Purpose |
| --- | --- |
| `Trove` | Connection/instance cleanup. |
| `Promise` | Lightweight async promises. |
| `Observer` | Observer functions (`observeTag`, `observeProperty`, `observeAttribute`, `observeChildren`, `observePlayer`, `observeCharacter`). |
| `StateMachine` | Finite state machines + per-key groups. |
| `Spring` | Damped harmonic oscillator for smooth motion. |
| `Zone` | Spatial trigger volumes with player/instance enter/exit signals. |
| `Queue` / `Cache` | FIFO queue and LRU/TTL memoization. |
| `Input` | Named action bindings across devices. |
| `AssetPreloader` | `ContentProvider:PreloadAsync` with progress. |
| `Log` | Leveled, tagged logging with FFlag gating. |
| `DebugOverlay` | On-screen FPS + remote traffic HUD. |
| `Sound` | Play sounds by name from a library folder. |
| `GuiButton` | Hover/press tweens for `Button`-tagged GUI. |
| `TableUtil` / `StringUtil` / `NumberUtil` / `Debounce` / `Timer` | Everyday helpers. |

---

## Core primitives

**Signal** provides generic, type-safe events. Handlers run on independent threads; one erroring listener never blocks the rest.

```lua
local s: Atlas.Signal.Signal<string> = Atlas.Signal.new()
s:connect(function(msg) print(msg) end)
s:fire("hello")
```

**Types** include `Option<T>` and `Result<T, E>` for explicit absence and error handling.

**Enum** gives you immutable, comparable enumerations. **Symbol** provides opaque identity tokens.

---

## Project layout

```
src/
├── Atlas/                  ← the package
│   ├── Modular/            ← Service, Controller, Component, Loader
│   ├── Data/               ← player data + vendored ProfileStore
│   ├── Networking/         ← typed remote banks
│   ├── Monetization/       ← MarketplaceService wrapper
│   ├── GlobalMessaging/    ← cross-server topics
│   ├── FFlags/             ← live runtime flags
│   ├── Leaderstats/        ← leaderstats sync
│   ├── GlobalSignals/      ← in-process signal banks
│   ├── Adapters/           ← Create* factories for subsystems
│   └── Util/               ← Trove, Spring, Input, Sound, …
├── server/Services/        ← your server modules
├── client/Controllers/     ← your client modules
└── shared/                 ← DataTemplate, Networks, Lists, Components, …
```

- `default.project.json`: dev place, mounts Atlas + starter folders.
- `package.project.json`: library-only build for `rojo build`.
- `wally.toml`: package metadata (`kiddydevofficial/atlas`).

---

## Development

```bash
rojo serve              # dev place to Studio
rojo build package.project.json -o atlas.rbxm
```

Type-checking (requires [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp)):

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --platform=roblox src
```

### Publishing to Wally

```bash
wally login    # authenticate with GitHub account KiddyDevOfficial
wally publish  # from repo root
```

```toml
[dependencies]
Atlas = "kiddydevofficial/atlas@^0.4.0"
```

---

Persistence is powered by [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) by loleris.

Built and maintained by [KiddyDevOfficial](https://github.com/KiddyDevOfficial).

## License

MIT. See [LICENSE](LICENSE).
