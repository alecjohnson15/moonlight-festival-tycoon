--!strict
-- Ghost Catcher's rules, kept apart from ActivityService so the tests can
-- check them: where and when a round's wisps appear, whether a player is
-- close enough to catch one, and what catching pays. Positions are plot-local
-- studs, with Y up from the plot floor, and times are seconds from the start
-- of the round. Config is Config/Activity.

export type Wisp = { At: number, X: number, Z: number }

local Activity = {}

local function gap(a: { X: number, Z: number }, x: number, z: number): number
	return math.sqrt((a.X - x) ^ 2 + (a.Z - z) ^ 2)
end

-- A round's wisps, evenly spaced in time so the last one still has its full
-- wait before the round ends, each between MinGap and MaxGap from the one
-- before. The first is measured from start, where the player stands. random
-- returns a number from 0 to 1.
function Activity.schedule(config: any, random: () -> number, start: { X: number, Z: number }): { Wisp }
	local area = config.Area
	local spacing = (config.RoundSeconds - config.WispSeconds) / math.max(1, config.Wisps - 1)
	local wisps = {}
	local last = start
	for i = 1, config.Wisps do
		local x, z = area.X, area.Z
		-- Try for a spot the right distance away; the last try stands if none is.
		for _ = 1, 40 do
			x = area.X + (random() - 0.5) * area.Width
			z = area.Z + (random() - 0.5) * area.Depth
			local distance = gap(last, x, z)
			if distance >= config.MinGap and distance <= config.MaxGap then
				break
			end
		end
		local wisp = { At = (i - 1) * spacing, X = x, Z = z }
		table.insert(wisps, wisp)
		last = wisp
	end
	return wisps
end

-- Whether a player whose middle is at (x, y, z) catches wisp at time t.
function Activity.catches(config: any, wisp: Wisp, t: number, x: number, y: number, z: number): boolean
	if t < wisp.At or t > wisp.At + config.WispSeconds then
		return false
	end
	return gap(wisp, x, z) <= config.CatchRadius and math.abs(y - config.Height) <= config.CatchHeight
end

-- What one wisp pays a plot earning income coins a second.
function Activity.wispReward(config: any, income: number): number
	return math.max(config.MinReward, math.floor(income * config.RewardSeconds + 0.5))
end

-- What catching every wisp in a round pays on top.
function Activity.perfectReward(config: any, income: number): number
	return math.max(config.MinReward * 2, math.floor(income * config.PerfectSeconds + 0.5))
end

-- The most rounds back to back can add, as a share of the plot's income
-- (leaving out the MinReward floor, which only matters in the first minutes).
function Activity.bonusShare(config: any): number
	local perRound = config.Wisps * config.RewardSeconds + config.PerfectSeconds
	return perRound / (config.LeadSeconds + config.RoundSeconds + config.CooldownSeconds)
end

return Activity
