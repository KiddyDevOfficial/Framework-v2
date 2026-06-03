--!nocheck
--[=[
	@module GamePasses
	List of game passes and server-side grant handlers. Registered by
	`MonetizationService` on init (and on join / purchase via the framework).
]=]

local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

export type GamePasses = {
	GetGamePass: (name: string) -> GamePass?,
	GetGamePassByTag: (tag: string) -> GamePass?,
	GetGamePassById: (id: number) -> GamePass?,
	GetAllGamePasses: () -> { GamePass },
	GamePasses: { GamePass },
}

export type GamePass = {
	id: number,
	name: string,
	tag: string?,
	handler: (player: Player) -> (),
}

local GamePasses: GamePasses = {}
GamePasses.GamePasses = {
	--[=[
		{
		id = 0,
		name = "VIP",
		tag = "vip",
		handler = function(player)
			if not IS_SERVER then
				return
			end
		end,
	},
	]=]-- Example game pass
}

function GamePasses.GetGamePass(name: string): GamePass?
	for _, gamePass in GamePasses.GamePasses do
		if gamePass.name == name then
			return gamePass
		end
	end
	return nil
end

function GamePasses.GetGamePassByTag(tag: string): GamePass?
	for _, gamePass in GamePasses.GamePasses do
		if gamePass.tag == tag then
			return gamePass
		end
	end
	return nil
end

function GamePasses.GetGamePassById(id: number): GamePass?
	for _, gamePass in GamePasses.GamePasses do
		if gamePass.id == id then
			return gamePass
		end
	end
	return nil
end

function GamePasses.GetAllGamePasses(): { GamePass }
	return GamePasses.GamePasses
end

return GamePasses :: GamePasses
