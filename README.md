# Goling's Framework

A type-first, modular framework for Roblox / Luau — no classes, no
inheritance, no abstract methods. Just plain tables with `:Init` / `:Start`
style methods, dependency ordering, frame loops, and a
CollectionService-driven component runtime.

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
  `Timer`, `Promise`, `Observer`, `StateMachine`, `GuiButton`
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
| **Core** | `Signal`, `Networking`, `Enum`, `Symbol`, `Types` |
| **Util** (also top-level) | `Util`, `Trove`, `TableUtil`, `StringUtil`, `NumberUtil`, `Debounce`, `Timer`, `Promise`, `Observer`, `StateMachine`, `GuiButton` |

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
deterministically obfuscated from the server job id, while code continues to
use the logical bank and packet names.

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

## License

MIT — see [LICENSE](LICENSE).
