-- Builds Pinehollow from Config/Map. Town.layout() works out where every
-- prop goes as plain numbers (the client uses it too, for the build
-- preview, and the tests check nothing overlaps); Town.build() makes the
-- parts. The town comes out the same every run.

local Map = require(script.Parent.Parent.Config.Map)
local Kit = require(script.Parent.Parent.Kit)
local Landmarks = require(script.Parent.Landmarks)
local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)

export type Spot = { X: number, Z: number, Turn: number, Scale: number, Seed: number }
export type Circle = { X: number, Z: number, R: number }

export type Layout = {
	Cabins: { Spot },
	Houses: { Spot },
	Trees: { Spot },
	Rocks: { Spot },
	Coal: { Spot },
	Salvage: { Spot },
	Holes: { Spot },
	Bushes: { Spot },
	Crates: { Spot },
	Drifts: { Spot },
	Peaks: { Spot },
	Lamps: { Spot },
	Spawns: { Spot },
	-- Circles the monsters walk around.
	Obstacles: { Circle },
	-- Circles kept clear of building (stations, cabins, the lodge, ...).
	Keep: { Circle },
	-- Straight roads from the base out to each landmark.
	Roads: { { From: { number }, To: { number } } },
}

export type Built = {
	Layout: Layout,
	Hearth: Model,
	Lodge: Model,
	Workbench: Model,
	Stockpile: Model,
	CookPot: Model,
	RadioTower: Model,
	Railway: Model,
	Cabins: { Model },
	Landmarks: { [string]: Model },
	Nodes: { Model },
	Folder: Folder,
}

local Town = {}

local function point(at: { number }): (number, number)
	return at[1], at[2]
end

