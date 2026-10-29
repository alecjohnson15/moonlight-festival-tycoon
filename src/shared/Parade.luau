--!strict
-- The Moonlight Parade's rules (Config/Parade), kept apart from ParadeService
-- so the tests can check them: when parades start, where the floats are,
-- where and when lanterns appear, whether a player is close enough to catch
-- one, how many catches fill the meter, and what they pay. Positions are in
-- the route's space: X and Z across the courtyard floor from the middle of
-- the parade's loop, Y up from the floor. Times are seconds from the start
-- of the parade.

-- A lantern: when it appears, where on the loop (an angle), and how far
-- outside (positive) or inside the loop it floats.
export type Lantern = { At: number, Angle: number, Offset: number }

export type Route = { RadiusX: number, RadiusZ: number }

local Parade = {}

-- When the next parade starts at or after now, for a server that started at
-- serverStart. Times are server times.
function Parade.nextStart(config: any, serverStart: number, now: number): number
	local first = serverStart + config.FirstSeconds
	if now <= first then
		return first
	end
	local passed = math.ceil((now - first) / config.IntervalSeconds)
	return first + passed * config.IntervalSeconds
end

-- The angle of float index (from 1) at t seconds into the parade. The floats
-- go round evenly spaced, the first one leading.
function Parade.floatAngle(config: any, t: number, index: number): number
	return t / config.LapSeconds * math.pi * 2 - (index - 1) * math.pi * 2 / config.Floats
end

-- A point on the loop, or offset studs outside it, at height y.
function Parade.point(route: Route, angle: number, offset: number, y: number): (number, number, number)
	return math.cos(angle) * (route.RadiusX + offset), y, math.sin(angle) * (route.RadiusZ + offset)
end

-- How many lanterns a parade lets go with players on the server, and how many
-- must be caught to fill the meter.
function Parade.lanternCount(config: any, players: number): number
	return config.Lanterns + config.LanternsPerPlayer * math.max(players, 1)
end

function Parade.goal(config: any, lanterns: number): number
	return math.max(1, math.ceil(lanterns * config.GoalShare))
end

-- A parade's lanterns, evenly spaced in time so the last one still has its
-- full time before the parade ends. Each drops just behind one of the floats,
-- taking turns. random returns a number from 0 to 1.
function Parade.schedule(config: any, random: () -> number, count: number): { Lantern }
	local lanterns = {}
	local spacing = (config.RunSeconds - config.LanternSeconds) / math.max(1, count - 1)
	for i = 1, count do
		local at = (i - 1) * spacing
		local float = (i - 1) % config.Floats + 1
		table.insert(lanterns, {
			At = at,
			Angle = Parade.floatAngle(config, at, float) - 0.2 - random() * 0.2,
			Offset = (random() * 2 - 1) * config.Spread,
		})
	end
	return lanterns
end

-- Whether a player whose middle is at (x, y, z) catches lantern at time t.
function Parade.catches(
	config: any,
	route: Route,
	lantern: Lantern,
	t: number,
	x: number,
	y: number,
	z: number
): boolean
	if t < lantern.At or t > lantern.At + config.LanternSeconds then
		return false
	end
	local lx, ly, lz = Parade.point(route, lantern.Angle, lantern.Offset, config.Height)
	return math.sqrt((lx - x) ^ 2 + (lz - z) ^ 2) <= config.CatchRadius and math.abs(y - ly) <= config.CatchHeight
end

-- What one catch pays a player earning income coins a second, if they have
-- already been paid for caught of this parade's lanterns.
function Parade.catchReward(config: any, income: number, caught: number): number
	if caught >= config.PaidLanterns then
		return 0
	end
	return math.max(config.MinReward, math.floor(income * config.RewardSeconds + 0.5))
end

-- What filling the meter pays each player who caught a lantern.
function Parade.fullReward(config: any, income: number): number
	return math.max(config.FullMinReward, math.floor(income * config.FullSeconds + 0.5))
end

-- The most parades can add, as a share of a player's income, catching every
-- lantern they're paid for and filling the meter every time (leaving out the
-- coin floors, which only matter in the first minutes).
function Parade.bonusShare(config: any): number
	local perParade = config.PaidLanterns * config.RewardSeconds + config.FullSeconds
	return perParade / config.IntervalSeconds
end

return Parade
