-- Hollowmere Manor: a moonlit Victorian mansion in the middle of a masked
-- ball. Two floors and a walled garden, built round loops so a chase never
-- hits a dead end: a double-height foyer with twin staircases up to a
-- balcony and the master bedroom, a ballroom with a stage and a grand
-- piano, a library of tall shelves to dodge between, a long dining hall, a
-- kitchen, a study, a glass conservatory with a fountain, and a garden of
-- hedges, a gazebo and the family graves. Three secret passages link far
-- rooms (a bookcase, a fireplace, a portrait).
--
-- Plan, looking down with the front door at the top (+Z):
--
--   z=58  +-----------+-----------+-----------+
--         | Ballroom  |   Foyer   |  Dining   |
--   z=18  |           |           +-----------+
--   z=14  +-----------+---Hall----|  Kitchen  |
--         |  Library  | (Bedroom  |           |
--   z=-22 |           |   above)  +-----------+
--         |           |Conservat'y|   Study   |
--   z=-58 +-----------+-----------+-----------+
--                       Garden
--   z=-104
--         x=-72      -20         20          72

local Kit = require(script.Parent.Parent.Kit)
local Pieces = require(script.Parent.Parent.Pieces)

local Manor = {}

Manor.Id = "manor"
Manor.Name = "Hollowmere Manor"
Manor.Blurb = "A masked ball in a moonlit mansion. Mind the secret passages."

-- How the world looks while this map is played (MapService applies it).
Manor.Lighting = {
	ClockTime = 0.2,
	Brightness = 1.6,
	Ambient = "#3C3550",
	OutdoorAmbient = "#4A4870",
	FogColor = "#232036",
	Atmosphere = { Density = 0.32, Haze = 1.6, Color = "#5C5A88", Decay = "#2A2440" },
	ColorShift = "#8EA2FF",
	Exposure = 0.15,
}

local hex = Kit.color
local PI = math.pi

local WALL = hex("#5B3F52")
local WALL_DARK = hex("#3F2C3B")
local WAINSCOT = hex("#3A2418")
local TRIM = hex("#C9A44C")
local MARBLE = hex("#D9D2C6")
local WOOD_FLOOR = hex("#6B4428")
local TILE = hex("#4E5560")
local GRASS = hex("#2B4A2E")
local WARM = hex("#FFC98A")
local MOON = hex("#BFD0FF")