local function distanceToSegment(x: number, z: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
	local px, pz = ax + dx * t - x, az + dz * t - z
	return math.sqrt(px * px + pz * pz)
end

-- The angle (from north, clockwise) and radius of each cabin.
local function cabinSpots(): { Spot }
	local spots = {}
	for index = 1, Map.CabinCount do
		local angle = math.rad(22.5 + 45 * (index - 1))
		-- The two cabins either side of the lodge sit a little further out.
		local radius = Map.CabinRadius + (if math.abs(math.cos(angle)) > 0.9 and math.cos(angle) < 0 then 8 else 0)
		table.insert(spots, {
			X = math.sin(angle) * radius,
			Z = -math.cos(angle) * radius,
			Turn = 0,
			Scale = 1,
			Seed = index,
		})
	end
	return spots
end

local cached: Layout? = nil

function Town.layout(): Layout
	if cached then
		return cached
	end
	local random = Kit.random(Map.Seed)
	local hx, hz = point(Map.Hearth)
	local layout: Layout = {
		Cabins = cabinSpots(),
		Houses = {},
		Trees = {},
		Rocks = {},
		Coal = {},
		Salvage = {},
		Holes = {},
		Bushes = {},
		Crates = {},
		Drifts = {},
		Peaks = {},
		Lamps = {},
		Spawns = {},
		Obstacles = {},
		Keep = {},
		Roads = {},
	}

	-- What the base keeps clear and the monsters walk around.
	local lodgeX, lodgeZ = point(Map.Lodge)
	table.insert(layout.Obstacles, { X = lodgeX - 9, Z = lodgeZ, R = 12 })
	table.insert(layout.Obstacles, { X = lodgeX + 9, Z = lodgeZ, R = 12 })
	table.insert(layout.Keep, { X = lodgeX, Z = lodgeZ - 6, R = 21 })
	for _, station in { Map.Workbench, Map.Stockpile, Map.CookPot } do
		table.insert(layout.Keep, { X = station[1], Z = station[2], R = 7 })
	end
	local towerX, towerZ = point(Map.RadioTower)
	table.insert(layout.Obstacles, { X = towerX, Z = towerZ, R = 14 })
	table.insert(layout.Keep, { X = towerX, Z = towerZ, R = 20 })
	for _, cabin in layout.Cabins do
		table.insert(layout.Obstacles, { X = cabin.X, Z = cabin.Z, R = 8 })
		table.insert(layout.Keep, { X = cabin.X, Z = cabin.Z, R = 11 })
	end
	-- The station platform.
	local stationX, stationZ = point(Map.Station)
	table.insert(layout.Keep, { X = stationX, Z = stationZ, R = 14 })

	-- Roads to the landmarks.
	for _, landmark in Map.Landmarks do
		local lx, lz = point(landmark.At)
		local dx, dz = lx - hx, lz - hz
		local length = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / length, dz / length
		table.insert(layout.Roads, {
			From = { hx + ux * 34, hz + uz * 34 },
			To = { lx - ux * (landmark.Clear * 0.6), lz - uz * (landmark.Clear * 0.6) },
		})
		-- Lamps every 45 studs along it, swapping sides.
		local side = 1
		for along = 60, length - landmark.Clear, 45 do
			table.insert(layout.Lamps, {
				X = hx + ux * along - uz * 7 * side,
				Z = hz + uz * along + ux * 7 * side,
				Turn = 0,
				Scale = 1,
				Seed = 0,
			})
			side = -side
		end
	end

	-- Old town houses, in a loose street.
	local townX, townZ = point(Map.OldTown.At)
	for index = 1, 6 do
		local row = if index <= 3 then -1 else 1
		local along = ((index - 1) % 3 - 1) * 26
		local x, z = townX + along, townZ + row * 17
		table.insert(
			layout.Houses,
			{ X = x, Z = z, Turn = if row < 0 then 0 else math.pi, Scale = 1, Seed = index * 7 }
		)
		table.insert(layout.Obstacles, { X = x, Z = z, R = 10 })
		-- Two piles of buried junk out front.
		for pile = -1, 1, 2 do
			table.insert(layout.Salvage, {
				X = x + pile * 6,
				Z = z - row * 11,
				Turn = 0,
				Scale = 1,
				Seed = index * 13 + pile,
			})
		end
	end

	local function clearOf(x: number, z: number, margin: number): boolean
		local d = math.sqrt((x - hx) ^ 2 + (z - hz) ^ 2)
		if d < 95 or d > Map.WallRadius - 14 then
			return false
		end
		local lakeX, lakeZ = point(Map.Lake.At)
		if math.sqrt((x - lakeX) ^ 2 + (z - lakeZ) ^ 2) < Map.Lake.Radius + margin then
			return false
		end
		if math.sqrt((x - townX) ^ 2 + (z - townZ) ^ 2) < Map.OldTown.Radius + margin then
			return false
		end
		local quarryX, quarryZ = point(Map.Quarry.At)
		if math.sqrt((x - quarryX) ^ 2 + (z - quarryZ) ^ 2) < Map.Quarry.Radius + margin then
			return false
		end
		if math.abs(z - Map.TrackZ) < 12 + margin then
			return false
		end
		if math.sqrt((x - towerX) ^ 2 + (z - towerZ) ^ 2) < 26 + margin then
			return false
		end
		for _, landmark in Map.Landmarks do
			local lx, lz = point(landmark.At)
			if math.sqrt((x - lx) ^ 2 + (z - lz) ^ 2) < landmark.Clear + margin then
				return false
			end
		end
		for _, road in layout.Roads do
			if distanceToSegment(x, z, road.From[1], road.From[2], road.To[1], road.To[2]) < 9 + margin then
				return false
			end
		end
		return true
	end

	local function scatter(list: { Spot }, count: number, margin: number, minScale: number, maxScale: number)
		local tries = 0
		while #list < count and tries < count * 60 do
			tries += 1
			local angle = random.number(0, math.pi * 2)
			local radius = math.sqrt(random.number(0.1, 1)) * (Map.WallRadius - 10)
			local x, z = hx + math.sin(angle) * radius, hz - math.cos(angle) * radius
			if clearOf(x, z, margin) then
				local ok = true
				for _, other in list do
					if (other.X - x) ^ 2 + (other.Z - z) ^ 2 < (margin * 2.4) ^ 2 then
						ok = false
						break
					end
				end
				if ok then
					table.insert(list, {
						X = x,
						Z = z,
						Turn = random.number(0, math.pi * 2),
						Scale = random.number(minScale, maxScale),
						Seed = tries,
					})
				end
			end
		end
	end

	scatter(layout.Trees, Map.Trees, 4, 0.85, 1.35)
	scatter(layout.Rocks, Map.LooseRocks, 4, 0.8, 1.2)
	scatter(layout.Bushes, Map.Bushes, 3, 1, 1)
	scatter(layout.Crates, Map.CrateSpots, 4, 1, 1)
	scatter(layout.Drifts, 30, 6, 0.8, 2)

	-- The quarry: boulders and coal.
	local quarryX, quarryZ = point(Map.Quarry.At)
	for index = 1, 16 do
		local angle = index / 16 * math.pi * 2 + random.number(-0.2, 0.2)
		local radius = random.number(10, Map.Quarry.Radius - 6)
		local spot = {
			X = quarryX + math.cos(angle) * radius,
			Z = quarryZ + math.sin(angle) * radius,
			Turn = random.number(0, 6),
			Scale = random.number(0.9, 1.3),
			Seed = index,
		}
		table.insert(if index % 3 == 0 then layout.Coal else layout.Rocks, spot)
	end
	-- Coal by the ice cave.
	local caveX, caveZ = point(Map.LandmarkById.IceCave.At)
	for index = 1, 5 do
		local angle = math.rad(-150 + index * 50)
		table.insert(layout.Coal, {
			X = caveX + math.sin(angle) * 34,
			Z = caveZ - math.cos(angle) * 34,
			Turn = index,
			Scale = 1.1,
			Seed = index,
		})
	end
	-- Junk round the depot and the sawmill.
	for _, id in { "Depot", "Sawmill" } do
		local lx, lz = point(Map.LandmarkById[id].At)
		for index = 1, 4 do
			local angle = index * 1.7
			table.insert(layout.Salvage, {
				X = lx + math.cos(angle) * 30,
				Z = lz + math.sin(angle) * 30,
				Turn = 0,
				Scale = 1,
				Seed = index * 31,
			})
		end
	end
	-- Fishing holes on the lake, clear of the lighthouse islet.
	local lakeX, lakeZ = point(Map.Lake.At)
	-- The lighthouse is to the west, so the holes keep to the other sides.
	for index, degrees in { 15, 70, 120, 165, 210, 335 } do
		local angle = math.rad(degrees)
		local radius = 28 + (index % 2) * 18
		table.insert(layout.Holes, {
			X = lakeX + math.sin(angle) * radius,
			Z = lakeZ - math.cos(angle) * radius,
			Turn = angle,
			Scale = 1,
			Seed = index,
		})
	end

	-- The mountains around the valley.
	for index = 1, 30 do
		local angle = index / 30 * math.pi * 2 + random.number(-0.04, 0.04)
		local radius = Map.EdgeRadius + random.number(5, 30)
		table.insert(layout.Peaks, {
			X = hx + math.sin(angle) * radius,
			Z = hz - math.cos(angle) * radius,
			Turn = -angle,
			Scale = random.number(0.85, 1.35),
			Seed = index,
		})
	end

	-- Where the monsters come out of the blizzard: one every 45 degrees,
	-- starting from north.
	for index = 1, Map.SpawnPoints do
		local angle = (index - 1) / Map.SpawnPoints * math.pi * 2
		table.insert(layout.Spawns, {
			X = hx + math.sin(angle) * Map.SpawnRadius,
			Z = hz - math.cos(angle) * Map.SpawnRadius,
			Turn = angle,
			Scale = 1,
			Seed = index,
		})
	end

	cached = layout
	return layout
end

local function at(spot: Spot): CFrame
	return CFrame.new(spot.X, 0, spot.Z) * CFrame.Angles(0, spot.Turn, 0)
end

local function facingHearth(x: number, z: number): CFrame
	local hx, hz = point(Map.Hearth)
	return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(hx, 0, hz))
