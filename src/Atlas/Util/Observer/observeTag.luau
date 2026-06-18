--!strict
--[=[
	@module Util.Observer.observeTag
	Observes every instance with CollectionService tag `tag`. Pass `ancestors`
	to only activate tagged instances under those roots; ancestry is tracked
	live as instances are reparented.
]=]

local CollectionService = game:GetService("CollectionService")

local Trove = require(script.Parent.Parent.Trove)
local Types = require(script.Parent.Types)

type Cleanup = Types.Cleanup
type Stop = Types.Stop
type TagCallback = Types.TagCallback

type Entry = {
	active: boolean,
	cleanup: Cleanup?,
	trove: any?,
}

local function runCleanup(entry: Entry)
	local cleanup = entry.cleanup
	entry.cleanup = nil
	entry.active = false
	if cleanup then
		cleanup()
	end
end

local function observeTag(tag: string, callback: TagCallback, ancestors: { Instance }?): Stop
	assert(type(tag) == "string" and #tag > 0, "[Observer.observeTag] tag must be a non-empty string")
	assert(type(callback) == "function", "[Observer.observeTag] callback must be a function")

	local trove = Trove.new()
	local entries: { [Instance]: Entry } = {}

	local function inAncestry(instance: Instance): boolean
		if not ancestors then
			return true
		end
		for _, ancestor in ancestors do
			if instance == ancestor or instance:IsDescendantOf(ancestor) then
				return true
			end
		end
		return false
	end

	local function activate(instance: Instance, entry: Entry)
		if entry.active then
			return
		end
		entry.active = true
		entry.cleanup = callback(instance)
	end

	local function onAdded(instance: Instance)
		if entries[instance] then
			return
		end
		local entry: Entry = { active = false, cleanup = nil, trove = nil }
		entries[instance] = entry

		if ancestors then
			local childTrove = trove:extend()
			entry.trove = childTrove
			childTrove:connect(instance.AncestryChanged, function()
				if inAncestry(instance) then
					activate(instance, entry)
				else
					runCleanup(entry)
				end
			end)
		end

		if inAncestry(instance) then
			activate(instance, entry)
		end
	end

	local function onRemoved(instance: Instance)
		local entry = entries[instance]
		if not entry then
			return
		end
		entries[instance] = nil
		runCleanup(entry)
		if entry.trove then
			entry.trove:destroy()
		end
	end

	trove:connect(CollectionService:GetInstanceAddedSignal(tag), onAdded)
	trove:connect(CollectionService:GetInstanceRemovedSignal(tag), onRemoved)

	for _, instance in CollectionService:GetTagged(tag) do
		onAdded(instance)
	end

	return function()
		for instance in entries do
			onRemoved(instance)
		end
		trove:destroy()
	end
end

return observeTag
