--!strict
--[=[
	@controller AssetPreloaderController
	Singleton wrapper around `Weave.Util.AssetPreloader` - one shared
	preloader for the whole client. Feed it batches of assets, watch `Progress`
	to drive a loading bar. Counts accumulate across calls, so a loading screen
	can preload in several passes and still show one combined bar.

	```lua
	local AssetPreloader = require(script.Parent.AssetPreloaderController)

	AssetPreloader.Progress:connect(function(loaded, total)
	    loadingBar.Size = UDim2.fromScale(loaded / total, 1)
	end)

	AssetPreloader:preload({
	    ReplicatedStorage.Assets,
	    "rbxassetid://1234567890",
	}):andThen(function(count)
	    print(`preloaded {count} assets`)
	end):catch(warn)
	```

	For anything the proxy below doesn't cover, reach the preloader directly
	via `AssetPreloaderController.Preloader`.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weave = require(ReplicatedStorage:WaitForChild("Weave"))
local AssetPreloader = Weave.Util.AssetPreloader

type Content = Weave.PreloadContent
type Promise<T> = Weave.Promise<T>

local preloader = AssetPreloader.new()

local AssetPreloaderController = {
	Preloader = preloader,
	Progress = preloader.Progress,
	AssetLoaded = preloader.AssetLoaded,
}

function AssetPreloaderController:preload(content: { Content }): Promise<number>
	return preloader:preload(content)
end

function AssetPreloaderController:getProgress(): number
	return preloader:getProgress()
end

function AssetPreloaderController:loadedCount(): number
	return preloader:loadedCount()
end

function AssetPreloaderController:totalCount(): number
	return preloader:totalCount()
end

function AssetPreloaderController:Stop()
	preloader:destroy()
end

return AssetPreloaderController