end

function Town.build(parent: Instance): Built
	local layout = Town.layout()
	local folder = Kit.new("Folder", parent, { Name = "Town" })
	local hx, hz = point(Map.Hearth)

	-- The ground: one big field of snow, the frozen lake and packed roads.
	local ground = Kit.new("Part", folder, {
		Name = "Ground",
		Anchored = true,
		Size = Vector3.new(1000, 10, 1000),
		CFrame = CFrame.new(hx, -5, hz),
		Color = Palette.Snow,
		Material = Enum.Material.Snow,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	ground:SetAttribute("Ground", true)
	local lakeX, lakeZ = point(Map.Lake.At)
	local lake = Kit.new("Part", folder, {
		Name = "Lake",
		Anchored = true,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, Map.Lake.Radius * 2, Map.Lake.Radius * 2),
		CFrame = CFrame.new(lakeX, 0.05, lakeZ) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Palette.Ice,
		Material = Enum.Material.Ice,
		Reflectance = 0.15,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	lake:SetAttribute("Ground", true)
	local roads = Kit.model(folder, "Roads")
	for _, road in layout.Roads do
		local from = Vector3.new(road.From[1], 0.06, road.From[2])
		local to = Vector3.new(road.To[1], 0.06, road.To[2])
		local strip = Kit.span(roads, from, to, 10, 0.1, Palette.Packed, Enum.Material.Snow)
		strip.CanCollide = false
	end
	-- The plaza round the hearth.
	Kit.new("Part", folder, {
		Name = "Plaza",
		Anchored = true,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 64, 64),
		CFrame = CFrame.new(hx, 0.05, hz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Palette.Packed,
		Material = Enum.Material.Snow,
	})

	local base = Kit.model(folder, "Base")
	local hearth = Landmarks.hearth(base, CFrame.new(hx, 0, hz))
	local lodge = Landmarks.lodge(base, CFrame.new(Map.Lodge[1], 0, Map.Lodge[2]))
	local workbench = Landmarks.workbench(base, facingHearth(Map.Workbench[1], Map.Workbench[2]))
	local stockpile = Landmarks.stockpile(base, facingHearth(Map.Stockpile[1], Map.Stockpile[2]))
	local cookPot = Landmarks.cookPot(base, facingHearth(Map.CookPot[1], Map.CookPot[2]))
	local radioTower = Landmarks.radioTower(base, facingHearth(Map.RadioTower[1], Map.RadioTower[2]))
	local railway = Landmarks.railway(folder, Map.TrackZ, Map.Station[1])

	-- The signpost by the hearth, an arrow to each landmark.
	local post = Kit.model(base, "Signpost")
	local postAt = CFrame.new(hx - 12, 0, hz - 10)
	Kit.solid(Kit.post(post, postAt * CFrame.new(0, 5, 0), 10, 0.7, Palette.Bark, Enum.Material.Wood))
	for index, landmark in Map.Landmarks do
		local target = Vector3.new(landmark.At[1], 0, landmark.At[2])
		local look = CFrame.lookAt(postAt.Position, target)
		Props.arrow(post, look * CFrame.new(0, 9.4 - index * 1.6, -3.4), landmark.Name)
	end

	local cabins = {}
	for index, spot in layout.Cabins do
		table.insert(cabins, Landmarks.cabin(base, facingHearth(spot.X, spot.Z), index))
	end

	local landmarks = {}
	local builders = {
		Sawmill = Landmarks.sawmill,
		IceCave = Landmarks.iceCave,
		Lighthouse = Landmarks.lighthouse,
		Depot = Landmarks.depot,
	}
	for _, landmark in Map.Landmarks do
		landmarks[landmark.Id] = builders[landmark.Id](folder, facingHearth(landmark.At[1], landmark.At[2]))
	end

	local scenery = Kit.model(folder, "Scenery")
	for _, spot in layout.Houses do
		Props.house(scenery, at(spot), spot.Seed)
	end
	for _, spot in layout.Peaks do
		Props.peak(scenery, at(spot), spot.Scale)
	end
	for _, spot in layout.Drifts do
		Props.drift(scenery, at(spot), Vector3.new(14, 4, 9) * spot.Scale)
	end
	for _, spot in layout.Lamps do
		Props.lampPost(scenery, at(spot))
	end

	-- The invisible wall that keeps everyone in the valley.
	local wall = Kit.model(folder, "Wall")
	local segments = 48
	local width = 2 * math.pi * Map.WallRadius / segments + 4
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local x, z = hx + math.sin(angle) * Map.WallRadius, hz - math.cos(angle) * Map.WallRadius
		Kit.new("Part", wall, {
			Anchored = true,
			CanCollide = true,
			Transparency = 1,
			CastShadow = false,
			Size = Vector3.new(width, 120, 4),
			CFrame = CFrame.lookAt(Vector3.new(x, 50, z), Vector3.new(hx, 50, hz)),
		})
	end

	-- Everything players gather from.
	local nodesFolder = Kit.model(folder, "Nodes")
	local nodes = {}
	for index, spot in layout.Trees do
		table.insert(nodes, Props.pine(nodesFolder, at(spot), spot.Scale, if index % 3 == 0 then 1 else 0))
	end
	for _, spot in layout.Rocks do
		table.insert(nodes, Props.rock(nodesFolder, at(spot), spot.Scale))
	end
	for _, spot in layout.Coal do
		table.insert(nodes, Props.coalSeam(nodesFolder, at(spot), spot.Scale))
	end
	for _, spot in layout.Salvage do
		table.insert(nodes, Props.salvage(nodesFolder, at(spot), spot.Seed))
	end
	for _, spot in layout.Holes do
		table.insert(nodes, Props.fishingHole(nodesFolder, at(spot)))
	end
	for _, spot in layout.Bushes do
		table.insert(nodes, Props.bush(nodesFolder, at(spot), spot.Seed))
	end

	return {
		Layout = layout,
		Hearth = hearth,
		Lodge = lodge,
		Workbench = workbench,
		Stockpile = stockpile,
		CookPot = cookPot,
		RadioTower = radioTower,
		Railway = railway,
		Cabins = cabins,
		Landmarks = landmarks,
		Nodes = nodes,
		Folder = folder,
	}
end

return Town
