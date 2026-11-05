--!strict
-- The geometry of tagging, kept apart from the server so the tests can check
-- it: who a swing reaches, whether a claimed position is believable, and
-- cooldowns. Distances are across the ground, with a separate limit on how
-- far above or below a target can be.

export type Target = { Id: any, Position: Vector3 }

local Combat = {}

local FORWARD = Vector3.new(0, 0, -1)

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function direction(vector: Vector3): Vector3
	local across = flat(vector)
	return if across.Magnitude > 1e-3 then across.Unit else FORWARD
end

-- The nearest target a swing reaches: within reach, within arc degrees
-- either side of facing, and within height above or below.
function Combat.swingTarget(
	from: Vector3,
	facing: Vector3,
	targets: { Target },
	reach: number,
	arc: number,
	height: number
): Target?
	local ahead = direction(facing)
	local limit = math.cos(math.rad(arc))
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local offset = target.Position - from
		local distance = flat(offset).Magnitude
		if distance <= reach and math.abs(offset.Y) <= height and distance < bestDistance then
			-- Someone right on top of the attacker counts as in front.
			if distance < 1.5 or direction(offset):Dot(ahead) >= limit then
				best, bestDistance = target, distance
			end
		end
	end
	return best
end

-- Whether a cooldown of seconds has passed since last, allowing an action
-- to arrive up to slack (a fraction of the cooldown) early.
function Combat.ready(now: number, last: number?, seconds: number, slack: number): boolean
	return last == nil or now - last >= seconds * (1 - slack)
end

-- Whether a position the client reports is close enough to where the server
-- has the player to be believed.
function Combat.near(claimed: Vector3, actual: Vector3, slack: number): boolean
	return (claimed - actual).Magnitude <= slack
end

-- A direction worth using: not zero, and not wild. Returns it as a unit
-- vector, or nil.
function Combat.aim(wanted: Vector3): Vector3?
	local length = wanted.Magnitude
	if length ~= length or length < 1e-3 or length == math.huge then
		return nil
	end
	return wanted / length
end

return Combat
