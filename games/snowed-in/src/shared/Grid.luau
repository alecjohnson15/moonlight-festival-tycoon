--!strict
-- Where buildings may go. Centres snap to the build grid, footprints turn in
-- quarter turns, and a spot is allowed when it is inside the build circle,
-- off the hearth and the base's stations, and not overlapping anything
-- already built. The client uses the same checks to colour its preview, and
-- the server uses them to decide.

local Balance = require(script.Parent.Config.Balance)
local EnemySim = require(script.Parent.EnemySim)

export type Rect = { X: number, Z: number, HalfW: number, HalfD: number }
export type Circle = { X: number, Z: number, R: number }

export type Rules = {
	HearthX: number,
	HearthZ: number,
	-- Circles kept clear: stations, cabins, the lodge, the radio tower.
	Keep: { Circle },
	Built: { Rect },
}

local Grid = {}

function Grid.snap(value: number): number
	local grid = Balance.Build.Grid
	return math.floor(value / grid + 0.5) * grid
end

function Grid.turns(turns: number): number
	return math.floor(turns) % 4
end

local function overlaps(a: Rect, b: Rect): boolean
	-- Touching edges are fine, so walls can line up end to end.
	return math.abs(a.X - b.X) < a.HalfW + b.HalfW - 0.01 and math.abs(a.Z - b.Z) < a.HalfD + b.HalfD - 0.01
end

local function rectHitsCircle(rect: Rect, circle: Circle): boolean
	local dx = math.max(math.abs(circle.X - rect.X) - rect.HalfW, 0)
	local dz = math.max(math.abs(circle.Z - rect.Z) - rect.HalfD, 0)
	return dx * dx + dz * dz < circle.R * circle.R
end

-- The footprint a structure would have at this spot, after snapping.
function Grid.place(kind: string, x: number, z: number, turns: number): Rect
	local halfW, halfD = EnemySim.footprint(kind, Grid.turns(turns))
	return { X = Grid.snap(x), Z = Grid.snap(z), HalfW = halfW, HalfD = halfD }
end

-- Whether the footprint may be built. Returns false and the reason a
-- player sees when it can't.
function Grid.check(rect: Rect, rules: Rules): (boolean, string?)
	local build = Balance.Build
	local dx, dz = rect.X - rules.HearthX, rect.Z - rules.HearthZ
	local fromHearth = math.sqrt(dx * dx + dz * dz)
	if fromHearth + math.max(rect.HalfW, rect.HalfD) > build.Radius then
		return false, "Too far from the hearth"
	end
	if rectHitsCircle(rect, { X = rules.HearthX, Z = rules.HearthZ, R = build.ClearRadius }) then
		return false, "Too close to the hearth"
	end
	for _, circle in rules.Keep do
		if rectHitsCircle(rect, circle) then
			return false, "Something is already there"
		end
	end
	for _, other in rules.Built do
		if overlaps(rect, other) then
			return false, "Something is already there"
		end
	end
	if #rules.Built >= build.MaxStructures then
		return false, "The base is full"
	end
	return true, nil
end

return Grid
