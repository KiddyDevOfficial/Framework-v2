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
- **Enum** — immutable, comparable enumerations.
- **Symbol** — opaque identity tokens.
- **Types** — `Option<T>`, `Result<T, E>`, helpers.
- **DataService** — persistent, auto-replicated player data built directly
  into the framework (no external dependencies), wrapped as a framework
  `Service` + `Controller` so it boots in dependency order.

Fully `--!strict`. Passes `luau-lsp analyze` with zero warnings.

---

## Install

### Cursor terminal (any new project)

**One-time setup** (from this repo):

```powershell
.\scripts\setup-cursor.ps1
```

Restart the Cursor terminal once. Then open **any** Roblox project in Cursor, open the integrated terminal at the project root, and run:

```text
framework-install
```

That installs into the **current working directory** (your opened workspace). Default mode is `local` (links this repo; no Wally publish needed). Use `framework-install -Mode wally` for the registry package.

You can also run **Tasks: Run Task** → **Install Framework (current project)** (`Ctrl+Shift+P`).

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

```lua
local Turret = Framework.CreateComponent({
    Name = "Turret",
    Tag = "Turret",
    -- Ancestor = workspace,                       -- optional
    -- Predicate = function(inst) return ... end,  -- optional
})

function Turret:Construct()
    -- self.Instance is preset by the framework
    self.lastFired = 0
end

function Turret:Start() end
function Turret:Heartbeat(dt: number) end
function Turret:Stop() end

return Turret
```

`Options`:

| Field | Description |
| --- | --- |
| `Name: string` | Unique component identifier (required). |
| `Tag: string` | CollectionService tag (required). |
| `Ancestor: Instance?` | Restrict to descendants of this Instance. |
| `Predicate: (Instance) -> boolean?` | Per-Instance filter. |

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

The framework ships a built-in DataService modeled after
[`leifstout/dataservice`](https://github.com/leifstout/dataService), but
rewritten on top of the framework's own primitives — `Framework.Signal` for
events, plain `DataStoreService` (with session locking, heartbeat, auto-save
and a Studio mock) for persistence, and a single replication
`RemoteEvent`/`RemoteFunction` under `ReplicatedStorage/_FrameworkDataService`.
Zero external Wally dependencies.

Two adapter factories fold it into the modular lifecycle:

### Server — `Framework.CreateDataService`

```lua
-- src/server/Services/Data.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)
local Template = require(ReplicatedStorage.Shared.DataTemplate)

return Framework.CreateDataService({
    -- Name = "DataService",            -- default
    Template = Template,
    ProfileStoreIndex = "Production",
    -- UseMock = true,                  -- toggle in Studio
})
```

The returned definition is a regular framework `Service`: `:Init` boots
`DataService.server` with your options, and other services can simply
`Dependencies = { "DataService" }` to be guaranteed it's live before their own
`Init` runs. Convenience pass-throughs are exposed in PascalCase:

```lua
local Data = Framework.GetService("DataService")
local profile  = Data:WaitForData(player)
local currency = Data:Get(player, "currency")
Data:Update(player, "currency", function(c) return c + 100 end)
Data:GetChangedSignal(player, "currency"):connect(function(new) print(new) end)
```

> Signals returned by `:GetChangedSignal`, `:GetIndexChangedSignal`,
> `:GetArrayInsertedSignal` and `:GetArrayRemovedSignal` are framework
> `Signal`s, so listeners use the lowercase `:connect` / `:once` /
> `:disconnect` / `:wait` API.

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
-- src/client/Controllers/Data.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)

return Framework.CreateDataController()  -- Name defaults to "DataController"
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

### Storage backend

  * On the server, profiles are stored in `DataStoreService` under the name
    given by `ProfileStoreIndex` (default `"PlayerData"`), keyed by
    `<ProfileStoreDataPrefix><UserId>` (default prefix `"PLAYER_"`).
  * Session locking is implemented via the lock field on each entry plus a
    process-unique session id. If a second server tries to claim a live lock
    that's still being heartbeated, the player is kicked with a
    *"Profile load failed (session locked)"* message so the original session
    keeps ownership.
  * Setting `UseMock = true` (the sample template does this in Studio)
    short-circuits all `DataStoreService` calls to a per-process in-memory
    dictionary, which is what you want when API services are disabled.
  * On `game:BindToClose`, every live profile is end-sessioned (saved and
    unlocked) before the process exits.

### Not supported (vs. ProfileStore upstream)

The built-in implementation is intentionally small. If you need the more
advanced ProfileStore features below, swap `DataPackage` in
`src/Framework/Adapters/Data.luau` for the original Wally package instead:

  * `addGlobalCallback` / `sendGlobalMessage` — surfaced as stubs that
    `error()` if called, since raw DataStores have no built-in message queue.
  * Versioned profile migrations.
  * Mock/real toggle per profile (mock is process-wide here).

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
│   ├── init.luau
│   ├── Signal.luau
│   ├── Symbol.luau
│   ├── Enum.luau
│   ├── Types.luau
│   ├── DataService.luau              ← thin re-export of Data/
│   ├── Data/
│   │   ├── init.luau                 ← { server, client, Data }
│   │   ├── Data.luau                 ← reactive data tree
│   │   ├── Profile.luau              ← DataStore session lock + auto-save
│   │   ├── Networking.luau           ← RemoteEvent / RemoteFunction broker
│   │   ├── Server.luau               ← server singleton
│   │   ├── Client.luau               ← client singleton
│   │   └── Utils.luau                ← shared action enum
│   ├── Adapters/
│   │   └── Data.luau                 ← CreateDataService / CreateDataController
│   └── Modular/
│       ├── init.luau
│       ├── Lifecycle.luau
│       ├── Service.luau
│       ├── Controller.luau
│       ├── Component.luau
│       └── Loader.luau
├── client/      ← your client code
├── server/      ← your server code
└── shared/      ← your shared code
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
