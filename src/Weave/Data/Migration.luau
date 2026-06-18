--!strict
--[=[
	@module Data.Migration
	Schema versioning for persisted player data. Migrator `i` upgrades data
	from version `i - 1` to version `i`; `#migrations` is the target version.
	The version is stored under `versionKey` (default `_dataVersion`).

	Migrations run before ProfileStore reconcile, so old data is reshaped before
	new template defaults are filled in.

	```lua
	Migrations = {
	    function(data)
	        local first, last = string.match(data.name or "", "(%S+)%s*(.*)")
	        data.firstName = first or data.name
	        data.lastName = last
	        data.name = nil
	    end,
	    function(data)
	        data.wallet = { coins = data.coins or 0 }
	        data.coins = nil
	    end,
	}
	```

	New profiles start at the target version because the template is stamped at
	init.
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
	Runs outstanding migrators in place. If one errors, the stamp stays at the
	last successful version and the error is re-raised.
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
	Stamps fresh profiles at the target version.
]=]
function Migration.stampTemplate(template: any, config: Config)
	local key = Migration.keyOf(config)
	if template[key] == nil then
		template[key] = #config.migrations
	end
end

return Migration
