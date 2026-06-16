--!strict
--[=[
	@module Data.Migration
	Schema versioning for persisted player data. You keep an ordered list of
	migrators; migrator `i` upgrades data from version `i-1` to version `i`, so
	the target version is just `#migrations`. A version number is stamped into
	the data under `versionKey` (default `_dataVersion`).

	On load the framework reads the stored version (missing / non-number counts
	as `0` - i.e. a profile saved before you added versioning) and runs every
	migrator from there up to the target, bumping the stamp after each step.
	Migrations run **before** ProfileStore's template reconcile, so they reshape
	the old data first and reconcile then fills in any newly-added template
	defaults.

	```lua
	-- in your DataService options
	Migrations = {
	    -- v0 -> v1: split a single "name" field into first / last
	    function(data)
	        local first, last = string.match(data.name or "", "(%S+)%s*(.*)")
	        data.firstName = first or data.name
	        data.lastName = last
	        data.name = nil
	    end,
	    -- v1 -> v2: coins moved under a wallet table
	    function(data)
	        data.wallet = { coins = data.coins or 0 }
	        data.coins = nil
	    end,
	}
	```

	New players start already at the target version: the framework stamps the
	template with `#migrations` at init, so a fresh profile (a copy of the
	template) needs no migration.
]=]

local Migration = {}

export type Migrator = (data: any) -> ()

export type Config = {
	migrations: { Migrator },
	versionKey: string?,
}

local DEFAULT_VERSION_KEY = "_dataVersion"

export type Result = {
	from: number,
	to: number,
	ran: number,
}

function Migration.keyOf(config: Config): string
	return config.versionKey or DEFAULT_VERSION_KEY
end

--[=[
	The version a fully-migrated profile ends up at - the number of migrators.
]=]
function Migration.targetVersion(config: Config): number
	return #config.migrations
end

local function readVersion(data: any, key: string): number
	local current = data[key]
	if type(current) ~= "number" or current < 0 then
		return 0
	end
	return math.floor(current)
end

--[=[
	Runs the outstanding migrators on `data` in place and updates the version
	stamp. Returns where it started, where it ended, and how many ran. A
	migrator that errors aborts the run at that version (the stamp reflects the
	last step that succeeded) and the error is re-raised to the caller.
]=]
function Migration.run(data: any, config: Config): Result
	assert(type(data) == "table", "[Data.Migration] data must be a table")
	local key = Migration.keyOf(config)
	local target = #config.migrations
	local from = readVersion(data, key)
	local current = from

	while current < target do
		local migrator = config.migrations[current + 1]
		migrator(data)
		current += 1
		data[key] = current
	end

	return { from = from, to = current, ran = current - from }
end

--[=[
	Stamps `template[versionKey]` with the target version unless it's already
	set, so brand-new profiles (copies of the template) start fully migrated.
]=]
function Migration.stampTemplate(template: any, config: Config)
	local key = Migration.keyOf(config)
	if template[key] == nil then
		template[key] = #config.migrations
	end
end

return Migration