function Manor.build(origin: CFrame): Model
	local map = Kit.model(nil, Manor.Id)
	map:SetAttribute("DisplayName", Manor.Name)
	local structure = Kit.model(map, "Structure")
	local dressing = Kit.model(map, "Dressing")
	local spawns = Kit.new("Folder", map, { Name = "Spawns" })
	local coins = Kit.new("Folder", map, { Name = "Coins" })
	local clues = Kit.new("Folder", map, { Name = "Clues" })
	local passages = Kit.new("Folder", map, { Name = "Passages" })
	local rooms = Kit.new("Folder", map, { Name = "Rooms" })

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function point(x: number, y: number, z: number): Vector3
		return (origin * CFrame.new(x, y, z)).Position
	end
	-- Facing directions, for things against walls: each faces into the room.
	local FACE_N = CFrame.Angles(0, PI, 0) -- faces +Z
	local FACE_E = CFrame.Angles(0, -PI / 2, 0) -- faces +X
	local FACE_W = CFrame.Angles(0, PI / 2, 0) -- faces -X

	local function floor(
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		y: number,
		color: Color3,
		material: Enum.Material
	)
		Kit.slab(
			structure,
			at((x0 + x1) / 2, y - 0.5, (z0 + z1) / 2),
			Vector3.new(x1 - x0, 1, z1 - z0),
			color,
			material
		)
	end
	local function ceiling(x0: number, z0: number, x1: number, z1: number, y: number, color: Color3?)
		Kit.slab(
			structure,
			at((x0 + x1) / 2, y + 0.5, (z0 + z1) / 2),
			Vector3.new(x1 - x0, 1, z1 - z0),
			color or hex("#2B2030")
		)
	end
	local function wall(
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		y: number,
		height: number,
		openings: { any }?,
		color: Color3?
	)
		Kit.wall(
			structure,
			point(x0, y, z0),
			point(x1, y, z1),
			height,
			1,
			color or WALL,
			Enum.Material.Plaster,
			openings
		)
		-- Dark wood panelling along the bottom, on both faces.
		local length = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		local frame = CFrame.lookAt(point(x0, y, z0), point(x1, y, z1))
		local cursor = 0
		local holes = table.clone(openings or {})
		table.sort(holes, function(a, b)
			return a.At < b.At
		end)
		local function panel(from: number, to: number)
			if to - from > 0.2 then
				Kit.block(
					dressing,
					frame * CFrame.new(0, 1.75, -(from + to) / 2),
					Vector3.new(1.3, 3.5, to - from),
					WAINSCOT,
					Enum.Material.Wood
				)
				Kit.block(
					dressing,
					frame * CFrame.new(0, 3.6, -(from + to) / 2),
					Vector3.new(1.4, 0.25, to - from),
					TRIM,
					Enum.Material.Metal
				)
			end
		end
		for _, hole in holes do
			if (hole.Bottom or 0) < 3.5 then
				panel(cursor, hole.At - hole.Width / 2)
				cursor = hole.At + hole.Width / 2
			end
		end
		panel(cursor, length)
	end
	-- A doorway's frame: posts and a lintel in trim colour, on the wall from
	-- (x0, z0) to (x1, z1) at distance along it.
	local function doorFrame(x0: number, z0: number, x1: number, z1: number, y: number, along: number, width: number)
		local frame = CFrame.lookAt(point(x0, y, z0), point(x1, y, z1))
		for _, side in { -1, 1 } do
			Kit.block(
				dressing,
				frame * CFrame.new(0, 5, -(along + side * (width / 2 + 0.3))),
				Vector3.new(1.5, 10, 0.6),
				WAINSCOT,
				Enum.Material.Wood
			)
		end
		Kit.block(
			dressing,
			frame * CFrame.new(0, 10.3, -along),
			Vector3.new(1.5, 0.6, width + 1.2),
			WAINSCOT,
			Enum.Material.Wood
		)
	end
	-- Glass in a window opening, with a frame cross, letting moonlight in.
	local function window(
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		y: number,
		along: number,
		width: number,
		bottom: number,
		height: number
	)
		local frame = CFrame.lookAt(point(x0, y, z0), point(x1, y, z1))
		local centre = frame * CFrame.new(0, bottom + height / 2, -along)
		local glass = Kit.slab(structure, centre, Vector3.new(0.3, height, width), hex("#2C3558"), Enum.Material.Glass)
		glass.Transparency = 0.55
		glass.CastShadow = false
		Kit.block(dressing, centre, Vector3.new(0.5, height, 0.25), WAINSCOT, Enum.Material.Wood)
		Kit.block(dressing, centre, Vector3.new(0.5, 0.25, width), WAINSCOT, Enum.Material.Wood)
		Kit.block(
			dressing,
			centre * CFrame.new(0, -height / 2 - 0.2, 0),
			Vector3.new(1.6, 0.4, width + 0.6),
			TRIM,
			Enum.Material.Wood
		)
	end
	local function room(name: string, x0: number, z0: number, x1: number, z1: number, y0: number, y1: number)
		local box = Kit.marker(rooms, name, at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
		box.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	end
	local function spawnAt(x: number, y: number, z: number)
		Kit.marker(spawns, "Spawn", at(x, y + 3, z))
	end
	local function coinAt(x: number, y: number, z: number)
		Kit.marker(coins, "Coin", at(x, y + 2.2, z))
	end
	local function clueAt(x: number, y: number, z: number)
		Kit.marker(clues, "Clue", at(x, y + 2.2, z))
	end
	-- A pair of secret passage ends: each marker stands where a traveller
	-- arrives, facing out of the prop.
	local passageCount = 0
	local function passage(a: CFrame, b: CFrame, label: string)
		passageCount += 1
		local pair = Kit.model(passages, `Passage{passageCount}`)
		pair:SetAttribute("Label", label)
		Kit.marker(pair, "A", a)
		Kit.marker(pair, "B", b)
	end

	-- Floors and the ground ----------------------------------------------
	Kit.slab(structure, at(0, -2, -20), Vector3.new(260, 2, 260), hex("#1E2A20"), Enum.Material.Grass)
	floor(-72, 14, -20, 58, 0, MARBLE, Enum.Material.Marble) -- ballroom
	floor(-20, 14, 20, 58, 0, MARBLE, Enum.Material.Marble) -- foyer
	floor(20, 18, 72, 58, 0, WOOD_FLOOR, Enum.Material.WoodPlanks) -- dining
	floor(-72, -58, -20, 14, 0, WOOD_FLOOR, Enum.Material.WoodPlanks) -- library
	floor(-20, -22, 20, 14, 0, WOOD_FLOOR, Enum.Material.WoodPlanks) -- hall
	floor(20, -22, 72, 18, 0, TILE, Enum.Material.Slate) -- kitchen
	floor(20, -58, 72, -22, 0, WOOD_FLOOR, Enum.Material.WoodPlanks) -- study
	floor(-20, -58, 20, -22, 0, hex("#5C6B5E"), Enum.Material.Cobblestone) -- conservatory
	floor(-72, -104, 72, -58, 0, GRASS, Enum.Material.Grass) -- garden
	-- Upstairs: the balcony over the front of the hall, and the bedroom.
	Kit.slab(structure, at(0, 14.5, 19), Vector3.new(40, 1, 10), WOOD_FLOOR, Enum.Material.WoodPlanks)
	Kit.slab(structure, at(0, 14.5, -4), Vector3.new(40, 1, 36), WOOD_FLOOR, Enum.Material.WoodPlanks)

	-- Ceilings and roofs ---------------------------------------------------
	ceiling(-72, 14, -20, 58, 16)
	ceiling(-72, -58, -20, 14, 16)
	ceiling(20, 18, 72, 58, 16)
	ceiling(20, -22, 72, 18, 16)
	ceiling(20, -58, 72, -22, 16)
	ceiling(-20, 14, 20, 58, 30)
	ceiling(-20, -22, 20, 14, 28)
	-- The conservatory's glass roof.
	local roof = Kit.slab(structure, at(0, 16.5, -40), Vector3.new(40, 1, 36), hex("#9FB8D6"), Enum.Material.Glass)
	roof.Transparency = 0.6
	for i = -3, 3 do
		Kit.block(dressing, at(i * 6, 16.2, -40), Vector3.new(0.5, 0.6, 36), hex("#2A2A30"), Enum.Material.Metal)
	end
	-- A pitched roof over the middle of the house.
	for _, side in { -1, 1 } do
		Kit.wedge(
			structure,
			at(side * 11, 36, 18) * CFrame.Angles(0, -side * PI / 2, 0),
			Vector3.new(80, 10, 22),
			hex("#2A2236"),
			Enum.Material.Slate
		)
	end
	-- Parapets round the wings' flat roofs.
	for _, x in { -72, 72 } do
		Kit.block(structure, at(x, 18, 0), Vector3.new(1.6, 3, 117), WALL_DARK, Enum.Material.Brick)
	end

	-- Walls: outside ------------------------------------------------------
	local DOOR = { Width = 8, Height = 10 }
	local function door(at2: number, width: number?): any
		return { At = at2, Width = width or DOOR.Width, Height = DOOR.Height }
	end
	local function win(at2: number, width: number?, bottom: number?, height: number?): any
		return { At = at2, Width = width or 5, Height = height or 6, Bottom = bottom or 5 }
	end
	-- Front (+Z), west to east.
	wall(-72, 58, -20, 58, 0, 16, { win(10), win(26), win(42) }, WALL_DARK)
	wall(-20, 58, 20, 58, 0, 30, { win(8, 5, 6, 8), win(32, 5, 6, 8), win(20, 8, 18, 9) }, WALL_DARK)
	wall(20, 58, 72, 58, 0, 16, { win(10), win(26), win(42) }, WALL_DARK)
	-- Back (-Z).
	wall(-72, -58, -20, -58, 0, 16, { door(12) }, WALL_DARK)
	wall(20, -58, 72, -58, 0, 16, { door(40) }, WALL_DARK)
	-- West and east.
	wall(-72, -58, -72, 58, 0, 16, { win(76), win(96) }, WALL_DARK)
	wall(72, -58, 72, 58, 0, 16, { win(12), win(30), win(54), win(80), win(106) }, WALL_DARK)
	-- The conservatory's glass back wall, with doors to the garden.
	do
		local a, b = point(-20, 0, -58), point(20, 0, -58)
		for _, piece in Kit.wall(structure, a, b, 16, 0.6, hex("#9FB8D6"), Enum.Material.Glass, { door(20, 10) }) do
			piece.Transparency = 0.55
			piece.CastShadow = false
		end
		for i = 0, 8 do
			Kit.block(dressing, at(-20 + i * 5, 8, -58), Vector3.new(0.4, 16, 0.8), hex("#2A2A30"), Enum.Material.Metal)
		end
	end

	-- Walls: inside -------------------------------------------------------
	-- Foyer sides (two storeys) and the hall's sides with the bedroom over.
	wall(-20, 14, -20, 58, 0, 30, { door(22) })
	wall(20, 14, 20, 58, 0, 30, { door(24) })
	wall(-20, -22, -20, 14, 0, 28, { door(18), win(18, 5, 20, 5) })
	wall(20, -22, 20, 14, 0, 28, { door(18), win(10, 5, 20, 5) })
	-- Hall front (to the foyer, under the balcony) and the bedroom's front.
	wall(-20, 14, 20, 14, 0, 14, { door(20, 10) })
	wall(-20, 14, 20, 14, 15, 13, { door(20) })
	-- Hall back (to the conservatory), up to the bedroom's ceiling.
	wall(-20, -22, 20, -22, 0, 14, { door(20, 12) })
	wall(-20, -22, 20, -22, 15, 13, { win(10, 6, 4, 5), win(30, 6, 4, 5) })
	-- The conservatory's sides, to the library and the study.
	wall(-20, -58, -20, -22, 0, 16, { door(18) })
	wall(20, -58, 20, -22, 0, 16, { door(18) })
	-- Ballroom to library, dining to kitchen, kitchen to study.
	wall(-72, 14, -20, 14, 0, 16, { door(26), door(44) })
	wall(20, 18, 72, 18, 0, 16, { door(26) })
	wall(20, -22, 72, -22, 0, 16, { door(36) })
	-- Door frames on the main doorways.
	doorFrame(-20, 14, -20, 58, 0, 22, 8)
	doorFrame(20, 14, 20, 58, 0, 24, 8)
	doorFrame(-20, -22, -20, 14, 0, 18, 8)
	doorFrame(20, -22, 20, 14, 0, 18, 8)
	doorFrame(-20, 14, 20, 14, 0, 20, 10)
	doorFrame(-20, 14, 20, 14, 15, 20, 8)
	doorFrame(-72, 14, -20, 14, 0, 26, 8)
	doorFrame(-72, 14, -20, 14, 0, 44, 8)
	doorFrame(20, 18, 72, 18, 0, 26, 8)
	doorFrame(20, -22, 72, -22, 0, 36, 8)
	-- Glass in the windows.
	for _, spec in
		{
			{ -72, 58, -20, 58, 10 },
			{ -72, 58, -20, 58, 26 },
			{ -72, 58, -20, 58, 42 },
			{ 20, 58, 72, 58, 10 },
			{ 20, 58, 72, 58, 26 },
			{ 20, 58, 72, 58, 42 },
		}
	do
		window(spec[1], spec[2], spec[3], spec[4], 0, spec[5], 5, 5, 6)
	end
	for _, along in { 76, 96 } do
		window(-72, -58, -72, 58, 0, along, 5, 5, 6)
	end
	for _, along in { 12, 30, 54, 80, 106 } do
		window(72, -58, 72, 58, 0, along, 5, 5, 6)
	end
	window(-20, 58, 20, 58, 0, 8, 5, 6, 8)
	window(-20, 58, 20, 58, 0, 32, 5, 6, 8)
	window(-20, 58, 20, 58, 0, 20, 8, 18, 9)
	window(-20, -22, -20, 14, 0, 18, 5, 20, 5)
	window(20, -22, 20, 14, 0, 10, 5, 20, 5)
	window(-20, -22, 20, -22, 15, 10, 6, 4, 5)
	window(-20, -22, 20, -22, 15, 30, 6, 4, 5)
	-- The front doors, closed for the party.
	for _, side in { -1, 1 } do
		Kit.block(dressing, at(side * 2.6, 6, 57.3), Vector3.new(5, 12, 0.6), hex("#4A2A1A"), Enum.Material.Wood)
		Kit.ball(dressing, at(side * 0.9, 6, 56.9), Vector3.new(0.5, 0.5, 0.5), TRIM, Enum.Material.Metal)
	end
	Kit.block(dressing, at(0, 12.6, 57.2), Vector3.new(11, 1.2, 1), TRIM, Enum.Material.Metal)

	-- Foyer ---------------------------------------------------------------
	room("Foyer", -20, 14, 20, 58, 0, 30)
	room("Balcony", -20, 14, 20, 24, 15, 28)
	for _, side in { -1, 1 } do
		Kit.stairs(structure, at(side * 7, 0, 46), 6, 15, 22, hex("#6E1F2E"), Enum.Material.Fabric)
		-- Banisters both sides of each flight, and newel posts.
		Kit.span(
			dressing,
			point(side * 3.8, 3.5, 46),
			point(side * 3.8, 18.5, 24),
			0.4,
			0.4,
			WAINSCOT,
			Enum.Material.Wood
		)
		Kit.span(
			dressing,
			point(side * 10.2, 3.5, 46),
			point(side * 10.2, 18.5, 24),
			0.4,
			0.4,
			WAINSCOT,
			Enum.Material.Wood
		)
		for _, x in { side * 3.8, side * 10.2 } do
			Kit.solid(Kit.post(dressing, at(x, 2, 46.5), 4, 0.9, WAINSCOT, Enum.Material.Wood))
			Kit.ball(dressing, at(x, 4.3, 46.5), Vector3.new(1, 1, 1), TRIM, Enum.Material.Metal)
		end
		for i = 0, 10 do
			local z = 45 - i * 2
			local y = (46 - z) / 22 * 15
			Kit.block(dressing, at(side * 3.8, y + 1.75, z), Vector3.new(0.2, 3.5, 0.2), WAINSCOT, Enum.Material.Wood)
			Kit.block(dressing, at(side * 10.2, y + 1.75, z), Vector3.new(0.2, 3.5, 0.2), WAINSCOT, Enum.Material.Wood)
		end
	end
	-- The balcony's railing, leaving the stair tops open.
	for _, span in { { -20, -10 }, { -4, 4 }, { 10, 20 } } do
		Kit.span(dressing, point(span[1], 18.5, 24), point(span[2], 18.5, 24), 0.4, 0.4, WAINSCOT, Enum.Material.Wood)
		Kit.barrier(dressing, at((span[1] + span[2]) / 2, 17, 24), Vector3.new(span[2] - span[1], 4, 0.6))
		for x = span[1], span[2], 1.5 do
			Kit.block(dressing, at(x, 16.75, 24), Vector3.new(0.18, 3.5, 0.18), WAINSCOT, Enum.Material.Wood)
		end
	end
	Pieces.rug(dressing, at(0, 0, 36), Vector2.new(16, 20), hex("#6E1F2E"), TRIM)
	Pieces.chandelier(dressing, at(0, 30, 38), 5, WARM, 9)
	for _, side in { -1, 1 } do
		Pieces.armor(dressing, at(side * 15, 0, 44))
		Pieces.plant(dressing, at(side * 18, 0, 55), 11 + side, nil)
		Pieces.painting(
			dressing,
			at(side * 19.4, 21, 40) * (if side < 0 then FACE_E else FACE_W),
			Vector2.new(6, 8),
			TRIM,
			{
				hex("#2C2A4A"),
				hex("#E2C9A6"),
				hex("#6E1F2E"),
			},
			true
		)
		Pieces.sconce(dressing, at(side * 19.3, 8, 30) * (if side < 0 then FACE_E else FACE_W), WARM, side < 0)
		Pieces.sconce(dressing, at(side * 19.3, 8, 50) * (if side < 0 then FACE_E else FACE_W), WARM, false)
	end
	Pieces.painting(
		dressing,
		at(0, 24, 14.6) * FACE_N,
		Vector2.new(9, 7),
		TRIM,
		{ hex("#1B1F4A"), hex("#F2D27A"), hex("#4A2E6B") },
		true
	)
	Pieces.clock(dressing, at(-18.6, 0, 18) * FACE_E)
	Pieces.chair(dressing, at(-6, 15, 16) * FACE_N)
	Pieces.chair(dressing, at(6, 15, 16) * FACE_N)
	Pieces.table(dressing, at(0, 15, 16.5), Vector3.new(4, 3, 2.5), nil, hex("#F2EEE6"))
	Pieces.candelabra(dressing, at(0, 18, 16.5), true)
	spawnAt(-15, 0, 32)
	spawnAt(15, 0, 32)
	spawnAt(0, 15, 19)
	for _, spot in { { -15, 26 }, { 15, 26 }, { 0, 44 }, { -10, 54 }, { 10, 54 }, { 0, 20 } } do
		coinAt(spot[1], 0, spot[2])
	end
	coinAt(-15, 15, 18)
	coinAt(15, 15, 18)
	clueAt(-18, 0, 50)
	clueAt(18, 15, 21)

	-- Ballroom ------------------------------------------------------------
	room("Ballroom", -72, 14, -20, 58, 0, 16)
	Pieces.rug(dressing, at(-44, 0, 36), Vector2.new(30, 30), hex("#1B1F4A"), TRIM)
	Pieces.rug(dressing, at(-44, 0.05, 36), Vector2.new(18, 18), hex("#4A2E6B"), hex("#F2D27A"))
	Pieces.chandelier(dressing, at(-52, 16, 36), 4, WARM, 5)
	Pieces.chandelier(dressing, at(-34, 16, 36), 4, WARM, 5)
	-- A stage at the west end, with curtains.
	Kit.slab(structure, at(-66, 0.75, 36), Vector3.new(10, 1.5, 28), hex("#3B2416"), Enum.Material.WoodPlanks)
	Kit.stairs(structure, at(-58.6, 0, 30) * FACE_W, 6, 1.5, 2.4, hex("#3B2416"), Enum.Material.WoodPlanks)
	for _, z in { 23, 49 } do
		Kit.block(dressing, at(-62, 8, z), Vector3.new(1, 15, 5), hex("#8C1C3A"), Enum.Material.Fabric)
	end
	Kit.block(dressing, at(-62, 14.5, 36), Vector3.new(1, 3, 30), hex("#8C1C3A"), Enum.Material.Fabric)
	Pieces.piano(dressing, at(-66, 1.5, 44) * FACE_E)
	for i = 0, 2 do
		local spot = Kit.glow(dressing, at(-60, 14.5, 28 + i * 8), Vector3.new(0.8, 0.8, 0.8), hex("#FFE7A3"), true)
		Kit.light(spot, hex("#FFE7A3"), 14, 1)
	end
	-- Tables round the dance floor.
	for _, spot in { { -30, 52 }, { -44, 53 }, { -56, 52 }, { -30, 20 }, { -44, 19 } } do
		Pieces.table(dressing, at(spot[1], 0, spot[2]), Vector3.new(5, 3, 3.5), nil, hex("#F2EEE6"))
		Pieces.candelabra(dressing, at(spot[1], 3, spot[2]), false)
	end
	Pieces.fireplace(dressing, at(-46, 0, 56.8) * CFrame.Angles(0, 0, 0))
	Pieces.painting(
		dressing,
		at(-46, 11, 57.4),
		Vector2.new(10, 4),
		TRIM,
		{ hex("#1B1F4A"), hex("#3A4A7A"), hex("#C9A44C"), hex("#2B4A2E") }
	)
	spawnAt(-44, 0, 28)
	spawnAt(-36, 0, 44)
	spawnAt(-64, 1.5, 36)
	for _, spot in { { -50, 30 }, { -38, 42 }, { -44, 36 }, { -28, 30 }, { -58, 46 }, { -60, 18 }, { -24, 46 } } do
		coinAt(spot[1], 0, spot[2])
	end
	coinAt(-68, 1.5, 28)
	clueAt(-68, 1.5, 46)
	clueAt(-24, 0, 18)

	-- Library -------------------------------------------------------------
	room("Library", -72, -58, -20, 14, 0, 16)
	-- Shelves along the outer walls.
	for i = 0, 4 do
		Pieces.bookshelf(dressing, at(-70.6, 0, -50 + i * 12) * FACE_E, 10, 13, 100 + i)
	end
	for i = 0, 1 do
		Pieces.bookshelf(dressing, at(-30 - i * 12, 0, -56.6) * FACE_N, 10, 13, 120 + i)
	end
	-- Rows of free-standing shelves make aisles to dodge between.
	for row, z in { -40, -26, -12 } do
		for i, spec in { { -58, 12 }, { -38, 10 } } do
			Pieces.bookshelf(dressing, at(spec[1], 0, z + 1) * FACE_N, spec[2], 11, 140 + row * 4 + i)
			Pieces.bookshelf(dressing, at(spec[1], 0, z - 1), spec[2], 11, 160 + row * 4 + i)
		end
	end
	-- A reading nook: armchairs, a rug, a lamp and a globe.
	Pieces.rug(dressing, at(-30, 0, 2), Vector2.new(14, 12), hex("#2E5E3A"), TRIM)
	Pieces.chair(dressing, at(-33, 0, 6) * CFrame.Angles(0, 0.4, 0), WAINSCOT, hex("#2E5E3A"))
	Pieces.chair(dressing, at(-26, 0, 6) * CFrame.Angles(0, -0.4, 0), WAINSCOT, hex("#2E5E3A"))
	Pieces.table(dressing, at(-30, 0, 0), Vector3.new(4, 2.4, 3), nil, nil)
	Pieces.candelabra(dressing, at(-30, 2.4, 0), true)
	do
		local globe = Kit.model(dressing, "Globe")
		Kit.post(globe, at(-24, 1.5, -8), 3, 0.3, WAINSCOT)
		Kit.ball(globe, at(-24, 4, -8), Vector3.new(2.4, 2.4, 2.4), hex("#2F6E8E"))
		Kit.ball(globe, at(-24.2, 4.4, -8.9), Vector3.new(1.2, 0.8, 0.6), hex("#5E8C4A"))
	end
	Pieces.chandelier(dressing, at(-46, 16, -20), 3, WARM, 4)
	Pieces.chandelier(dressing, at(-46, 16, 0), 3, WARM, 4)
	-- The secret bookcase, against the hall wall; a glowing book marks it.
	Pieces.bookshelf(dressing, at(-21.2, 0, -28) * FACE_W, 8, 12, 99)
	Kit.glow(dressing, at(-22.4, 6.5, -26.5), Vector3.new(0.3, 1.4, 0.9), hex("#B067FF"))
	local libraryEnd = at(-25, 3, -28) * FACE_W
	spawnAt(-46, 0, 6)
	spawnAt(-52, 0, -33)
	for _, spot in { { -54, -19 }, { -42, -33 }, { -66, -47 }, { -30, -50 }, { -36, 8 }, { -64, 6 }, { -48, -5 } } do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(-66, 0, -19)
	clueAt(-26, 0, -54)

	-- Hall ----------------------------------------------------------------
	room("Hall", -20, -22, 20, 14, 0, 14)
	Pieces.rug(dressing, at(0, 0, -4), Vector2.new(10, 30), hex("#6E1F2E"), TRIM)
	for _, z in { -14, 6 } do
		for _, side in { -1, 1 } do
			Pieces.sconce(dressing, at(side * 19.3, 7, z) * (if side < 0 then FACE_E else FACE_W), WARM, z == 6)
		end
	end
	Pieces.armor(dressing, at(-16, 0, -18) * FACE_N)
	Pieces.plant(dressing, at(16, 0, -18), 21)
	Pieces.table(dressing, at(16, 0, 8), Vector3.new(3, 3, 5), nil, hex("#4A2E6B"))
	Pieces.painting(
		dressing,
		at(-19.4, 7.5, -4) * FACE_E,
		Vector2.new(5, 3.5),
		TRIM,
		{ hex("#0F1A3A"), hex("#C0C8FF"), hex("#1E2A20") }
	)
	spawnAt(0, 0, -10)
	coinAt(-8, 0, -14)
	coinAt(8, 0, 2)
	coinAt(0, 0, 10)
	clueAt(-16, 0, 10)

	-- Master bedroom (upstairs) ------------------------------------------
	room("Bedroom", -20, -22, 20, 14, 15, 28)
	Pieces.bed(dressing, at(0, 15, -16) * FACE_N)
	Pieces.rug(dressing, at(0, 15, -2), Vector2.new(16, 12), hex("#4A2E6B"), TRIM)
	Pieces.chandelier(dressing, at(0, 28, -4), 3, WARM, 3)
	Pieces.wardrobe(dressing, at(-15, 15, -18) * CFrame.Angles(0, -3 * PI / 4, 0))
	local bedroomWardrobe = at(-12, 18, -15) * CFrame.Angles(0, -3 * PI / 4, 0)
	Pieces.fireplace(dressing, at(18.6, 15, -4) * FACE_W)
	local bedroomFire = at(15, 18, -4) * FACE_W
	Pieces.table(dressing, at(-15, 15, 6), Vector3.new(5, 3, 2.5), nil, hex("#F2EEE6"))
	Pieces.candelabra(dressing, at(-15, 18, 6), false)
	Pieces.chair(dressing, at(10, 15, 8) * CFrame.Angles(0, -0.5, 0), nil, hex("#4A2E6B"))
	spawnAt(-6, 15, 0)
	coinAt(6, 15, -10)
	coinAt(-10, 15, 2)
	coinAt(12, 15, 4)
	clueAt(10, 15, -18)

	-- Conservatory ----------------------------------------------------------
	room("Conservatory", -20, -58, 20, -22, 0, 16)
	Pieces.fountain(dressing, at(0, 0, -40), 6, hex("#B8B2A6"), hex("#3E8EB8"))
	do
		local statue = Kit.model(dressing, "Statue")
		Kit.solid(Kit.post(statue, at(0, 3, -40), 4, 1.4, hex("#D9D2C6"), Enum.Material.Marble))
		Kit.ball(statue, at(0, 6.2, -40), Vector3.new(2.2, 2.2, 2.2), hex("#D9D2C6"), Enum.Material.Marble)
		Kit.block(statue, at(0, 6.4, -41.1), Vector3.new(2, 0.6, 0.3), hex("#1E1B26"))
	end
	for i, spot in
		{ { -16, -26 }, { 16, -26 }, { -16, -54 }, { 16, -54 }, { -16, -40 }, { 16, -40 }, { -8, -54 }, { 8, -26 } }
	do
		Pieces.plant(dressing, at(spot[1], 0, spot[2]), 30 + i, hex(if i % 2 == 0 then "#2F6B3A" else "#3E7B35"))
	end
	for _, spot in { { -9, -33 }, { 9, -47 } } do
		Pieces.bench(dressing, at(spot[1], 0, spot[2]) * CFrame.Angles(0, if spot[1] < 0 then -PI / 2 else PI / 2, 0))
	end
	local moonlight = Kit.block(dressing, at(0, 15.5, -40), Vector3.new(1, 1, 1), MOON)
	moonlight.Transparency = 1
	Kit.light(moonlight, MOON, 30, 0.9)
	spawnAt(-10, 0, -40)
	spawnAt(10, 0, -32)
	-- (The fifth coin sat inside the fountain's rim; it's just outside now.)
	for _, spot in { { 0, -28 }, { -12, -48 }, { 12, -50 }, { -6, -46 }, { 10, -40 } } do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(-18, 0, -30)

	-- Dining hall -----------------------------------------------------------
	room("Dining", 20, 18, 72, 58, 0, 16)
	Pieces.rug(dressing, at(46, 0, 38), Vector2.new(34, 14), hex("#6E1F2E"), TRIM)
	do
		local tableModel = Pieces.table(dressing, at(46, 0, 38), Vector3.new(28, 3.2, 6), nil, hex("#F2EEE6"))
		for i = -5, 5 do
			Kit.post(tableModel, at(46 + i * 2.5, 3.25, 36.2), 0.1, 1.2, hex("#F4F1E8"))
			Kit.post(tableModel, at(46 + i * 2.5, 3.25, 39.8), 0.1, 1.2, hex("#F4F1E8"))
		end
		for i = -1, 1 do
			Pieces.candelabra(dressing, at(46 + i * 9, 3.2, 38), i == 0)
		end
	end
	for i = -4, 4 do
		Pieces.chair(dressing, at(46 + i * 3, 0, 33.5) * FACE_N, nil, hex("#6E1F2E"))
		Pieces.chair(dressing, at(46 + i * 3, 0, 42.5), nil, hex("#6E1F2E"))
	end
	Pieces.chandelier(dressing, at(38, 16, 38), 3.5, WARM, 5)
	Pieces.chandelier(dressing, at(54, 16, 38), 3.5, WARM, 5)
	Pieces.fireplace(dressing, at(70.8, 0, 38) * FACE_W)
	Pieces.counter(dressing, at(46, 0, 56.4) * FACE_N, 14, hex("#3B2416"), hex("#5A3A22"))
	Pieces.painting(
		dressing,
		at(46, 10, 57.4),
		Vector2.new(12, 4),
		TRIM,
		{ hex("#2B4A2E"), hex("#E2C9A6"), hex("#8C6A2E") }
	)
	spawnAt(30, 0, 26)
	spawnAt(62, 0, 50)
	for _, spot in { { 28, 38 }, { 64, 38 }, { 46, 28 }, { 46, 48 }, { 36, 52 }, { 60, 24 } } do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(68, 0, 54)
	clueAt(24, 0, 54)

	-- Kitchen ---------------------------------------------------------------
	room("Kitchen", 20, -22, 72, 18, 0, 16)
	Pieces.counter(dressing, at(62, 0, 16.4), 14)
	Pieces.counter(dressing, at(70.4, 0, 2) * FACE_W, 14)
	Pieces.counter(dressing, at(44, 0, -2), 16, hex("#3C3A40"), hex("#7A5230"))
	Pieces.stove(dressing, at(30, 0, 15.5))
	for i = 0, 3 do
		Kit.post(dressing, at(38 + i * 2.6, 12, -2), 1, 0.9, hex("#B87333"), Enum.Material.Metal)
		Kit.block(dressing, at(38 + i * 2.6, 14, -2), Vector3.new(0.1, 3.4, 0.1), hex("#2A2A30"))
	end
	Kit.block(dressing, at(42, 15.6, -2), Vector3.new(14, 0.3, 0.3), hex("#2A2A30"), Enum.Material.Metal)
	for _, spot in { { 66, -18 }, { 62, -18 }, { 66, -14 } } do
		Pieces.barrel(dressing, at(spot[1], 0, spot[2]))
	end
	Pieces.crate(dressing, at(24, 0, -18))
	Pieces.crate(dressing, at(24, 3, -18), 2.4)
	Pieces.crate(dressing, at(28, 0, -18.5), 2.6)
	-- The pantry: a cupboard with a passage behind it.
	do
		local pantry = Kit.model(dressing, "Pantry")
		Kit.solid(
			Kit.block(pantry, at(70.6, 5, -10), Vector3.new(1.4, 10, 7), hex("#5A3A22"), Enum.Material.WoodPlanks)
		)
		for y = 2, 8, 2 do
			Kit.block(pantry, at(69.8, y, -10), Vector3.new(0.4, 0.2, 6.6), hex("#3B2416"))
			for j = -2, 2 do
				Kit.post(
					pantry,
					at(69.6, y + 0.6, -10 + j * 1.2),
					1,
					0.7,
					hex(({ "#B5651D", "#E2C9A6", "#5E8C4A" })[(j % 3) + 1])
				)
			end
		end
		Kit.glow(pantry, at(69.8, 9.2, -10), Vector3.new(0.3, 0.5, 2), hex("#B067FF"))
	end
	local pantryEnd = at(66, 3, -10) * FACE_W
	for _, spot in { { 30, -10 }, { 42, 6 }, { 56, -14 }, { 60, 10 } } do
		local lamp = Kit.glow(dressing, at(spot[1], 13.5, spot[2]), Vector3.new(1.2, 1.2, 1.2), WARM, true)
		Kit.post(dressing, at(spot[1], 14.8, spot[2]), 2, 0.1, hex("#2A2A30"))
		if spot[1] == 42 then
			Kit.light(lamp, WARM, 30, 1.4)
		end
	end
	spawnAt(34, 0, 6)
	spawnAt(58, 0, -6)
	for _, spot in { { 30, -4 }, { 56, 4 }, { 46, -14 }, { 64, 12 }, { 36, 10 } } do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(24, 0, 12)
	clueAt(68, 0, -20)

	-- Study -----------------------------------------------------------------
	room("Study", 20, -58, 72, -22, 0, 16)
	Pieces.rug(dressing, at(46, 0, -40), Vector2.new(16, 12), hex("#1F4E5F"), TRIM)
	Pieces.table(dressing, at(46, 0, -46), Vector3.new(8, 3, 4), hex("#3B2416"), nil)
	Pieces.chair(dressing, at(46, 0, -49.5), nil, hex("#1F4E5F"))
	Pieces.candelabra(dressing, at(44, 3, -46), true)
	for i = 0, 2 do
		Pieces.bookshelf(dressing, at(28 + i * 10, 0, -56.6) * FACE_N, 9, 12, 200 + i)
	end
	Pieces.wardrobe(dressing, at(24, 0, -30) * FACE_E)
	Pieces.clock(dressing, at(66, 0, -23.4))
	-- A portrait that swings open onto a passage.
	Pieces.painting(
		dressing,
		at(71.4, 7, -40) * FACE_W,
		Vector2.new(5, 7),
		TRIM,
		{ hex("#3A2F55"), hex("#E2C9A6"), hex("#1F4E5F") },
		true
	)
	Kit.glow(dressing, at(71.2, 11.2, -40), Vector3.new(0.3, 0.3, 4.5), hex("#B067FF"))
	local studyEnd = at(67, 3, -40) * FACE_W
	Pieces.chandelier(dressing, at(46, 16, -36), 3, WARM, 4)
	spawnAt(36, 0, -36)
	spawnAt(58, 0, -50)
	for _, spot in { { 28, -50 }, { 60, -30 }, { 46, -34 }, { 66, -52 }, { 36, -26 } } do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(24, 0, -54)
	clueAt(68, 0, -30)

	-- Garden ------------------------------------------------------------------
	room("Garden", -72, -104, 72, -58, 0, 20)
	-- Fences round the garden, and a high wall of trees beyond them.
	Pieces.fence(dressing, point(-72, 0, -104), point(72, 0, -104), 7)
	Pieces.fence(dressing, point(-72, 0, -104), point(-72, 0, -58), 7)
	Pieces.fence(dressing, point(72, 0, -104), point(72, 0, -58), 7)
	for i = 0, 11 do
		Pieces.deadTree(dressing, at(-66 + i * 12, 0, -112), 18 + (i % 3) * 3, 300 + i)
	end
	-- A path from the conservatory to the gazebo.
	Kit.block(dressing, at(0, 0.05, -70), Vector3.new(8, 0.1, 24), hex("#8E8A96"), Enum.Material.Cobblestone)
	-- The gazebo.
	do
		local gazebo = Kit.model(dressing, "Gazebo")
		local centre = at(0, 0, -86)
		Kit.slab(gazebo, centre * CFrame.new(0, 0.5, 0), Vector3.new(18, 1, 18), hex("#E8E2D6"), Enum.Material.Marble)
		for i = 0, 7 do
			local angle = i / 8 * PI * 2
			Pieces.column(gazebo, centre * CFrame.new(math.cos(angle) * 8, 1, math.sin(angle) * 8), 10)
		end
		Kit.post(gazebo, centre * CFrame.new(0, 11.3, 0), 1, 19, hex("#E8E2D6"), Enum.Material.Marble)
		for i = 1, 4 do
			Kit.post(
				gazebo,
				centre * CFrame.new(0, 11.5 + i * 0.9, 0),
				0.9,
				19 - i * 4,
				hex("#3A4A7A"),
				Enum.Material.Slate
			)
		end
		local lantern = Kit.glow(gazebo, centre * CFrame.new(0, 9, 0), Vector3.new(1.4, 1.8, 1.4), WARM)
		Kit.light(lantern, WARM, 26, 1.4, true)
		Kit.post(gazebo, centre * CFrame.new(0, 10.2, 0), 1.6, 0.12, hex("#2A2A30"))
		Pieces.bench(gazebo, centre * CFrame.new(-4, 1, 0) * CFrame.Angles(0, -PI / 2, 0))
		Pieces.bench(gazebo, centre * CFrame.new(4, 1, 0) * CFrame.Angles(0, PI / 2, 0))
	end
	-- Hedges in short runs, so there's always a way round.
	for _, run in
		{
			{ -60, -66, -30, -66 },
			{ 30, -66, 60, -66 },
			{ -50, -78, -50, -96 },
			{ 50, -78, 50, -96 },
			{ -36, -80, -20, -80 },
			{ 20, -80, 36, -80 },
			{ -36, -96, -16, -96 },
			{ 16, -96, 36, -96 },
			{ -66, -86, -58, -86 },
			{ 58, -86, 66, -86 },
		}
	do
		Pieces.hedge(structure, point(run[1], 0, run[2]), point(run[3], 0, run[4]), 7)
	end
	-- The family plot: graves inside a little fence.
	for i = 0, 5 do
		Pieces.gravestone(dressing, at(56 + (i % 3) * 5, 0, -74 - (i // 3) * 6) * FACE_N, 400 + i)
	end
	for i = 0, 7 do
		Pieces.pumpkin(dressing, at(-62 + (i % 4) * 4, 0, -96 - (i // 4) * 4), 2 + (i % 3) * 0.6, i % 2 == 0)
	end
	for _, spot in { { -30, -60 }, { 30, -60 }, { -66, -72 }, { 66, -100 }, { 0, -100 } } do
		Pieces.lamp(dressing, at(spot[1], 0, spot[2]), MOON, 10)
	end
	spawnAt(-26, 0, -88)
	spawnAt(26, 0, -88)
	for _, spot in
		{ { -40, -72 }, { 40, -72 }, { -60, -96 }, { 60, -96 }, { 0, -96 }, { -24, -88 }, { 24, -88 }, { 0, -76 } }
	do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(-62, 0, -78)
	clueAt(44, 0, -100)

	-- Secret passages -----------------------------------------------------
	passage(libraryEnd, bedroomWardrobe, "Hidden bookcase")
	passage(at(-46, 3, 53), pantryEnd, "Hidden fireplace")
	passage(studyEnd, bedroomFire, "Hidden portrait")

	-- An invisible ceiling over the garden and walls round the outside, so
	-- nobody climbs out.
	Kit.barrier(structure, at(0, 40, -81), Vector3.new(150, 1, 48))
	Kit.barrier(structure, at(0, 20, 60), Vector3.new(150, 40, 2))

	map.WorldPivot = origin
	return map
end

return Manor
