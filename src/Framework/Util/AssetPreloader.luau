--!strict
--[=[
	@module Util.AssetPreloader
	A `Promise`-based wrapper over `ContentProvider:PreloadAsync`. Hand it a
	list of `Instance`s (their asset-bearing properties are resolved
	automatically) or raw content ids, await the promise, and drive a loading
	bar off the `Progress` signal. Counts accumulate across calls, so one
	preloader can back a whole loading screen.

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
]=]

local ContentProvider = game:GetService("ContentProvider")

local Signal = require(script.Parent.Parent.Signal)
local Promise = require(script.Parent.Promise)

type Signal<T...> = Signal.Signal<T...>
type Promise<T> = Promise.Promise<T>

local AssetPreloader = {}
AssetPreloader.__index = AssetPreloader

export type Content = Instance | string

export type Preloader = {
	Progress: Signal<number, number, string>,
	AssetLoaded: Signal<string, Enum.AssetFetchStatus>,
	preload: (self: Preloader, content: { Content }) -> Promise<number>,
	getProgress: (self: Preloader) -> number,
	loadedCount: (self: Preloader) -> number,
	totalCount: (self: Preloader) -> number,
	destroy: (self: Preloader) -> (),
}

--[=[
	New preloader with its own running tally. Reuse it for every batch that
	feeds the same progress bar.
]=]
function AssetPreloader.new(): Preloader
	local self = setmetatable({
		Progress = Signal.new(),
		AssetLoaded = Signal.new(),
		_done = 0,
		_total = 0,
		_destroyed = false,
	}, AssetPreloader)
	return self :: any
end

--[=[
	Preloads `content` and resolves with how many assets this call covered.
	`PreloadAsync` yields, so the work runs on the promise's own thread;
	`Progress` / `AssetLoaded` fire as each asset lands. A failure in
	`PreloadAsync` rejects the promise rather than erroring out.
]=]
function AssetPreloader.preload(self: Preloader, content: { Content }): Promise<number>
	local s: any = self
	return Promise.new(function(resolve, reject)
		assert(not s._destroyed, "[AssetPreloader] cannot preload on a destroyed preloader")
		local count = #content
		if count == 0 then
			resolve(0)
			return
		end
		s._total += count
		local covered = 0
		local ok, err = pcall(function()
			-- `content` may include raw content-id strings, which PreloadAsync
			-- accepts at runtime even though its typed signature is `{Instance}`.
			ContentProvider:PreloadAsync(content :: any, function(contentId: string, status: Enum.AssetFetchStatus)
				covered += 1
				s._done += 1
				s.AssetLoaded:fire(contentId, status)
				s.Progress:fire(s._done, s._total, contentId)
			end)
		end)
		if ok then
			resolve(covered)
		else
			reject(tostring(err))
		end
	end)
end

--[=[
	Fraction loaded across every `preload` call, `0`..`1`. Returns `1` before
	anything has been queued.
]=]
function AssetPreloader.getProgress(self: Preloader): number
	local s: any = self
	if s._total == 0 then
		return 1
	end
	return s._done / s._total
end

function AssetPreloader.loadedCount(self: Preloader): number
	return (self :: any)._done
end

function AssetPreloader.totalCount(self: Preloader): number
	return (self :: any)._total
end

function AssetPreloader.destroy(self: Preloader)
	local s: any = self
	if s._destroyed then
		return
	end
	s._destroyed = true
	s.Progress:destroy()
	s.AssetLoaded:destroy()
end

return AssetPreloader
