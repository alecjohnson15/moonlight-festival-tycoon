--!strict
-- The geometry of an arena fight, kept apart from ArenaService so the tests
-- can check it: who a swing or a special move reaches, which way a hit throws
-- its target, and whether someone is standing in the arena. Positions are
-- where fighters stand (their root parts), and facing is the way the attacker
-- looks. Distances are measured across the ground, with a separate limit on
-- how far above or below a target can be.

export type Fighter = { Id: any, Position: Vector3 }

local Combat = {}

local FORWARD = Vector3.new(0, 0, -1)

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function direction(vector: Vector3): Vector3
	local across = flat(vector)
	return if across.Magnitude > 1e-3 then across.Unit else FORWARD
end

-- Whether position is in the arena: less than radius from the middle of the
-- stage's top (centre) and no more than height above it.
function Combat.isInside(centre: Vector3, radius: number, height: number, position: Vector3): boolean
	local offset = position - centre
	return flat(offset).Magnitude < radius and offset.Y > -1 and offset.Y < height
end

-- The nearest fighter a swing reaches: within reach, within arc degrees
-- either side of facing, and within height above or below.
function Combat.swingTarget(
	from: Vector3,
	facing: Vector3,
	fighters: { Fighter },
	reach: number,
	arc: number,
	height: number
): Fighter?
	local ahead = direction(facing)
	local limit = math.cos(math.rad(arc))
	local best: Fighter? = nil
	local bestDistance = math.huge
	for _, fighter in fighters do
		local offset = fighter.Position - from
		local distance = flat(offset).Magnitude
		if distance <= reach and math.abs(offset.Y) <= height and distance < bestDistance then
			-- Someone standing right on top of the attacker counts as in front.
			if distance < 1 or direction(offset):Dot(ahead) >= limit then
				best, bestDistance = fighter, distance
			end
		end
	end
	return best
end

-- Every fighter within radius of centre and within height above or below.
function Combat.within(centre: Vector3, fighters: { Fighter }, radius: number, height: number): { Fighter }
	local found = {}
	for _, fighter in fighters do
		local offset = fighter.Position - centre
		if flat(offset).Magnitude <= radius and math.abs(offset.Y) <= height then
			table.insert(found, fighter)
		end
	end
	return found
end

-- Every fighter within width / 2 of the path from a to b, and within height
-- above or below it, nearest to a first.
function Combat.along(a: Vector3, b: Vector3, fighters: { Fighter }, width: number, height: number): { Fighter }
	local length = flat(b - a).Magnitude
	local ahead = direction(b - a)
	local found = {}
	local distances: { [Fighter]: number } = {}
	for _, fighter in fighters do
		local offset = fighter.Position - a
		local along = math.clamp(flat(offset):Dot(ahead), 0, length)
		local aside = (flat(offset) - ahead * along).Magnitude
		if aside <= width / 2 and math.abs(offset.Y) <= height then
			table.insert(found, fighter)
			distances[fighter] = along
		end
	end
	table.sort(found, function(x, y)
		return distances[x] < distances[y]
	end)
	return found
end

-- The velocity a hit gives its target: away from where the hit came from,
-- across the ground, at strength, plus lift upwards. A target standing on the
-- same spot is thrown the way the attacker faces.
function Combat.knockback(from: Vector3, to: Vector3, facing: Vector3, strength: number, lift: number): Vector3
	local away = flat(to - from)
	local throw = if away.Magnitude >= 0.5 then away.Unit else direction(facing)
	return throw * strength + Vector3.new(0, lift, 0)
end

-- Whether a cooldown of seconds has passed since last. An action that arrives
-- up to slack (a fraction of the cooldown) early still counts, to allow for
-- network jitter.
function Combat.ready(now: number, last: number, seconds: number, slack: number): boolean
	return now - last >= seconds * (1 - slack)
end

return Combat
