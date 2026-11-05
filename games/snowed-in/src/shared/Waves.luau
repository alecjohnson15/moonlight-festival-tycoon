--!strict
-- Decides which monsters come on each night and when. A night has a points
-- budget that grows with the night and the number of players; the budget is
-- spent on the kinds of monster that have started appearing by then, mixing
-- in the bigger ones as the nights go on. Boss nights add their boss on top.
--
-- Everything takes a roll function (returning 0 to 1) so the server can use
-- Roblox's Random and the tests a fixed sequence.

local Balance = require(script.Parent.Config.Balance)
local Enemies = require(script.Parent.Config.Enemies)

export type Spawn = {
	Kind: string,
	-- Seconds into the night.
	At: number,
	-- Which spawn point (1 to Config/Map.SpawnPoints).
	Point: number,
}

local Waves = {}

-- How much the waves and the bosses' health scale with the number of
-- players in the run.
function Waves.multiplier(players: number): number
	local waves = Balance.Waves
	local count = math.max(1, players)
	return math.min(waves.Max, waves.Solo + waves.PerExtraPlayer * (count - 1))
end

function Waves.budget(night: number, players: number): number
	local waves = Balance.Waves
	local base = waves.NightBase + waves.NightGrowth * night
	if night > Balance.Nights then
		base += (waves.OvertimeGrowth - waves.NightGrowth) * (night - Balance.Nights)
	end
	return math.max(1, math.floor(base * Waves.multiplier(players) + 0.5))
end

-- The kinds that can be bought with points on this night, cheapest first.
function Waves.kinds(night: number): { Enemies.Enemy }
	local kinds = {}
	for _, enemy in Enemies.List do
		if not enemy.Boss and enemy.Points > 0 and enemy.From <= night then
			table.insert(kinds, enemy)
		end
	end
	table.sort(kinds, function(a, b)
		return a.Points < b.Points
	end)
	return kinds
end

-- The monsters for a night, in no particular order. Bigger kinds get a
-- larger share of the budget as the nights go on, but at least half the
-- budget is always frostlings and hounds, so there is a crowd to fight.
function Waves.compose(night: number, players: number, roll: () -> number): { string }
	local budget = Waves.budget(night, players)
	local kinds = Waves.kinds(night)
	local list = {}
	if #kinds == 0 then
		return list
	end
	local spent = 0
	local bigSpent = 0
	-- How likely each pick is to be one of the bigger kinds.
	local bigChance = math.clamp(0.15 + 0.06 * night, 0.15, 0.6)
	while spent < budget do
		local left = budget - spent
		local choice = kinds[1 + math.min(math.floor(roll() * math.min(2, #kinds)), #kinds - 1)]
		if #kinds > 2 and roll() < bigChance then
			local big = kinds[3 + math.min(math.floor(roll() * (#kinds - 2)), #kinds - 3)]
			if big.Points <= left and bigSpent + big.Points <= budget * 0.5 then
				choice = big
				bigSpent += big.Points
			end
		end
		if choice.Points > left then
			-- Spend what is left on the cheapest kind.
			choice = kinds[1]
		end
		if choice.Points > left then
			break
		end
		table.insert(list, choice.Id)
		spent += choice.Points
	end
	return list
end

-- The boss for this night, if it is a boss night.
function Waves.boss(night: number): string?
	return Balance.Bosses[night]
end

-- Spreads a night's monsters over the first part of the night, from the
-- spawn points, in small groups so they arrive as waves rather than a
-- trickle. The boss, if any, comes at the halfway mark of the window.
function Waves.schedule(list: { string }, boss: string?, nightSeconds: number, roll: () -> number): { Spawn }
	local window = nightSeconds * Balance.Waves.SpawnWindow
	local spawns: { Spawn } = {}
	local groups = math.max(1, math.ceil(#list / 5))
	local points = 8
	for index, kind in list do
		local group = (index - 1) % groups
		local at = 3 + (window - 3) * group / groups + roll() * 4
		-- Each group comes from one or two directions.
		local point = 1 + ((group * 3 + (if roll() < 0.3 then 1 else 0)) % points)
		table.insert(spawns, { Kind = kind, At = math.min(at, window), Point = point })
	end
	if boss then
		table.insert(spawns, { Kind = boss, At = window * 0.5, Point = 1 + math.floor(roll() * points) })
	end
	table.sort(spawns, function(a, b)
		return a.At < b.At
	end)
	return spawns
end

-- A boss's health in a run with this many players.
function Waves.bossHealth(kind: string, players: number): number
	local enemy = Enemies.ById[kind]
	return math.floor(enemy.Health * math.max(0.6, Waves.multiplier(players)) + 0.5)
end

return Waves
