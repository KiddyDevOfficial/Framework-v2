# Goling's Framework

Goling's Framework is a type-first, modular framework for Roblox / Luau that
streamlines the boilerplate every game ends up rewriting - service loaders,
player-data saving, typed remotes, monetization and more - into one
self-contained package. It runs on plain Luau with no classes, no inheritance,
no abstract methods and no external dependencies.

If you keep writing the same singleton loader and data-replication glue for
every new game and want to skip straight to the gameplay - this can be a
helpful resource!

## How does it work?

Everything you build is just a **table**. You hand the framework a table with
`:Init` / `:Start` style methods and it wires up the lifecycle for you - no
metatables, no inheritance, and `self` is always that same table.

The **Loader** discovers your modules, sorts them by their declared
**dependencies**, runs every `:Init` in order, spawns `:Start`, then binds the
frame loops (`:Heartbeat`, `:Stepped`, `:RenderStep`) for as long as a module
is alive. **Services** run on the server, **Controllers** run on the client
with the exact same shape, and **Components** attach one table per
CollectionService-tagged `Instance`.

On top of that core sit the batteries-included subsystems - **DataService**,
**Networking**, **Monetization**, **GlobalMessaging**, **FFlags**,
**Leaderstats** and **GlobalSignals** - and each one folds into the same
lifecycle through a `Create*` factory, so the rest of your code just lists it
as a dependency. Persistent player data is backed by a vendored
[ProfileStore](https://github.com/MadStudioRoblox/ProfileStore), so session
locking, auto-save and template reconciliation come along for free.

Much like the Roblox API itself, the public methods lean on PascalCase and
familiar naming so they read the way you'd expect; the underlying modules also
expose a lowercase API for advanced use.

**Goling's Framework is a gameplay framework - not an ECS, and not a
high-throughput replication engine.** It is tuned for the common case: typed
server/client singletons, per-instance components, and player data that just
works. If you need a full entity-component-system or custom replication, reach
for a purpose-built library instead.

The framework ships with these pieces:

- **Service** — server singleton with `:Init`, `:Start`, `:Heartbeat`, …
- **Controller** — client singleton, same shape.
- **Component** — per-`Instance` module bound by tag (`:Construct`, `:Start`, `:Stop`, …).
- **Loader** — discovery, dependency-aware bootstrap, lifecycle binding.
- **Signal\<T...\>** — generic, type-safe events.
- **GlobalSignals** — shared in-process signal banks for scripts in the same
  server/client VM.
- **Networking** — typed remote banks (`Event`, `UnreliableEvent`, `Request`).
- **DataService** — persistent, auto-replicated player data backed by a
  vendored [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore),
  via `CreateDataService` / `CreateDataController`.
- **Leaderstats** — sync configured `DataService` values into each player's
  leaderstats folder, via `CreateLeaderstatsService`.
- **Monetization** — `MarketplaceService` wrapper (products, passes,
  [subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions), receipts),
  catalog lists in `Shared/Lists`, via `CreateMonetizationService` /
  `CreateMonetizationController`.
- **GlobalMessaging** — cross-server [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService)
  subscribe / publish (server-only), via `CreateGlobalMessagingService`.
- **FFlags** — global runtime flags / shared values synchronized across live
  servers through GlobalMessaging, via `CreateFFlagsService`.
- **Util** — `Trove`, `TableUtil`, `StringUtil`, `NumberUtil`, `Debounce`,
  `Timer`, `Promise`, `Observer`, `StateMachine`, `Spring`, `Queue`, `Cache`,
  `Input`, `AssetPreloader`, `Log`, `DebugOverlay`, `Sound`, `GuiButton`
  (CollectionService tag `Button`).
- **Enum** — immutable, comparable enumerations.
- **Symbol** — opaque identity tokens.
- **Types** — `Option<T>`, `Result<T, E>`, helpers.

Fully `--!strict`. Passes `luau-lsp analyze` with zero warnings.

### API overview

Everything below is on the root `Framework` table (also available as
`Framework.Modular`, `Framework.Util`, etc. where noted).

| Category | Functions / modules |
| --- | --- |
| **Modular** | `CreateService`, `CreateController`, `CreateComponent`, `AddIn`, `AddServices`, `AddControllers`, `AddComponents`, `RegisterService`, `RegisterController`, `RegisterComponent`, `GetService`, `GetController`, `GetComponent`, `GetComponentInstance`, `GetComponentInstances`, `Start`, `Stop`, `IsStarted`, `OnStart`, `IsService`, `IsController`, `IsComponent` |
| **Data** | `CreateDataService`, `CreateDataController`, `DataService` (`{ server, client }`) |
| **Leaderstats** | `CreateLeaderstatsService`, `Leaderstats` (`{ server }`) |
| **Monetization** | `CreateMonetizationService`, `CreateMonetizationController`, `Monetization` (`{ server, client }`), `RegisterProduct`, `RegisterGamePass`, `RegisterSubscription` |
| **GlobalSignals** | `GlobalSignals`, `GlobalSignals.Bank`, `GlobalSignals.Signal`, `Bank:Signal` |
| **GlobalMessaging** | `CreateGlobalMessagingService`, `GlobalMessaging` (`{ server, Bank }`), `Bank:Event`, `Subscribe`, `Publish` |
| **FFlags** | `CreateFFlagsService`, `CreateFFlagsController`, `FFlags` (`{ server, client }`), `Get`, `Set`, `Observe`, `Remove` |
| **Core** | `Signal`, `Networking`, `Networking.Stats`, `Enum`, `Symbol`, `Types` |
| **Util** (also top-level) | `Util`, `Trove`, `TableUtil`, `StringUtil`, `NumberUtil`, `Debounce`, `Timer`, `Promise`, `Observer`, `StateMachine`, `Spring`, `Queue`, `Cache`, `Input`, `AssetPreloader`, `Log`, `DebugOverlay`, `Sound`, `GuiButton` |

**Typed requires (recommended):** service/controller modules already *are*
the singleton. Prefer `require(path.to.DataService)` over
`Framework.GetService("DataService")` so Luau infers methods without casts.

> **Runtime note:** generic call syntax like `CreateDataService<T>({ ... })`
> is type-checker only. At runtime Luau treats `<` as comparison and will
> error. Annotate the result instead: `local svc: Class = Framework.CreateDataService({ ... })`.

---

## Install

### One-command install (recommended)

From this repo, point at any Rojo project (path can be `.` for the current folder):

```powershell
# Windows — from Framework-v2 root
.\install.ps1 C:\path\to\your-game

# Or
.\install.cmd C:\path\to\your-game
```

```bash
# macOS / Linux
chmod +x scripts/install-framework.sh
./scripts/install-framework.sh /path/to/your-game
```

| Mode | Flag | What it does |
|------|------|----------------|
| **wally** (default) | `-Mode wally` | Adds `kiddydevofficial/framework` to `wally.toml`, mounts `Packages` in Rojo, runs `wally install`. |
| **local** | `-Mode local` | Links this repo: Rojo path to `src/Framework`, or Wally `{ path = "..." }` if no project file. |
| **rbxm** | `-Mode rbxm` | Builds `framework.rbxm` into `your-game/vendor/`. |

Requires [Rojo](https://github.com/rojo-rbx/rojo) and, for Wally modes, [Wally](https://github.com/UpliftGames/wally) on your PATH (`aftman install` in this repo installs both). Python 3 is optional but gives more reliable Rojo project patching.

After **wally** / **local** (Wally path):

```lua
local Framework = require(game:GetService("ReplicatedStorage").Packages.Framework)
```

After **local** (Rojo-only mount):

```lua
local Framework = require(game:GetService("ReplicatedStorage").Framework)
```

**Tip:** Add the Framework repo to your PATH or shell profile so you can run install from anywhere:

```powershell
function Install-Framework { & "C:\path\to\Framework-v2\install.ps1" @args }
```

### Wally (manual)

```toml
# wally.toml
[dependencies]
Framework = "kiddydevofficial/framework@^0.4.0"
```

The framework is self-contained — it has no external dependencies.

Then in code:

```lua
local Framework = require(game:GetService("ReplicatedStorage").Packages.Framework)
```

### Rojo (manual)

The repo's `default.project.json` mounts the framework at `ReplicatedStorage.Framework` for development. Drop `src/Framework/` anywhere under `ReplicatedStorage` in your own project and require it.

```lua
local Framework = require(game:GetService("ReplicatedStorage").Framework)
```

### Distribution-only build

```bash
rojo build package.project.json -o framework.rbxm
```

Produces a single `.rbxm` containing only the framework, ready to drag into Studio (or use `.\install.ps1 -Mode rbxm <project>`).

---

## Modular subsystem

### Service (server singleton)

A service is just a table. The framework calls every lifecycle hook with
`self` bound to that same table — no metatables, no inheritance.

```lua
local Framework = require(ReplicatedStorage.Framework)

local PlayerService = Framework.CreateService({
    Name = "PlayerService",
    Dependencies = { "DataService" },
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

function PlayerService:Stop() end

return PlayerService
```

### Controller (client singleton)

Same API as Service. Loader only runs it when `RunService:IsClient()`.

```lua
local HudController = Framework.CreateController({
    Name = "HudController",
    Dependencies = { "InputController" },
})

function HudController:Init() end
function HudController:Start() end
function HudController:RenderStep(dt: number) end

return HudController
```

### Component (per-Instance, CollectionService-driven)

Each tagged `Instance` gets its own lightweight component table. The
framework presets `self.Instance` and routes method lookups to the
definition for you.

**Folder convention:** place modules under `ReplicatedStorage.Shared.Components`
and call `Framework.AddComponents(thatFolder)`. The loader stamps each
returned table automatically: `Name` defaults to the `ModuleScript` name,
`Tag` defaults to `Name` when omitted. You can return a plain table with
only `Tag` set — no need to call `CreateComponent` yourself.

```lua
-- src/shared/Components/Turret.luau
local Turret = {
    Tag = "Turret",
    -- Ancestor = workspace,                       -- optional
    -- Predicate = function(inst) return ... end,  -- optional
}

function Turret:Construct()
    -- self.Instance is preset by the framework
    self.lastFired = 0
end

function Turret:Start() end
function Turret:Heartbeat(dt: number) end
function Turret:Stop() end

return Turret
```

Manual registration still works:

```lua
local Turret = Framework.CreateComponent({
    Name = "Turret",
    Tag = "Turret",
})
```

`Options`:

| Field | Description |
| --- | --- |
| `Name: string` | Unique component identifier (defaults to module name when scanned). |
| `Tag: string` | CollectionService tag (defaults to `Name`). |
| `Ancestor: Instance?` | Restrict to descendants of this Instance. |
| `Predicate: (Instance) -> boolean?` | Per-Instance filter. |

#### Shipped example components

| Component | Tag | Notes |
| --- | --- | --- |
| `ExampleComponent` | `ExampleComponent` | Starter template; no gameplay logic. |
| `SpinModel` | `SpinModel` | Rotates a tagged `Model` or `BasePart` on local Y. Optional `SpinSpeed` attribute (degrees/sec, default `45`; negative reverses). |

```lua
-- Studio: tag a Model/BasePart with "SpinModel", set SpinSpeed = 120 if desired.
local spin = Framework.GetComponentInstance("SpinModel", workspace.Sign)
```

### Dependencies

`Dependencies` is a list of service / controller names that must finish
`Init` before this one starts. The loader topologically sorts and raises
a clear error on cyclic dependencies.

```lua
Framework.CreateService({
    Name = "MyService",
    Dependencies = { "DataService", "InventoryService" },
})
```

### Lifecycle hooks

Services and controllers:

| Hook | When | May yield? |
| --- | --- | --- |
| `Init(self)` | Sequential, in dependency order, before any `Start`. | No. |
| `Start(self)` | Parallel (`task.spawn`), post-init. | Yes. |
| `Heartbeat(self, dt)` | `RunService.Heartbeat`. | No. |
| `Stepped(self, dt)` | `RunService.Stepped` (physics tick). | No. |
| `RenderStep(self, dt)` | `RunService.RenderStepped` (client only). | No. |
| `Stop(self)` | `Framework.Stop()` shutdown. | No. |

Components add a per-instance constructor:

| Hook | When | May yield? |
| --- | --- | --- |
| `Construct(self)` | Right after the per-instance table is created. | No. |
| `Start(self)` | Spawned after `Construct`. | Yes. |
| `Heartbeat(self, dt)` | Every frame while mounted. | No. |
| `Stepped(self, dt)` | Physics tick while mounted. | No. |
| `RenderStep(self, dt)` | Render step (client only) while mounted. | No. |
| `Stop(self)` | Instance unmounted or loader shut down. | No. |

### Bootstrap

```lua
-- Server entry
local Framework = require(ReplicatedStorage.Framework)

Framework.AddServices(script.Parent.Services)
Framework.AddComponents(ReplicatedStorage.Shared.Components)
Framework.Start()
```

```lua
-- Client entry
local Framework = require(ReplicatedStorage.Framework)

Framework.AddControllers(script.Parent.Controllers)
Framework.AddComponents(ReplicatedStorage.Shared.Components)
Framework.Start()
```

`Framework.AddIn(folder)` is a polymorphic shortcut: it requires every
descendant `ModuleScript` and registers each one according to the kind it
returns.

### Accessing services / controllers / components

```lua
local PlayerService    = Framework.GetService("PlayerService")
local HudController    = Framework.GetController("HudController")
local TurretDefinition = Framework.GetComponent("Turret")
local turretForModel   = Framework.GetComponentInstance("Turret", workspace.SomeModel)
local allTurrets       = Framework.GetComponentInstances("Turret")
```

### Lifecycle queries

```lua
Framework.IsStarted()              -- boolean
Framework.OnStart(function() ... end)  -- runs once the loader finishes Start()
Framework.Stop()                   -- tears down connections + calls every Stop hook
```

---

## DataService

The framework ships a built-in DataService with a `leifstout/dataservice`-style
API: a per-player reactive `Data` tree (path reads/writes + change signals) and
a single replication `RemoteEvent`/`RemoteFunction` under
`ReplicatedStorage/_FrameworkDataService`. Persistence is backed by
[MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)
(Apache-2.0), vendored at `src/Framework/Data/ProfileStore.luau`, which provides
session locking, periodic auto-save, reconciliation against your template, the
`BindToClose` flush, and a cross-server message queue. No Wally dependency — the
module is bundled in-tree.

Two adapter factories fold it into the modular lifecycle:

### Server — `Framework.CreateDataService`

```lua
-- src/server/Services/DataService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)
local DataTemplate = require(ReplicatedStorage.Shared.DataTemplate)

type PlayerData = DataTemplate.DataTemplate
type PlayerDataPath = DataTemplate.Path
type PlayerDataArrayPath = DataTemplate.ArrayPath

export type Class = Framework.DataServiceClass<PlayerData, PlayerDataPath, PlayerDataArrayPath>
export type Path = PlayerDataPath

local DataService: Class = Framework.CreateDataService({
    Name = "DataService",
    Template = DataTemplate,
    ProfileStoreIndex = "PlayerData",
    -- UseMock = true,                  -- toggle in Studio
    OnPlayerInit = function(_self, player, data: PlayerData)
        -- seed runtime-only keys before the snapshot replicates
    end,
})

return DataService
```

The returned definition is a regular framework `Service`: `:Init` boots
`DataService.server` with your options, and other services can simply
`Dependencies = { "DataService" }` to be guaranteed it's live before their own
`Init` runs. Convenience pass-throughs are exposed in PascalCase:

```lua
local DataService = require(ServerScriptService.Server.Services.DataService)
-- Paths autocomplete from `Shared.DataTemplate` when you use the typed service module:
local profile  = DataService:WaitForData(player)
local currency = DataService:Get(player, "currency")
DataService:Update(player, "currency", function(c) return c + 100 end)
DataService:Update(player, { "settings", "musicVolume" }, function(v) return math.clamp(v + 0.1, 0, 1) end)
DataService:GetChangedSignal(player, "currency"):connect(function(new) print(new) end)
```

> Signals returned by `:GetChangedSignal`, `:GetIndexChangedSignal`,
> `:GetArrayInsertedSignal` and `:GetArrayRemovedSignal` are framework
> `Signal`s, so listeners use the lowercase `:connect` / `:once` /
> `:disconnect` / `:wait` API.

#### Schema migrations

When you change the shape of saved data after launch, register `Migrations` so
old profiles upgrade on load instead of breaking. It's an ordered list where
migrator `i` upgrades data from version `i-1` to `i`; the target version is
`#Migrations`. A version number is stamped into the data under `DataVersionKey`
(default `_dataVersion`).

```lua
local DataService: Class = Framework.CreateDataService({
    Name = "DataService",
    Template = DataTemplate,
    Migrations = {
        -- v0 -> v1: split "name" into first / last
        function(data)
            local first, last = string.match(data.name or "", "(%S+)%s*(.*)")
            data.firstName, data.lastName, data.name = first or data.name, last, nil
        end,
        -- v1 -> v2: move coins under a wallet table
        function(data)
            data.wallet = { coins = data.coins or 0 }
            data.coins = nil
        end,
    },
})
```

On load the framework reads the stored version (a profile saved before you
added versioning counts as `0`) and runs every outstanding migrator up to the
target, **before** ProfileStore's template reconcile — so migrations reshape
the old data first and reconcile then fills in any newly-added template
defaults. New players start already at the target version (a fresh profile is a
copy of the template, which the framework stamps at init), so they skip
migration entirely. A migrator that errors is logged and aborts that profile's
run at the last version that succeeded.

### Typed paths from `DataTemplate`

`export type DataTemplate` in `src/shared/DataTemplate.luau` drives compile-time
paths on `DataService` / `DataController`. Prefer `require`ing your typed service
module (see above) so Luau infers `T` from `Template`:

| Helper | Purpose |
| --- | --- |
| `DataTemplate.Path` | Union of valid top-level keys and array path segments from your schema |
| `DataTemplate.ArrayPath` | Paths to array fields (for `:ArrayInsert` / `:ArrayRemove`) |
| `Framework.AnyDataPath` | Broad fallback (`string | { string | number }`) for untyped services |

On the client, pass `Template = DataTemplate` into `CreateDataController` (same
table as the server) so paths match. Luau currently cannot derive exact
ordered tuple paths from a table type, so `DataTemplate.Path` is the supported
schema-owned annotation for path autocomplete.

`OnPlayerInit` lets you seed runtime-only keys before the snapshot ships to the
client (see the shipped `DataService` for an example):

```lua
Framework.CreateDataService({
    Template = DataTemplate,
    OnPlayerInit = function(_self, player, data)
        local extended = data :: any
        extended.stats = extended.stats or { joinCount = 0 }
        extended.stats.joinCount += 1
    end,
})
```

### Client — `Framework.CreateDataController`

```lua
-- src/client/Controllers/DataController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)
local DataTemplate = require(ReplicatedStorage.Shared.DataTemplate)

type PlayerData = DataTemplate.DataTemplate
type PlayerDataPath = DataTemplate.Path
type PlayerDataArrayPath = DataTemplate.ArrayPath

export type Class = Framework.DataControllerClass<PlayerData, PlayerDataPath, PlayerDataArrayPath>
export type Path = PlayerDataPath

return Framework.CreateDataController({
    Name = "DataController",
    Template = DataTemplate,   -- same table as the server for path typing
})
```

`DataService.client:init` yields until the server pushes the initial snapshot,
so the adapter runs it in `:Start` (where yielding is permitted). Other
controllers should depend on this one and `:WaitForData()` if they need to be
fully defensive:

```lua
local Data = require(StarterPlayerScripts.Client.Controllers.DataController)
Data:WaitForData()
print("currency:", Data:Get("currency"))
Data:GetChangedSignal("currency"):connect(function(value)
    print("currency replicated:", value)
end)
```

### Direct access to the underlying module

For advanced use the raw module is available as `Framework.DataService`,
exposing the same `{ server, client }` shape as the upstream package:

```lua
Framework.DataService.server:get(player, "currency")
Framework.DataService.client:getChangedSignal({ "settings", "musicVolume" })
    :connect(function(volume) ... end)
```

### Cross-server messaging

Because persistence is backed by ProfileStore, the `addGlobalCallback` /
`sendGlobalMessage` pair is fully functional (it bridges ProfileStore's
`MessageAsync` / `MessageHandler` queue):

```lua
local Data = require(ServerScriptService.Server.Services.DataService)

-- Register on every server that should react to the message.
Data:AddGlobalCallback("GiftGems", function(player, payload)
    Data:Update(player, "currency", function(c) return c + payload.amount end)
    return true   -- return true to consume the message from the queue
end)

-- Send from anywhere (any server). Delivered now if the target is online,
-- or queued until their next session if they're offline.
Data:SendGlobalMessage("GiftGems", targetUserId, { amount = 500 })
```

### Storage backend

  * Profiles live in `DataStoreService` under the name given by
    `ProfileStoreIndex` (default `"PlayerData"`), keyed by
    `<ProfileStoreDataPrefix><UserId>` (default prefix `"PLAYER_"`).
  * Session locking, periodic auto-save, template reconciliation and the
    `BindToClose` save flush are all handled by ProfileStore. While a session
    is starting, the framework passes a `Cancel` guard so the attempt is
    abandoned if the player leaves; if the session ultimately can't be started
    the player is kicked with *"Profile load failed (please rejoin)"*.
  * `Set` / `Update` / `ArrayInsert` / `ArrayRemove` mutate `Profile.Data`
    in place, so ProfileStore persists them on its next auto-save (or on
    session end) — no manual save call needed.
  * `UseMock = true` routes everything through `ProfileStore.Mock`
    (an in-memory store), which is what you want in Studio with API services
    disabled.

### Advanced ProfileStore features

ProfileStore also offers versioned reads (`:GetAsync` / `:VersionQuery`),
`RobloxMetaData`, `LastSavedData` (for receipt handling), and more. These aren't
surfaced through the adapter today; to use them, extend the thin adapter in
`src/Framework/Data/Profile.luau` (which wraps each ProfileStore profile) and
`src/Framework/Data/Server.luau`. `DataService:GetProfile(player)` returns the
framework profile wrapper, whose `.Data` is the same table ProfileStore saves.

---

## Leaderstats

Server-only service that mirrors selected `DataService` paths into each
player's `leaderstats` folder. Values update automatically when data is
**set**, **updated**, or **changed** through `DataService`.

Configure entries in `src/shared/Leaderstats.luau`:

```lua
Leaderstats.Entries = {
    { Path = "currency", Name = "Coins", Class = "IntValue" },
    { Path = "level", Name = "Level", Class = "IntValue" },
    { Path = "xp", Name = "XP", Class = "IntValue" },
}
```

```lua
-- src/server/Services/LeaderstatsService.luau
local DataService = require(ServerScriptService.Server.Services.DataService)
local LeaderstatsConfig = require(ReplicatedStorage.Shared.Leaderstats)

return Framework.CreateLeaderstatsService({
    Name = "LeaderstatsService",
    Entries = LeaderstatsConfig.Entries,
    DataService = DataService,
})
```

When a profile loads, the service waits for `DataService:WaitForData(player)`,
creates the leaderstat instances, sets initial values, then listens to
`DataService:GetChangedSignal(player, path)` for each configured entry.

`Class` is optional — it defaults to `IntValue`, `NumberValue`, or
`StringValue` based on the current value type.

---

## GlobalSignals

Shared in-process signal banks for scripts running in the same server/client
VM. Use this when multiple modules need to publish/listen to lightweight Lua
events without passing signal objects around.

This is **not** a RemoteEvent layer and does not cross the client/server
boundary. Use `Networking` for remotes and `GlobalMessaging` for cross-server
MessagingService topics.

```lua
-- src/shared/Signals/GameSignals.luau
local GlobalSignals = require(ReplicatedStorage.Framework).GlobalSignals
local Bank = GlobalSignals.Bank("Game")

export type PlayerStateArgs = {
    player: Player,
    state: string,
}

return {
    RoundStarted = Bank:Signal("RoundStarted") :: GlobalSignals.Signal<string>,
    PlayerStateChanged = Bank:Signal("PlayerStateChanged") :: GlobalSignals.Signal<PlayerStateArgs>,
}
```

```lua
local Signals = require(ReplicatedStorage.Shared.Signals.GameSignals)

Signals.RoundStarted:connect(function(mapName)
    print("round started", mapName)
end)

Signals.RoundStarted:fire("Arena")
```

`GlobalSignals.Bank("Name")` and `Bank:Signal("Name")` are idempotent, so
every script requiring the same shared signal bank receives the same signal
object. For quick one-off use, `GlobalSignals.Signal("Name")` uses a default
bank.

---

## Networking

Typed remotes grouped into **banks**. Define a shared module once, require it
on server and client. Runtime `Folder` / remote `Instance` names are
deterministically obfuscated from `game.GameId` / `game.PlaceId` (values that
replicate identically to server and client), while code continues to use the
logical bank and packet names.

```lua
-- src/shared/Networks/PlayerNet.luau
local Networking = require(ReplicatedStorage.Framework).Networking
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
Net.GetSnapshot:OnServerInvoke(function(player, _args) return {} end)

-- Client
Net.UpdateField:FireServer({ Field = "currency", Value = 100 })
local snap = Net.GetSnapshot:InvokeServer(nil)
```

Packet kinds: `Bank:Event` (reliable `RemoteEvent`), `Bank:UnreliableEvent`
(`UnreliableRemoteEvent`), `Bank:Request` (`RemoteFunction`).

### Traffic stats — `Networking.Stats`

Opt-in counters that every packet reports to. They count **logical packet
operations** (one `FireServer` / `FireAllClients` / `InvokeServer` out, one
handler invocation in) rather than bytes — Roblox gives no cheap per-packet
size, but call volume is what flags a remote firing far too often. When
disabled (the default), `record` is a single boolean check, so the hot path
stays cheap. [`DebugOverlay`](#debugoverlay) drives this automatically.

```lua
local Stats = Framework.Networking.Stats

Stats.setEnabled(true)
-- ...play for a bit...
local snap = Stats.snapshot()           -- { enabled, outgoing, incoming, perPacket }
print(snap.outgoing, snap.incoming)     -- totals since last reset
for key, packet in snap.perPacket do
    print(key, packet.outgoing, packet.incoming)   -- key is "Bank.Packet"
end
Stats.reset()                           -- zero counters (call on an interval for a rate)
```

---

## Monetization

Framework-native `MarketplaceService` layer: developer products
(`ProcessReceipt` handlers), game passes (with join/purchase grant handlers),
experience subscriptions, and purchase signals. No Wally deps. Subscription
APIs mirror
[Roblox subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions).

### Product & game pass lists

Define catalog entries once under `src/shared/Lists/`. `MonetizationService`
registers every entry on `Init`:

| Module | Fields | Handler |
| --- | --- | --- |
| `Lists/Products.luau` | `id`, `name`, `tag?` | `(player, receipt) -> boolean` — return `true` once the grant is persisted |
| `Lists/GamePasses.luau` | `id`, `name`, `tag?` | `(player) -> ()` — idempotent; runs on purchase **and** when a player joins if they already own the pass |

Both modules expose `GetByName`, `GetByTag`, `GetById`, and `GetAll*`
helpers. Look up entries from client UI via `require(ReplicatedStorage.Shared.Lists.Products)`
(read-only metadata; handlers only run on the server).

```lua
-- src/shared/Lists/Products.luau
Products.Products = {
    {
        id = 112213,
        name = "Starter Pack",
        tag = "starter_pack",
        handler = function(player, receipt)
            return true   -- grant + persist before returning true
        end,
    },
}

-- src/shared/Lists/GamePasses.luau
GamePasses.GamePasses = {
    {
        id = 987654,
        name = "VIP",
        tag = "vip",
        handler = function(player)
            -- grant VIP perks (safe to run again on rejoin)
        end,
    },
}
```

### Server — `Framework.CreateMonetizationService`

The shipped `MonetizationService` boots the framework layer and auto-registers
every list entry:

```lua
-- src/server/Services/MonetizationService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)
local Lists = ReplicatedStorage.Shared.Lists
local Products = require(Lists.Products)
local GamePasses = require(Lists.GamePasses)
local Players = game:GetService("Players")

export type Class = Framework.MonetizationServiceClass

local MonetizationService: Class = Framework.CreateMonetizationService({
    Name = "MonetizationService",
})

local baseInit = MonetizationService.Init

function MonetizationService:Init()
    baseInit(self)

    for _, product in Products.GetAllProducts() do
        self:RegisterProduct(product.id, product.handler)
    end

    for _, gamePass in GamePasses.GetAllGamePasses() do
        self:RegisterGamePass(gamePass.id, gamePass.handler)
    end

    -- Players already in the server before Init finishes
    for _, player in Players:GetPlayers() do
        self:GrantRegisteredGamePassesForPlayer(player)
    end
end

return MonetizationService
```

Manual registration still works alongside (or instead of) the lists:

```lua
local Monetization = require(ServerScriptService.Server.Services.MonetizationService)

Monetization:RegisterProduct(123456, function(player, receipt) return true end)
Monetization:RegisterGamePass(987654, function(player) ... end)
Monetization:PromptProductPurchase(player, 123456)
Monetization:PromptGamePassPurchase(player, 987654)
if Monetization:OwnsGamePass(player, 987654) then ... end

Monetization.ProductPurchased:connect(function(player, productId) ... end)
Monetization.GamePassPurchased:connect(function(player, gamePassId) ... end)
```

**Game pass handlers** run when:

1. A registered pass is purchased in-session (`PromptGamePassPurchaseFinished`).
2. A player joins (`PlayerAdded`) — any registered pass they already own.
3. You call `GrantRegisteredGamePassesForPlayer(player)` explicitly.

Keep handlers **idempotent** (check data flags before granting) so rejoins
don't double-award perks.

**Subscriptions (server)** — status, details, payment history, prompts, and
`Players.UserSubscriptionStatusChanged` (via `SubscriptionStatusChanged` + per-id handlers):

```lua
local SUBSCRIPTION_ID = "your-subscription-id"

Monetization:RegisterSubscription(SUBSCRIPTION_ID, function(player, id, status)
    if status.IsSubscribed then
        -- grant VIP
    end
end)

local status = Monetization:GetUserSubscriptionStatus(player, SUBSCRIPTION_ID)
-- status.IsSubscribed, status.IsRenewing

Monetization:PromptSubscriptionPurchase(player, SUBSCRIPTION_ID)
Monetization:PromptCancelSubscription(player, SUBSCRIPTION_ID)

Monetization.SubscriptionStatusChanged:connect(function(player, id, status) ... end)
```

### Client — `Framework.CreateMonetizationController`

```lua
return Framework.CreateMonetizationController({ Name = "MonetizationController" })
```

```lua
local Monetization = require(StarterPlayerScripts.Client.Controllers.MonetizationController)
Monetization:PromptGamePassPurchase(987654)
Monetization.GamePassPurchaseFinished:connect(function(id, purchased) ... end)

Monetization:PromptSubscriptionPurchase(SUBSCRIPTION_ID)
Monetization:GetSubscriptionProductInfo(SUBSCRIPTION_ID) -- localized price (client-only)
Monetization.SubscriptionPurchaseFinished:connect(function(id, didTryPurchasing) ... end)
```

### Direct access

```lua
local Monetization = require(ReplicatedStorage.Framework).Monetization
Monetization.server:init()
Monetization.server:registerProduct(123456, handler)
Monetization.server:registerGamePass(987654, function(player) ... end)
Monetization.client:init()
Monetization.client:promptGamePassPurchase(987654)
Monetization.server:getUserSubscriptionStatus(player, SUBSCRIPTION_ID)
Monetization.client:getSubscriptionProductInfo(SUBSCRIPTION_ID)
```

---

## GlobalMessaging

Server-only wrapper around Roblox [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService)
for cross-server topics. Delivery is **best-effort** (not guaranteed); design handlers so
missed messages are non-critical. Payloads must stay under **1 KB**. Topics are **1–80
characters** after any prefix.

By default the server prepends `G_<gameId>_` to every topic so names stay scoped to your
experience. Override with `TopicPrefix` in `CreateGlobalMessagingService`.

### Banks (recommended)

Mirrors [`Networking.Bank`](src/Framework/Networking/Bank.luau): define topics once in a
shared module, require on any server that needs them.

```lua
-- src/shared/Messaging/ExampleGlobalNet.luau
local GlobalMessaging = require(ReplicatedStorage.Framework).GlobalMessaging
local Bank = GlobalMessaging.Bank("Example")

export type GiftPayload = { userId: number, amount: number }

return {
    Gift = Bank:Event("Gift") :: Framework.GlobalMessageTopic<GiftPayload>,
}
```

Resolved MessagingService topic: `G_<gameId>_Example_Gift` (prefix + bank + event).

```lua
local Net = require(ReplicatedStorage.Shared.Messaging.ExampleGlobalNet)

Net.Gift:Subscribe(function(message)
    print(message.Data.userId, message.Sent)
end)

Net.Gift:Publish({ userId = 12345, amount = 100 })
Net.Gift:Unsubscribe()
```

`Bank:Event` is idempotent (same bank + name returns the same topic handle). Banks are
**server-only** — requiring them on the client will error if you call `:Publish` /
`:Subscribe`.

### Server — `Framework.CreateGlobalMessagingService`

```lua
-- src/server/Services/GlobalMessagingService.luau
local Framework = require(ReplicatedStorage.Framework)

export type Class = Framework.GlobalMessagingServiceClass

return Framework.CreateGlobalMessagingService({
    Name = "GlobalMessagingService",
    -- TopicPrefix = "MyGame_",   -- optional; default G_<gameId>_
})
```

```lua
local GlobalMessaging = require(ServerScriptService.Server.Services.GlobalMessagingService)

-- Subscribe once (re-subscribing the same topic replaces the prior listener).
local disconnect = GlobalMessaging:Subscribe("gift", function(message)
    -- message.Data — your payload table
    -- message.Sent — unix time (seconds) when published
    local payload = message.Data
end)

-- Publish to every server subscribed to this topic (yields until accepted by backend).
GlobalMessaging:Publish("gift", { userId = 12345, amount = 100 })

GlobalMessaging:Unsubscribe("gift")
disconnect()   -- same as Unsubscribe when returned from Subscribe

print(GlobalMessaging:ResolveTopic("gift"))  -- full topic string sent to MessagingService
```

Other services should list `Dependencies = { "GlobalMessagingService" }` and subscribe in
their own `:Init` after the messaging service has booted.

### Direct access

```lua
local GlobalMessaging = require(ReplicatedStorage.Framework).GlobalMessaging
GlobalMessaging.server:init()
GlobalMessaging.server:subscribe("MyBank_MyEvent", function(message) ... end)
GlobalMessaging.server:publish("MyBank_MyEvent", { hello = true })

local Bank = GlobalMessaging.Bank("MyBank")
local Topic = Bank:Event("MyEvent") :: GlobalMessaging.Topic<{ hello: boolean }>
Topic:Publish({ hello = true })
```

### vs DataService global messages

`DataService` also exposes `AddGlobalCallback` / `SendGlobalMessage` for **per-player**
queues backed by ProfileStore (ideal for offline gifts tied to a user id). Use
**GlobalMessaging** when you need arbitrary broadcast topics between live servers
(events, announcements, live ops) without routing through player profiles.

---

## FFlags

Global runtime flags / shared values synchronized across live servers through
`GlobalMessaging`. Use them for live toggles, event multipliers, temporary
maintenance switches, or server-only config that can change without restarting.

FFlags are **server-owned** and **non-persistent**: every server starts from
`Shared/FFlags.luau`, then runtime `Set` / `Remove` calls propagate to other
live servers through a `GlobalMessaging.Bank("FFlags")` topic. Clients receive
a read-only snapshot and live updates through internal framework networking.

```lua
-- src/shared/FFlags.luau
return {
    DoubleXP = false,
    MaintenanceMode = false,
    EventMultiplier = 1,
    MessageOfTheDay = "",
}
```

```lua
-- src/server/Services/FFlagsService.luau
local Framework = require(ReplicatedStorage.Framework)
local Defaults = require(ReplicatedStorage.Shared.FFlags)

return Framework.CreateFFlagsService({
    Name = "FFlagsService",
    Defaults = Defaults,
})
```

`CreateFFlagsService` depends on `GlobalMessagingService` by default, so the
messaging subscription is live before flags initialize.

### Server

```lua
local FFlags = require(ServerScriptService.Server.Services.FFlagsService)

if FFlags:Get("DoubleXP") == true then
    -- award double XP
end

FFlags:Observe("MaintenanceMode", function(value, oldValue, source)
    print("Maintenance changed:", oldValue, "->", value, source)
end)

FFlags:Set("EventMultiplier", 2)      -- local immediately, then all live servers
FFlags:Remove("MessageOfTheDay")      -- removes across live servers
FFlags:SetLocal("DoubleXP", true)     -- current server only; no broadcast
```

### Client (read-only)

```lua
-- src/client/Controllers/FFlagsController.luau
return Framework.CreateFFlagsController({ Name = "FFlagsController" })
```

```lua
local FFlags = require(StarterPlayerScripts.Client.Controllers.FFlagsController)

FFlags:WaitForReady()

if FFlags:Get("MaintenanceMode") == true then
    -- update UI
end

FFlags:Observe("EventMultiplier", function(value, oldValue, source)
    print("Multiplier changed:", oldValue, "->", value, source)
end)
```

Client methods are read-only: `Get`, `GetAll`, `Observe`, `Changed`, `WaitForReady`, and `IsReady`. Writes must go
through the server service.

Raw access is available as `Framework.FFlags.server` / `Framework.FFlags.client`
with camelCase methods (`:get`, `:set`, `:observe`, etc.).

---

## Util

Re-exported on `Framework` and grouped under `Framework.Util`.

| Module | Purpose |
| --- | --- |
| `Trove` | Connection/instance cleanup (`add`, `connect`, `destroy`). |
| `TableUtil` | Deep copy, merge, diff helpers. |
| `StringUtil` | String formatting / parsing helpers. |
| `NumberUtil` | Clamping, lerping, rounding helpers. |
| `Debounce` | Leading/trailing debounce for callbacks. |
| `Timer` | Heartbeat-driven timers with pause/resume. |
| `Promise` | Lightweight promise type for async flows. |
| `Observer` | Typed observable value (`set`, `observe`, `Changed` signal). |
| `StateMachine` | Shared finite state machine + per-key `group` (see below). |
| `Spring` | Physics spring for `number` / `Vector2` / `Vector3` (camera, UI, recoil). |
| `Queue` | Generic FIFO queue with amortized O(1) `push` / `pop`. |
| `Cache` | Generic cache with optional LRU capacity + TTL expiry. |
| `Input` | Device-agnostic action map: bind/rebind named actions, `isDown`, device tracking. |
| `AssetPreloader` | `Promise`-based `ContentProvider:PreloadAsync` wrapper with progress signals. |
| `Log` | Leveled, tagged logging with global/per-tag levels and optional FFlag gating. |
| `DebugOverlay` | On-screen FPS / frame-time + remote-traffic HUD, gatable behind an FFlag. |
| `Sound` | Library-folder sound handler: play by name (2D / positional / on-instance), groups + volume. |
| `GuiButton` | Hover/press tweens + sounds for GUI tagged `Button`. Optional `SizeFactor` attribute. |

```lua
local Trove = Framework.Trove
local master = Trove.new()
master:add(workspace.ChildAdded:Connect(...))

Framework.GuiButton.bindTagged()  -- all CollectionService "Button" tags
```

---

## StateMachine

A shared, type-first finite state machine. Identical on server and client for
any mechanic where an entity is always in exactly one state and only certain
transitions are legal. Each machine carries a typed, mutable `data` payload,
fires a `Changed` signal, and exposes per-state `onEnter` / `onExit` hooks.
Reachable as `Framework.StateMachine`.

```lua
local StateMachine = Framework.StateMachine

type MechanicData = { ticks: number }

local fsm = StateMachine.new({
    initial = "Idle",
    data = { ticks = 0 } :: MechanicData,
    states = {
        Idle     = { transitions = { "Active" } },
        Active   = {
            transitions = { "Idle", "Cooldown" },
            onEnter = function(ctx) ctx.data.ticks += 1 end,
        },
        Cooldown = { transitions = { "Idle" } },
    },
})

fsm:transition("Active")   -- legal only when allowed; returns false otherwise
fsm:force("Cooldown")      -- bypass source whitelist + guard
fsm:can("Active")          -- preview without transitioning
fsm:update(dt)             -- run current state's onUpdate
fsm:destroy()
```

| Method | Purpose |
| --- | --- |
| `new(config)` | Create a machine; enters `initial` (`onEnter` with `from = nil`). |
| `get` / `is` / `getData` | Read current state and shared payload. |
| `can(to)` | Whether `transition(to)` would currently succeed. |
| `transition(to)` | Legal transition (source whitelist + target `guard`). |
| `force(to)` | Transition ignoring whitelist + guard (still runs hooks). |
| `update(dt)` | Run the current state's `onUpdate(data, dt)`. |
| `onEnter` / `onExit` | Subscribe to a state's entries/exits (returns a `Connection`). |
| `destroy` | Tear down all signals. |

**Per-entity groups** — `StateMachine.group` keeps one machine per key
(`Player`, `Instance`, string id, …), created on demand. Pass a shared
`Config` (each key gets a deep-copied `data` table) or a `builder(key)`:

```lua
local ExampleStates = require(ReplicatedStorage.Shared.StateMachines.ExampleStates)

local group = Framework.StateMachine.group(ExampleStates.config)
-- local group = Framework.StateMachine.group(ExampleStates.build)  -- per-key data

group:transition(player, "Active")
group:force(player, "Cooldown")
RunService.Heartbeat:Connect(function(dt) group:update(dt) end)
Players.PlayerRemoving:Connect(function(p) group:remove(p) end)
```

`Shared/StateMachines/ExampleStates.luau` ships as a copy-paste starter
(Idle / Active / Cooldown).

---

## Spring

Physics-based interpolation — the natural alternative to fixed-duration
tweens for camera follow, UI bounce, recoil, and any value that should
*chase* a moving target. Drive it from a `Heartbeat` / `RenderStep` hook by
calling `:step(dt)`. The integrator is the unconditionally stable
semi-implicit damped harmonic oscillator, so large `dt` spikes never explode.
Works on `number`, `Vector2`, and `Vector3`. Reachable as `Framework.Spring`.

```lua
local Spring = Framework.Spring

-- Spring.new(initial, frequency?, dampingRatio?)
--   frequency    : oscillations/sec; higher = snappier (default 4)
--   dampingRatio : 1 critically damped (no overshoot), <1 bouncy, >1 sluggish (default 1)
local camera = Spring.new(Vector3.zero, 4, 1)
camera:setTarget(Vector3.new(0, 10, 0))

RunService.RenderStepped:Connect(function(dt)
    workspace.CurrentCamera.CFrame = CFrame.new(camera:step(dt))
end)

-- A bouncy UI value:
local scale = Spring.new(1, 6, 0.4)
button.MouseButton1Click:Connect(function()
    scale:impulse(2)   -- kick the velocity for a "pop"
end)
```

| Method | Purpose |
| --- | --- |
| `new(initial, frequency?, dampingRatio?)` | Create a spring resting at `initial`. |
| `step(dt)` | Advance the simulation and return the new value. |
| `getValue` / `getVelocity` / `getTarget` | Read current state. |
| `setTarget(value)` | Set the rest target the spring chases. |
| `setValue(value, settle?)` | Snap the value; `settle = true` also zeroes velocity + target. |
| `setVelocity(value)` | Override the current velocity. |
| `setFrequency(f)` / `setDampingRatio(d)` | Retune at runtime. |
| `impulse(delta)` | Add `delta` to velocity (an instantaneous kick). |
| `isSettled(posEps?, velEps?)` | True once at target and stopped. |

---

## Queue

Generic FIFO queue with amortized O(1) `push` / `pop` — it advances two
indices instead of calling `table.remove`, so dequeuing never shifts the
backing array. Handy for job pipelines, networking backpressure, turn order,
and any "process in arrival order" workload. Reachable as `Framework.Queue`.

```lua
local Queue = Framework.Queue

local jobs = Queue.new()        -- or Queue.new({ "seed1", "seed2" })
jobs:push("a")
jobs:push("b")

print(jobs:size())   -- 2
print(jobs:pop())    -- "a"
print(jobs:peek())   -- "b"

while not jobs:isEmpty() do
    process(jobs:pop())
end
```

| Method | Purpose |
| --- | --- |
| `new(initial?)` | Create a queue, optionally seeded from an array (head first). |
| `push(value)` | Enqueue at the tail. |
| `pop()` | Dequeue and return the head, or `nil` when empty. |
| `peek()` | Return the head without removing it. |
| `size()` / `isEmpty()` | Inspect length. |
| `clear()` | Drop all items. |
| `toArray()` | Snapshot of pending items, head first. |

---

## Cache

Generic in-memory cache with optional **LRU** capacity eviction and optional
**TTL** expiry. Use it to memoize expensive lookups —
`MarketplaceService:GetProductInfo`, group ranks, pathfinding — without
leaking memory or serving stale data forever. Omit both options and it
behaves like a tidy unbounded table. Reachable as `Framework.Cache`.

```lua
local Cache = Framework.Cache

-- maxSize : evict least-recently-used past this many entries
-- ttl     : seconds an entry stays valid (lazy, os.clock based)
local prices = Cache.new({ maxSize = 200, ttl = 60 })

local function priceOf(id: number): number
    local hit = prices:get(id)
    if hit ~= nil then
        return hit
    end
    local info = MarketplaceService:GetProductInfo(id)
    prices:set(id, info.PriceInRobux or 0)
    return prices:get(id) :: number
end
```

| Method | Purpose |
| --- | --- |
| `new(options?)` | Create a cache (`{ maxSize?, ttl? }`). |
| `set(key, value)` | Insert/replace, marking the key most-recently-used. |
| `get(key)` | Live value (refreshes recency), or `nil` if absent/expired. |
| `has(key)` | Presence check without bumping recency. |
| `remove(key)` / `clear()` | Drop one / all entries. |
| `size()` | Count of stored entries. |
| `keys()` | Keys ordered least- to most-recently-used. |

---

## Input

Device-agnostic **action map**. Bind named actions to one or more buttons —
`Enum.KeyCode` for keyboard / gamepad, `Enum.UserInputType` for mouse buttons —
then listen for the action instead of wiring raw `UserInputService` events all
over the place. Rebinding is one call, an action can hold several bindings at
once, and the map tracks the active device so you can swap button prompts.
Client-only in practice (it listens to `UserInputService`); on the server the
signals just stay quiet. Reachable as `Framework.Input`.

```lua
local Input = Framework.Input

local map = Input.new()
map:bind("Jump", { Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
map:bind("Fire", { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 })

map:onBegan("Jump", function()
    character:jump()
end)

-- query state per-frame when you need it
if map:isDown("Fire") then
    weapon:tryShoot()
end

-- player rebinding + KBM / controller swaps
map:rebind("Jump", { Enum.KeyCode.W })
map.DeviceChanged:connect(function(device)
    hud:setPromptStyle(device)        -- "KeyboardMouse" | "Gamepad" | "Touch"
end)

map:destroy()
```

| Method | Purpose |
| --- | --- |
| `new(options?)` | New map. `{ ignoreProcessed? }` (default `true`) skips inputs the engine already consumed. |
| `bind(action, buttons)` | Add bindings for an action (chainable). |
| `rebind(action, buttons)` | Replace every binding for an action (chainable). |
| `unbind(action)` | Drop all bindings for an action. |
| `getBindings(action)` | Cloned list of buttons bound to the action. |
| `isDown(action)` | Whether any button for the action is currently held. |
| `onBegan(action, cb)` / `onEnded(action, cb)` | Connect to one action's press / release; returns a `Connection`. |
| `setEnabled(enabled)` | Toggle the whole map; disabling releases held actions cleanly. |
| `getDevice()` | Current device category. |
| `destroy()` | Disconnect everything and destroy the signals. |

Signals: `Began(action, input)`, `Ended(action, input)`, `DeviceChanged(device)`.

A ready-made `InputController` (`src/client/Controllers/InputController.luau`)
wraps a shared map as a singleton — depend on `"InputController"` (or just
require it) and call `InputController:bind(...)` / `:isDown(...)` from any
controller, no setup needed.

---

## AssetPreloader

`Promise`-based wrapper over `ContentProvider:PreloadAsync`. Hand it `Instance`s
(their asset-bearing properties resolve automatically) or raw content ids, await
the promise, and drive a loading bar off the `Progress` signal. Counts
accumulate across calls, so one preloader can back a whole loading screen.
Reachable as `Framework.AssetPreloader`.

```lua
local AssetPreloader = Framework.AssetPreloader

local loader = AssetPreloader.new()

loader.Progress:connect(function(loaded, total, lastId)
    loadingBar.Size = UDim2.fromScale(loaded / total, 1)
end)

loader:preload({
    ReplicatedStorage.Assets,           -- folder of decals / sounds / meshes
    "rbxassetid://1234567890",
}):andThen(function(count)
    print(`preloaded {count} assets`)
    loadingScreen:hide()
end):catch(warn)

loader:destroy()
```

| Method | Purpose |
| --- | --- |
| `new()` | New preloader with its own running tally. |
| `preload(content)` | Preload a batch; returns `Promise<number>` (assets this call covered). |
| `getProgress()` | Fraction loaded across all calls, `0`..`1` (`1` before anything is queued). |
| `loadedCount()` / `totalCount()` | Cumulative resolved / queued asset counts. |
| `destroy()` | Destroy the signals. |

Signals: `Progress(loaded, total, lastContentId)`, `AssetLoaded(contentId, status)`.

A ready-made `AssetPreloaderController`
(`src/client/Controllers/AssetPreloaderController.luau`) wraps one shared
preloader as a singleton — require it and call `:preload(...)` / connect
`Progress` from anywhere.

---

## Log

Leveled, tagged logging. One logger per system; output is prefixed
`[LEVEL][Tag]` and routed through `print` (trace/debug/info) or `warn`
(warn/error). A global minimum level — with optional per-tag overrides —
decides what actually prints, so `debug` calls can stay in the code and only
light up when you raise the level. Reachable as `Framework.Log`.

```lua
local Log = Framework.Log

local log = Log.new("Combat")
log:info("hit", target.Name, "for", damage)   -- [INFO][Combat] hit Rig for 12
log:debug("internal state", state)             -- hidden unless level <= Debug

Log.setLevel(Log.Level.Debug)                  -- globally show debug and up
Log.setTagLevel("Combat", Log.Level.Trace)     -- but trace just for Combat
```

Levels are ordered numbers: `Trace` (10) < `Debug` (20) < `Info` (30) <
`Warn` (40) < `Error` (50) < `None` (100, mutes everything).

**FFlag-gated verbosity.** `Log` never hard-depends on `FFlags`; it only needs
something exposing `observe(name, handler)`, which both sides of
`Framework.FFlags` provide. The flag value may be a level name (`"debug"`) or a
raw number:

```lua
-- server
Log.useFFlag(Framework.FFlags.server, "LogLevel")
-- client (after the controller is ready)
local unbind = Log.useFFlag(Framework.FFlags.client, "LogLevel")
```

| Method | Purpose |
| --- | --- |
| `new(tag, level?)` | Tagged logger; optional private minimum level. |
| `log/trace/debug/info/warn/error(...)` | Emit at a level (logger methods). |
| `setLevel(level)` / `getLevel()` | Global minimum level. |
| `setTagLevel(tag, level?)` | Per-tag override (`nil` clears). |
| `setSink(fn?)` | Redirect output (e.g. to an overlay / remote collector). |
| `useFFlag(fflags, name)` | Track the global level off an FFlag; returns unsubscribe. |
| `levelFromValue(value)` | Resolve a name/number to a level. |

---

## DebugOverlay

A small on-screen HUD: frame rate / frame time (with the window's worst frame)
plus remote-traffic rate read from [`Networking.Stats`](#networking). Client
-only; the GUI is built lazily on first show. While visible it enables
`Networking.Stats` (and disables it again on hide if it was the one that turned
it on), so you only pay for counting while you're watching. Reachable as
`Framework.DebugOverlay`.

```lua
local DebugOverlay = Framework.DebugOverlay

local overlay = DebugOverlay.new()

-- gate it behind an FFlag for live sessions...
overlay:bindFFlag(Framework.FFlags.client, "ShowDebugOverlay")

-- ...or drive it yourself (e.g. F3 via Framework.Input)
overlay:toggle()
```

| Method | Purpose |
| --- | --- |
| `new(options?)` | `{ refreshInterval?, position? }`; nothing draws until shown. |
| `show()` / `hide()` / `toggle()` | Visibility control. |
| `setVisible(visible)` / `isVisible()` | Set / query visibility. |
| `bindFFlag(fflags, name)` | Show/hide from a boolean FFlag; returns unsubscribe. |
| `destroy()` | Disconnect and tear down the GUI. |

---

## Sound

A small sound handler. Point it at a folder of template `Sound`s — your sound
**library** — then play them by name, as 2D UI sounds, at a world position, or
parented to an instance. Each playback is a clone, so a sound can overlap
itself; non-looping clones clean themselves up when they finish. Volume runs
through lazily-created `SoundGroup`s nested under one master group, so
`setMasterVolume` scales everything. Reachable as `Framework.Sound`.

```lua
local Sound = Framework.Sound

local sfx = Sound.new()
sfx:setLibrary(ReplicatedStorage.Assets.Sounds)   -- folder of Sound templates

sfx:play("Coin")                                   -- 2D one-shot
sfx:play("Theme", { looped = true, group = "Music" })
sfx:playAt("Explosion", hitPosition, { group = "SFX" })   -- Vector3 or BasePart
sfx:playOn("Engine", car.PrimaryPart, { looped = true })

sfx:setGroupVolume("Music", 0.5)
sfx:setMasterVolume(0.8)
sfx:setMuted(true)
```

Lookup is recursive, so a library split into `SFX/` and `Music/` subfolders
still resolves by bare name. `play*` returns the playing clone (or `nil` if the
name/library is missing).

| Method | Purpose |
| --- | --- |
| `new(options?)` | `{ library?, defaultParent?, masterGroupName? }`. |
| `setLibrary(folder)` / `getLibrary()` / `hasLibrary()` | Assign / read the template folder. |
| `get(name)` | The template `Sound` (clone it, or use `play`). |
| `play(name, props?)` | 2D one-shot under `defaultParent` (SoundService). |
| `playOn(name, parent, props?)` | Play parented to an instance (3D falloff). |
| `playAt(name, Vector3 \| BasePart, props?)` | Play at a position (spawns a holder part) or on a part. |
| `stop(sound)` / `stopAll()` | Dispose one / all sounds this player started. |
| `getGroup(name)` / `setGroupVolume(name, v)` | Managed `SoundGroup` under master. |
| `setMasterVolume(v)` / `getMasterVolume()` | Master group volume. |
| `setMuted(muted)` / `isMuted()` | Mute (zeroes master, restores on unmute). |
| `destroy()` | Stop everything and remove the groups. |

`props` accept `volume`, `playbackSpeed`, `looped`, `timePosition`, `soundId`
(override the asset), `group` (managed group name), and `soundGroup` (an explicit
`SoundGroup`, takes priority).

A ready-made `SoundController`
(`src/client/Controllers/SoundController.luau`) wraps one shared handler as a
singleton — it auto-assigns `SoundService.Sounds` on `Init` if present, and any
controller can `SoundController:play("...")` after depending on
`"SoundController"`.

---

## Signal

```lua
local Signal = Framework.Signal

local s: Signal.Signal<string, number> = Signal.new()

local conn = s:connect(function(name, count)
    -- inferred (name: string, count: number)
end)

s:fire("hello", 3)
s:once(function(_, _) end)   -- self-disconnecting
s:wait()                      -- yields current thread; returns fired args
conn:disconnect()
s:destroy()
```

Handlers run on independent threads via `task.spawn` — one handler erroring never blocks the firer or the other listeners.

---

## Types — Option & Result

```lua
local Types = Framework.Types

local opt: Types.Option<number> = Types.Some(42)
if Types.isSome(opt) then ... end
local value = Types.unwrapOr(opt, 0)
local doubled = Types.mapOption(opt, function(n) return n * 2 end)

local r: Types.Result<number, string> = Types.tryCall(function()
    return riskyOp()
end)
if Types.isOk(r) then ... end
local mapped = Types.mapResult(r, function(n) return n + 1 end)
```

---

## Enum

```lua
local Enum = Framework.Enum

local Direction = Enum.create("Direction", { "North", "East", "South", "West" })

print(Direction.North.name)                -- "North"
print(Direction.North.ordinal)             -- 1
print(Direction:fromName("South"))         -- the South EnumValue
print(Direction:fromOrdinal(4))            -- the West EnumValue
print(Direction:contains(Direction.North)) -- true
for _, v in Direction:values() do print(v.name) end
```

Each value is frozen and identity-comparable (`==`).

---

## Symbol

```lua
local Symbol = Framework.Symbol

local PRIVATE_KEY = Symbol.unique("MyModule.private")
local NONE = Symbol.named("None")                -- same identity everywhere
assert(Symbol.named("None") == NONE)             -- true (interned)
assert(Symbol.unique("None") ~= NONE)            -- true (always fresh)
```

---

## Repository layout

```
src/
├── Framework/                        ← the package
│   ├── init.luau                     ← public API surface
│   ├── Signal.luau
│   ├── Symbol.luau
│   ├── Enum.luau
│   ├── Types.luau
│   ├── Data/                         ← player data (server / client / Data tree)
│   │   ├── Profile.luau              ← ProfileStore persistence adapter
│   │   └── ProfileStore.luau         ← vendored MadStudio/ProfileStore
│   ├── GlobalSignals/                ← local shared signal banks
│   ├── Networking/                   ← typed remote banks
│   ├── Monetization/                 ← MarketplaceService wrapper
│   ├── GlobalMessaging/              ← Bank, Topic, MessagingService wrapper
│   │   ├── Bank.luau
│   │   ├── Topic.luau
│   │   └── Manager.luau
│   ├── FFlags/                       ← global shared runtime flags
│   ├── Leaderstats/                  ← DataService → leaderstats sync
│   ├── Adapters/
│   │   ├── Data.luau                 ← CreateDataService / CreateDataController
│   │   ├── Monetization.luau         ← CreateMonetizationService / Controller
│   │   ├── GlobalMessaging.luau      ← CreateGlobalMessagingService
│   │   ├── FFlags.luau               ← CreateFFlagsService / Controller
│   │   └── Leaderstats.luau          ← CreateLeaderstatsService
│   ├── Util/                         ← Trove, Observer, StateMachine, GuiButton, …
│   └── Modular/                      ← Service, Controller, Component, Loader
├── server/                           ← your server code
│   └── Services/
│       ├── DataService.luau              ← typed CreateDataService wrapper
│       ├── MonetizationService.luau      ← auto-registers Lists on Init
│       ├── GlobalMessagingService.luau   ← cross-server MessagingService
│       ├── FFlagsService.luau            ← global shared runtime flags
│       └── LeaderstatsService.luau       ← player leaderstats display
├── client/                           ← your client code
│   └── Controllers/
│       ├── DataController.luau       ← typed CreateDataController wrapper
│       └── FFlagsController.luau     ← read-only client FFlags cache
└── shared/
    ├── Components/                   ← SpinModel, ExampleComponent, …
    ├── FFlags.luau                   ← default runtime flags
    ├── Leaderstats.luau              ← leaderstats entry config
    ├── DataTemplate.luau               ← default profile schema + Path types
    ├── DataTypes.luau                ← re-exports PlayerData / Path aliases
    ├── Lists/                        ← monetization catalogs
    │   ├── Products.luau             ← developer products + receipt handlers
    │   └── GamePasses.luau           ← game passes + grant handlers
    ├── Messaging/                    ← GlobalMessaging banks (cross-server)
    │   └── ExampleGlobalNet.luau     ← starter bank (copy for your topics)
    ├── Signals/                      ← local GlobalSignals banks
    │   └── ExampleSignals.luau       ← starter bank (copy for your events)
    ├── StateMachines/                ← shared FSM definitions
    │   └── ExampleStates.luau        ← starter FSM definition (copy & edit)
    └── Networks/                     ← Networking banks (client + server)
        └── ExampleNet.luau
```

- `default.project.json` — development place, mounts Framework + empty user folders.
- `package.project.json` — library-only, for `rojo build` distribution.
- `wally.toml` — Wally package metadata (`kiddydevofficial/framework`).

---

## Publishing to Wally

Package name: **`kiddydevofficial/framework`** (display name: **Goling's Framework**).

Wally scopes must match your **lowercase GitHub username**. To publish:

```bash
wally login          # authenticate with GitHub account KiddyDevOfficial
wally publish        # from repo root
```

In a game's `wally.toml`:

```toml
[dependencies]
Framework = "kiddydevofficial/framework@^0.4.0"
```

If publish fails with a scope permission error, run `wally login` with the GitHub account **KiddyDevOfficial**.

---

## Development

```bash
rojo serve              # serve dev place to Studio
rojo build              # build the dev place
rojo build package.project.json -o framework.rbxm   # build standalone library
```

Type-checking (requires [`luau-lsp`](https://github.com/JohnnyMorganz/luau-lsp)):

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --platform=roblox src
```

---

*Built and maintained by [KiddyDevOfficial](https://github.com/KiddyDevOfficial).*

***See documentation:*** everything you need is in the sections above — start
with [How does it work?](#how-does-it-work) and the [API overview](#api-overview).

***Get it now on:*** Wally — `kiddydevofficial/framework` (see [Install](#install)),
or grab a standalone `.rbxm` with `rojo build package.project.json`.

Persistence is powered by [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)
by loleris — if it saves you time, go drop them a star too.

---

## License

MIT — see [LICENSE](LICENSE).
