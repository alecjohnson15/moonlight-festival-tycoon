-- What happened in this run, for the results screen and the rewards: what
-- each player did (knockouts, thaws, wood dropped off, fires fed, things
-- built, parts freed and fitted), the radio parts the team fitted, whether
-- the night 5 boss went down and who was there to see it, and the team
-- milestones reached. Reset when a new run starts.

local RunStats = {}

export type Contribution = {
	Knockouts: number,
	Thaws: number,
	Gathered: number,
	Fed: number,
	Built: number,
	Repaired: number,
	Freed: number,
	Fitted: number,
}

local players: { [Player]: Contribution } = {}
local yetiWitnesses: { [Player]: boolean } = {}
local team = { Parts = 0, BeatYeti = false, Built = 0, Gathered = 0, Milestones = {} :: { string } }
local runNumber = 0

local function blank(): Contribution
	return { Knockouts = 0, Thaws = 0, Gathered = 0, Fed = 0, Built = 0, Repaired = 0, Freed = 0, Fitted = 0 }
end

local function entry(player: Player): Contribution
	local found = players[player]
	if not found then
		found = blank()
		players[player] = found
	end
	return found
end

-- Starts a new run's records, and gives the run a new number (used to pay
-- each run's rewards once only).
function RunStats.reset()
	table.clear(players)
	table.clear(yetiWitnesses)
	team.Parts = 0
	team.BeatYeti = false
	team.Built = 0
	team.Gathered = 0
	team.Milestones = {}
	runNumber += 1
end

-- An id for this run, unique to this server.
function RunStats.runId(): string
	return `{game.JobId}:{runNumber}`
end

-- Adds to one of a player's counts.
function RunStats.add(player: Player, key: string, amount: number)
	local found = entry(player) :: any
	found[key] = (found[key] or 0) + amount
end

function RunStats.knockout(player: Player)
	local found = entry(player)
	found.Knockouts += 1
	player:SetAttribute("Knockouts", found.Knockouts)
end

function RunStats.thaw(player: Player)
	entry(player).Thaws += 1
end

function RunStats.knockoutsFor(player: Player): number
	return entry(player).Knockouts
end

function RunStats.thawsFor(player: Player): number
	return entry(player).Thaws
end

function RunStats.contribution(player: Player): Contribution
	return table.clone(entry(player))
end

-- The yeti went down: everyone in the server sees it, so they all get the
-- trophy (and nobody who joins afterwards does).
function RunStats.yetiDown(list: { Player })
	team.BeatYeti = true
	for _, player in list do
		yetiWitnesses[player] = true
	end
end

function RunStats.sawYeti(player: Player): boolean
	return yetiWitnesses[player] == true
end

-- Records a team milestone once. Returns true the first time.
function RunStats.milestone(id: string): boolean
	if table.find(team.Milestones, id) then
		return false
	end
	table.insert(team.Milestones, id)
	return true
end

function RunStats.team()
	return team
end

function RunStats.forget(player: Player)
	players[player] = nil
	yetiWitnesses[player] = nil
end

return RunStats
