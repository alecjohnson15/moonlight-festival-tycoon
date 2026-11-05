-- What happened in this run, for the results screen and the rewards:
-- each player's knockouts and thaws, the radio parts the team fitted and
-- whether the night 5 boss went down. Reset when a new run starts.

local RunStats = {}

local knockouts: { [Player]: number } = {}
local thaws: { [Player]: number } = {}
local team = { Parts = 0, BeatYeti = false, Built = 0, Gathered = 0 }

function RunStats.reset()
	table.clear(knockouts)
	table.clear(thaws)
	team.Parts = 0
	team.BeatYeti = false
	team.Built = 0
	team.Gathered = 0
end

function RunStats.knockout(player: Player)
	knockouts[player] = (knockouts[player] or 0) + 1
	player:SetAttribute("Knockouts", knockouts[player])
end

function RunStats.thaw(player: Player)
	thaws[player] = (thaws[player] or 0) + 1
end

function RunStats.knockoutsFor(player: Player): number
	return knockouts[player] or 0
end

function RunStats.thawsFor(player: Player): number
	return thaws[player] or 0
end

function RunStats.team()
	return team
end

function RunStats.forget(player: Player)
	knockouts[player] = nil
	thaws[player] = nil
end

return RunStats
