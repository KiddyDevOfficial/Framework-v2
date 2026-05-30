--!strict
--[=[
	@module Types
	Functional utility types: `Option<T>`, `Result<T, E>`, and tagged-union
	helpers. These are POD tables (no metatables) so they replicate cleanly
	through RemoteEvents and serialize through JSON.

	Construct with the helpers (`Some`, `None`, `Ok`, `Err`). Inspect using
	the `is*` predicates and the small map / unwrap utilities.
]=]

local Types = {}

-- Option<T>

export type Option<T> = {
	kind: "Some",
	value: T,
} | {
	kind: "None",
}

function Types.Some<T>(value: T): Option<T>
	return { kind = "Some", value = value }
end

function Types.None<T>(): Option<T>
	return { kind = "None" } :: Option<T>
end

function Types.isSome<T>(opt: Option<T>): boolean
	return opt.kind == "Some"
end

function Types.isNone<T>(opt: Option<T>): boolean
	return opt.kind == "None"
end

--[=[
	Returns the inner value or `default` when the option is `None`.
]=]
function Types.unwrapOr<T>(opt: Option<T>, default: T): T
	if opt.kind == "Some" then
		return opt.value
	end
	return default
end

--[=[
	Returns the inner value or errors with `message` when `None`.
]=]
function Types.expect<T>(opt: Option<T>, message: string): T
	if opt.kind == "Some" then
		return opt.value
	end
	error(message, 2)
end

function Types.mapOption<T, U>(opt: Option<T>, mapper: (T) -> U): Option<U>
	if opt.kind == "Some" then
		return { kind = "Some", value = mapper(opt.value) }
	end
	return { kind = "None" } :: Option<U>
end

-- Result<T, E>

export type Result<T, E> = {
	kind: "Ok",
	value: T,
} | {
	kind: "Err",
	error: E,
}

function Types.Ok<T, E>(value: T): Result<T, E>
	return { kind = "Ok", value = value }
end

function Types.Err<T, E>(err: E): Result<T, E>
	return { kind = "Err", error = err }
end

function Types.isOk<T, E>(r: Result<T, E>): boolean
	return r.kind == "Ok"
end

function Types.isErr<T, E>(r: Result<T, E>): boolean
	return r.kind == "Err"
end

function Types.unwrap<T, E>(r: Result<T, E>): T
	if r.kind == "Ok" then
		return r.value
	end
	error(`unwrap on Err: {tostring((r :: any).error)}`, 2)
end

function Types.mapResult<T, U, E>(r: Result<T, E>, mapper: (T) -> U): Result<U, E>
	if r.kind == "Ok" then
		return { kind = "Ok", value = mapper(r.value) }
	end
	return r :: any
end

function Types.mapErr<T, E, F>(r: Result<T, E>, mapper: (E) -> F): Result<T, F>
	if r.kind == "Err" then
		return { kind = "Err", error = mapper(r.error) }
	end
	return r :: any
end

--[=[
	Wraps a function call in a `Result`. Any error thrown becomes the `Err`.
]=]
function Types.tryCall<T>(fn: () -> T): Result<T, string>
	local ok, value = pcall(fn)
	if ok then
		return { kind = "Ok", value = value :: T }
	end
	return { kind = "Err", error = tostring(value) }
end

-- Generic helpers

--[=[
	Asserts at runtime that `value` is non-nil. Returns it typed as
	non-optional so downstream code can drop the `?`.
]=]
function Types.expectNonNil<T>(value: T?, message: string?): T
	if value == nil then
		error(message or "expected non-nil value", 2)
	end
	return value :: T
end

-- Reserved key for tagging the "type" of a structurally-typed table.
export type Discriminant = string

return Types
