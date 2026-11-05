-- The warm spots players have built (lanterns and campfires), as circles on
-- the ground. BuildService keeps the list; PlayerService warms anyone
-- standing in one.

local Heat = {}

export type Spot = { X: number, Z: number, R: number }

local spots: { [any]: Spot } = {}

function Heat.set(key: any, spot: Spot?)
	spots[key] = spot
end

function Heat.clear()
	table.clear(spots)
end

-- Whether (x, z) is inside any warm spot.
function Heat.at(x: number, z: number): boolean
	for _, spot in spots do
		local dx, dz = x - spot.X, z - spot.Z
		if dx * dx + dz * dz <= spot.R * spot.R then
			return true
		end
	end
	return false
end

return Heat
