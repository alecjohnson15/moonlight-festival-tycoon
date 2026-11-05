--!strict
-- Help for small teams (Config/Features.SoloAssist): with one or two
-- players, gathering holds are quicker and the hearth burns slower, since
-- the waves already shrink with the team but the chores don't. The server
-- and the client both use these, so the hold a player sees is the hold the
-- server allows.

local Balance = require(script.Parent.Config.Balance)
local Features = require(script.Parent.Config.Features)

local Assist = {}

-- The extra share knocked off gathering holds for a team this size.
function Assist.gatherSpeed(players: number): number
	if not Features.SoloAssist then
		return 0
	end
	return Balance.SoloAssist.GatherSpeed[math.max(1, players)] or 0
end

-- How much of its usual rate the hearth burns for a team this size.
function Assist.burn(players: number): number
	if not Features.SoloAssist then
		return 1
	end
	return Balance.SoloAssist.Burn[math.max(1, players)] or 1
end

-- The share of a gathering hold left after a role's speed and the team's
-- help, which stack by multiplying so they never reach zero.
function Assist.holdScale(roleSpeed: number, players: number): number
	return (1 - roleSpeed) * (1 - Assist.gatherSpeed(players))
end

return Assist
