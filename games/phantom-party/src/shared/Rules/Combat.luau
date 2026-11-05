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

-- Whether nothing solid stands between two points. The server passes a
-- raycast against the map; the tests pass walls of their own.
export type Clear = (from: Vector3, to: Vector3) -> boolean

-- The nearest target a swing reaches: within reach, within arc degrees
-- either side of facing, within height above or below, and, when clear is
-- given, with no wall between the attacker and the target.
function Combat.swingTarget(
	from: Vector3,
	facing: Vector3,
	targets: { Target },
	reach: number,
	arc: number,
	height: number,
	clear: Clear?
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
			local inFront = distance < 1.5 or direction(offset):Dot(ahead) >= limit
			if inFront and (clear == nil or clear(from, target.Position)) then
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

-- Where a shot or a throw starts. The client says where it fired from, so
-- the beam leaves the blaster's tip on their screen; the server believes it
-- only if it's within slack of where it has the player and nothing solid is
-- in between, so nobody can fire from the far side of a wall. Otherwise the
-- shot starts where the server has them.
function Combat.origin(claimed: unknown, actual: Vector3, slack: number, clear: Clear?): Vector3
	if typeof(claimed) ~= "Vector3" then
		return actual
	end
	local point = claimed :: Vector3
	if point.X ~= point.X or point.Y ~= point.Y or point.Z ~= point.Z then
		return actual
	end
	if not Combat.near(point, actual, slack) then
		return actual
	end
	if clear and not clear(actual, point) then
		return actual
	end
	return point
end

-- How far along a thrown blade's path a viewer first sees it: 0 if they
-- can see where it was thrown from, the distance at which the path comes
-- within seen studs of them, or nil if it never does. The server sends the
-- flight to each viewer from that point on, so nobody far away learns where
-- the Phantom stood.
function Combat.pathStart(start: Vector3, heading: Vector3, range: number, viewer: Vector3, seen: number): number?
	local offset = viewer - start
	if offset.Magnitude <= seen then
		return 0
	end
	-- Where the line passes closest to the viewer, and how close.
	local along = offset:Dot(heading)
	local gap = (offset - heading * along).Magnitude
	if gap > seen then
		return nil
	end
	local enters = along - math.sqrt(seen * seen - gap * gap)
	if enters > range or along + math.sqrt(seen * seen - gap * gap) < 0 then
		return nil
	end
	return math.max(0, enters)
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
