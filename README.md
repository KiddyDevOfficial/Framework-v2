# Framework

A type-first, modular framework for Roblox / Luau — no classes, no
inheritance, no abstract methods. Just plain tables with `:Init` / `:Start`
style methods, dependency ordering, frame loops, and a
CollectionService-driven component runtime.

- **Service** — server singleton with `:Init`, `:Start`, `:Heartbeat`, …
- **Controller** — client singleton, same shape.
- **Component** — per-`Instance` module bound by tag (`:Construct`, `:Start`, `:Stop`, …).
- **Loader** — discovery, dependency-aware bootstrap, lifecycle binding.
- **Signal\<T...\>** — generic, type-safe events.
- **Networking** — typed remote banks (`Event`, `UnreliableEvent`, `Request`).
- **DataService** — persistent, auto-replicated player data backed by a
  vendored [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore),
  via `CreateDataService` / `CreateDataController`.
- **Monetization** — `MarketplaceService` wrapper (products, passes,
  [subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions), receipts),
  via `CreateMonetizationService` / `CreateMonetizationController`.
- **Util** — `Trove`, `TableUtil`, `StringUtil`, `NumberUtil`, `Debounce`,
  `Timer`, `Promise`, `Observer`, `GuiButton` (CollectionService tag `Button`).
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
| **Monetization** | `CreateMonetizationService`, `CreateMonetizationController`, `Monetization` (`{ server, client }`) |
| **Core** | `Signal`, `Networking`, `Enum`, `Symbol`, `Types` |
| **Util** (also top-level) | `Util`, `Trove`, `TableUtil`, `StringUtil`, `NumberUtil`, `Debounce`, `Timer`, `Promise`, `Observer`, `GuiButton` |

**Typed requires (recommended):** service/controller modules already *are*
the singleton. Prefer `require(path.to.DataService)` over
`Framework.GetService("DataService")` so Luau infers methods without casts.

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
| **wally** (default) | `-Mode wally` | Adds `leonardhoarau/framework` to `wally.toml`, mounts `Packages` in Rojo, runs `wally install`. |
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
Framework = "leonardhoarau/framework@^0.3.0"
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
local Template = require(ReplicatedStorage.Shared.DataTemplate)

export type Class = Framework.DataServiceClass

return Framework.CreateDataService({
    Name = "DataService",
    Template = Template,
    ProfileStoreIndex = "PlayerData",
    -- UseMock = true,                  -- toggle in Studio
})
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
client:

```lua
Framework.CreateDataService({
    Template = Template,
    OnPlayerInit = function(self, player, data)
        data.sessionJoinTime = os.time()
    end,
})
```

### Client — `Framework.CreateDataController`

```lua
-- src/client/Controllers/DataController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)

export type Class = Framework.DataControllerClass

return Framework.CreateDataController({ Name = "DataController" })
```

`DataService.client:init` yields until the server pushes the initial snapshot,
so the adapter runs it in `:Start` (where yielding is permitted). Other
controllers should depend on this one and `:WaitForData()` if they need to be
fully defensive:

```lua
local Data = Framework.GetController("DataController")
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
local Data = Framework.GetService("DataService")

-- Register on every server that should react to the message.
Data:AddGlobalCallback("GiftGems", function(player, payload)
    Data:Update(player, "gems", function(g) return g + payload.amount end)
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

## Networking

Typed remotes grouped into **banks**. Define a shared module once, require it
on server and client. Remotes are created under
`ReplicatedStorage._FrameworkNetworking/<BankName>/`.

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
(`ProcessReceipt` handlers), game passes, experience subscriptions, and purchase
signals. No Wally deps. Subscription APIs mirror
[Roblox subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions).

### Server — `Framework.CreateMonetizationService`

```lua
-- src/server/Services/MonetizationService.luau
local Framework = require(ReplicatedStorage.Framework)

local MonetizationService = Framework.CreateMonetizationService({
    Name = "MonetizationService",
})

function MonetizationService:Init()
    -- base Init boots Monetization.server
    self:RegisterProduct(123456, function(player, receipt)
        -- grant consumable; return true once persisted
        return true
    end)
end

return MonetizationService
```

```lua
local Monetization = require(ServerScriptService.Server.Services.MonetizationService)

Monetization:RegisterProduct(123456, function(player, receipt) return true end)
Monetization:PromptProductPurchase(player, 123456)
if Monetization:OwnsGamePass(player, 987654) then ... end

Monetization.ProductPurchased:connect(function(player, productId) ... end)
```

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
local Monetization = Framework.GetController("MonetizationController")
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
Monetization.client:init()
Monetization.client:promptGamePassPurchase(987654)
Monetization.server:getUserSubscriptionStatus(player, SUBSCRIPTION_ID)
Monetization.client:getSubscriptionProductInfo(SUBSCRIPTION_ID)
```

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
| `GuiButton` | Hover/press tweens + sounds for GUI tagged `Button`. Optional `SizeFactor` attribute. |

```lua
local Trove = Framework.Trove
local master = Trove.new()
master:add(workspace.ChildAdded:Connect(...))

Framework.GuiButton.bindTagged()  -- all CollectionService "Button" tags
```

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
│   ├── DataService.luau              ← thin re-export of Data/
│   ├── Data/                         ← player data (server / client / Data tree)
│   │   ├── Profile.luau              ← ProfileStore persistence adapter
│   │   └── ProfileStore.luau         ← vendored MadStudio/ProfileStore
│   ├── Networking/                   ← typed remote banks
│   ├── Monetization/                 ← MarketplaceService wrapper
│   ├── Adapters/
│   │   ├── Data.luau                 ← CreateDataService / CreateDataController
│   │   └── Monetization.luau         ← CreateMonetizationService / Controller
│   ├── Util/                         ← Trove, Observer, GuiButton, …
│   └── Modular/                      ← Service, Controller, Component, Loader
├── client/                           ← your client code
├── server/                           ← your server code
└── shared/
    ├── Components/                   ← SpinModel, ExampleComponent, …
    ├── DataTemplate.luau
    └── Networks/                     ← optional typed remote modules
```

- `default.project.json` — development place, mounts Framework + empty user folders.
- `package.project.json` — library-only, for `rojo build` distribution.
- `wally.toml` — Wally package metadata.

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
