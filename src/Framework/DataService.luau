--!strict
--[=[
	@module DataService
	Re-exports the framework's built-in `Data` subsystem under the
	historical `Framework.DataService` name. The actual implementation
	lives in `src/Framework/Data/` and has no external Wally
	dependencies - see `Data/init.luau` for the entry shape.
]=]

return require(script.Parent.Data)
