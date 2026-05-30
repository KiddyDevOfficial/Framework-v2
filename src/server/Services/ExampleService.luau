--!strict
--[=[
	@service ExampleService
	Starter service showing the framework lifecycle on the server. Return a
	plain table; the Loader stamps it and registers it by its ModuleScript
	name. Delete or copy this file to start your own services.

	Lifecycle (all optional): `Init` -> `Start` -> `Heartbeat` / `Stepped`.
	`Init` runs for every service first (dependency order), then `Start`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local ExampleService = {
	Dependencies = {} :: { string },
}

function ExampleService:Init()
	-- Boot the built-in monetization layer (ProcessReceipt, prompts, ...).
	Framework.Monetization.server:init()

	-- Example: grant a consumable for developer product 0 (replace the id).
	Framework.Monetization.server:registerProduct(0, function(_player, _receipt)
		-- grant the product, then return true once the grant is persisted.
		return true
	end)
end

function ExampleService:Start()
	print("[ExampleService] started on the server.")
end

return ExampleService
