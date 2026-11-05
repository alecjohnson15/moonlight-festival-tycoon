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
local Features = require(script.Parent.Config.Features)

export type Spawn = {
	Kind: string,
	-- Seconds into the night.
	At: number,
	-- Which spawn point (1 to Config/Map.SpawnPoints).
	Point: number,
}

-- A night's theme (Config/Features.NightThemes): what tonight's wave is
-- mostly made of, and the tip players see from the morning before, so each
-- night asks for something different. Weights share out the budget among
-- the kinds that have arrived; kinds a theme doesn't name still turn up a
-- little (Background).
export type Theme = {
	Id: string,
	Name: string,
	Tip: string,
	-- The first night it can be picked: when its main monster arrives.
	From: number,
	Weights: { [string]: number },
}

local Waves = {}

Waves.Background = 0.3

Waves.Themes = {
	{
		Id = "Crowd",
		Name = "Frostling Crowd",
		Tip = "Lots of little ones walk straight at the fire: swing your torch, and turrets mow them down.",
		From = 1,
		Weights = { Frostling = 4, SnowHound = 1 },
	},
	{
		Id = "Pack",
		Name = "Hound Pack",
		Tip = "Fast hounds hunt players, not the fire: stay together inside the warm circle.",
		From = 2,
		Weights = { SnowHound = 4, Frostling = 1.5 },
	},
	{
		Id = "Siege",
		Name = "Brute Siege",
		Tip = "Brutes smash walls first: keep wood in the stockpile for repairs, and ember traps slow them down.",
		From = 3,
		Weights = { SnowBrute = 3, Frostling = 2 },
	},
	{
		Id = "Swarm",
		Name = "Wisp Swarm",
		Tip = "Wisps fly over walls and throw ice from afar: slings, flares and turrets reach them.",
		From = 4,
		Weights = { IceWisp = 3, SnowHound = 1, Frostling = 1.5 },
	},
	{
		Id = "Whiteout",
		Name = "Whiteout",
		Tip = "A bit of everything out of the storm: feed the hearth before dark and hold the line.",
		From = 5,
		Weights = { Frostling = 1, SnowHound = 1, SnowBrute = 1, IceWisp = 1 },
	},
} :: { Theme }

Waves.ThemeById = {} :: { [string]: Theme }
for _, theme in Waves.Themes do
	Waves.ThemeById[theme.Id] = theme
end

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

-- The kind a theme is built round: its heaviest weight.
function Waves.signature(theme: Theme): string
	local best, weight = "Frostling", -1
	for kind, value in theme.Weights do
		if value > weight or (value == weight and kind < best) then
			best, weight = kind, value
		end
	end
	return best
end

-- Every night's theme for a run, from the run's seed, the same every time
-- for the same seed. The first night is always the gentle crowd, a new
-- monster's first night is its own theme (so it gets introduced), and no
-- theme comes two nights running.
function Waves.plan(seed: number): { [number]: Theme }
	local plan = {}
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function roll(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local previous = ""
	for night = 1, Balance.LastNight do
		local pick: Theme? = nil
		for _, theme in Waves.Themes do
			if theme.From == night then
				pick = theme
			end
		end
		if not pick then
			local options = {}
			for _, theme in Waves.Themes do
				if theme.From <= night and theme.Id ~= previous then
					table.insert(options, theme)
				end
			end
			pick = options[1 + math.min(#options - 1, math.floor(roll() * #options))]
		end
		local chosen = pick :: Theme
		plan[night] = chosen
		previous = chosen.Id
	end
	return plan
end

-- A night's monsters shaped by its theme: the budget is shared out by the
-- theme's weights among the kinds that have arrived (unnamed kinds get the
-- Background weight). Spends the budget exactly, since a frostling costs 1.
function Waves.themed(night: number, players: number, roll: () -> number, theme: Theme): { string }
	local budget = Waves.budget(night, players)
	local kinds = Waves.kinds(night)
	local list = {}
	local spent = 0
	while spent < budget do
		local left = budget - spent
		local total = 0
		for _, kind in kinds do
			if kind.Points <= left then
				total += theme.Weights[kind.Id] or Waves.Background
			end
		end
		if total <= 0 then
			break
		end
		local pick = roll() * total
		local choice = nil
		for _, kind in kinds do
			if kind.Points <= left then
				local weight = theme.Weights[kind.Id] or Waves.Background
				choice = kind
				if pick < weight then
					break
				end
				pick -= weight
			end
		end
		local chosen = choice :: Enemies.Enemy
		table.insert(list, chosen.Id)
		spent += chosen.Points
	end
	return list
end

-- The night's monsters: themed when the night has a theme (and
-- Config/Features.NightThemes is on), otherwise the plain mix.
function Waves.forNight(night: number, players: number, roll: () -> number, theme: Theme?): { string }
	if theme and Features.NightThemes then
		return Waves.themed(night, players, roll, theme)
	end
	return Waves.compose(night, players, roll)
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

-- The guards at a landmark whose radio part is still there, on a night:
-- more as the nights go on, a brute leading from night 3 and hounds from
-- night 2, and one fewer for each of fewer (catch-up), never none.
function Waves.guards(night: number, fewer: number?): { string }
	local count = math.max(1, Balance.Waves.GuardsPerLandmark + math.floor(night / 3) - (fewer or 0))
	local list = {}
	for index = 1, count do
		table.insert(
			list,
			if index == 1 and night >= 3
				then "SnowBrute"
				elseif index % 2 == 0 and night >= 2 then "SnowHound"
				else "Frostling"
		)
	end
	return list
end

-- A boss's health in a run with this many players.
function Waves.bossHealth(kind: string, players: number): number
	local enemy = Enemies.ById[kind]
	return math.floor(enemy.Health * math.max(0.6, Waves.multiplier(players)) + 0.5)
end

return Waves
