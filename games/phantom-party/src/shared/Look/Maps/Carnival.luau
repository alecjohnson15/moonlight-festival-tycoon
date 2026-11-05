-- Starlight Carnival: a fairground after closing time, all neon and
-- string lights under the stars. It's open ground with long sightlines (good
-- for a Guardian with a steady aim) broken up by places to duck into: a
-- midway of game booths, a carousel that still turns, a funhouse with a
-- mirror maze, the big top with its ring and bleachers, a ghost-train
-- tunnel, a food court and a back lot of trailers. A ferris wheel turns over
-- it all. Two secret passages: the fortune teller's curtain and a manhole.
--
-- Plan, looking down with the entrance at the top (+Z):
--
--        Bandstand     Entrance arch      Trailers
--   Carousel        |  Midway   |     Funhouse
--        Food court |  booths   |     Back lot
--   Ghost train      Big top         Ferris wheel

local Kit = require(script.Parent.Parent.Kit)
local Pieces = require(script.Parent.Parent.Pieces)

local Carnival = {}

Carnival.Id = "carnival"
Carnival.Name = "Starlight Carnival"
Carnival.Blurb = "The fair's closed, but the lights are on. Watch the mirrors."

Carnival.Lighting = {
	ClockTime = 22.5,
	Brightness = 2,
	Ambient = "#4A4060",
	OutdoorAmbient = "#5E5788",
	FogColor = "#2A2244",
	Atmosphere = { Density = 0.22, Haze = 1.2, Color = "#7A6AB0", Decay = "#3A2A60" },
	ColorShift = "#FFB0D0",
	Exposure = 0.3,
}

local hex = Kit.color
local PI = math.pi

local RED = hex("#D7263D")
local CREAM = hex("#F7F1E3")
local GOLD = hex("#F5C451")
local TEAL = hex("#2EC4B6")
local PURPLE = hex("#7B2CBF")
local NAVY = hex("#1B1F4A")
local DIRT = hex("#8A6A48")
local GRASS = hex("#2E4A2C")
local WOOD = hex("#6B4426")
local BULBS = { hex("#FFD166"), hex("#FF5D8F"), hex("#3BCEAC"), hex("#5D9CEC"), hex("#FFFFFF") }

function Carnival.build(origin: CFrame): Model
	local map = Kit.model(nil, Carnival.Id)
	map:SetAttribute("DisplayName", Carnival.Name)
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
	local function room(name: string, x0: number, z0: number, x1: number, z1: number)
		local box = Kit.marker(rooms, name, at((x0 + x1) / 2, 15, (z0 + z1) / 2))
		box.Size = Vector3.new(x1 - x0, 30, z1 - z0)
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
	local passageCount = 0
	local function passage(a: CFrame, b: CFrame, label: string)
		passageCount += 1
		local pair = Kit.model(passages, `Passage{passageCount}`)
		pair:SetAttribute("Label", label)
		Kit.marker(pair, "A", a)
		Kit.marker(pair, "B", b)
	end
	-- A ring of points round a centre, for anything round.
	local function around(cx: number, cz: number, radius: number, count: number, offset: number?): { { number } }
		local list = {}
		for i = 0, count - 1 do
			local angle = (i + (offset or 0)) / count * PI * 2
			table.insert(list, { cx + math.cos(angle) * radius, cz + math.sin(angle) * radius, angle })
		end
		return list
	end

	-- Ground, paths and the fence -----------------------------------------
	Kit.slab(structure, at(0, -1, 0), Vector3.new(240, 2, 240), GRASS, Enum.Material.Grass)
	Kit.slab(structure, at(0, 0.05, 20), Vector3.new(16, 0.1, 120), DIRT, Enum.Material.Ground)
	Kit.slab(structure, at(0, 0.05, -18), Vector3.new(150, 0.1, 12), DIRT, Enum.Material.Ground)
	Kit.slab(structure, at(-48, 0.05, 2), Vector3.new(12, 0.1, 60), DIRT, Enum.Material.Ground)
	Kit.slab(structure, at(48, 0.05, 2), Vector3.new(12, 0.1, 60), DIRT, Enum.Material.Ground)
	for _, edge in
		{
			{ -90, -90, 90, -90 },
			{ -90, 90, -12, 90 },
			{ 12, 90, 90, 90 },
			{ -90, -90, -90, 90 },
			{ 90, -90, 90, 90 },
		}
	do
		Pieces.fence(dressing, point(edge[1], 0, edge[2]), point(edge[3], 0, edge[4]), 7, hex("#2A2A36"))
	end
	-- The gate itself is locked for the night.
	Kit.barrier(structure, at(0, 10, 90), Vector3.new(24, 20, 1))
	for i = 0, 13 do
		local x = -84 + i * 13
		Pieces.tree(dressing, at(x, 0, -100), 20 + (i % 3) * 4, 500 + i, hex("#1E3326"))
		Pieces.tree(dressing, at(x + 6, 0, 100), 18 + (i % 4) * 3, 520 + i, hex("#1E3326"))
		Pieces.tree(dressing, at(-100, 0, x), 19 + (i % 3) * 3, 540 + i, hex("#1E3326"))
		Pieces.tree(dressing, at(100, 0, x + 4), 21 + (i % 2) * 4, 560 + i, hex("#1E3326"))
	end
	Kit.barrier(structure, at(0, 50, 0), Vector3.new(182, 1, 182))

	-- The entrance arch --------------------------------------------------
	room("Entrance", -24, 66, 24, 90)
	do
		local arch = Kit.model(dressing, "Arch")
		for _, side in { -1, 1 } do
			Kit.solid(Kit.post(arch, at(side * 12, 9, 88), 18, 2.4, RED))
			for y = 2, 16, 3 do
				Kit.glow(arch, at(side * 12, y, 86.7), Vector3.new(0.6, 0.6, 0.6), BULBS[(y % #BULBS) + 1], true)
			end
			Kit.ball(arch, at(side * 12, 18.6, 88), Vector3.new(3, 3, 3), GOLD, Enum.Material.Metal)
		end
		Kit.block(arch, at(0, 17, 88), Vector3.new(26, 4, 1.2), NAVY)
		Kit.sign(arch, at(0, 17, 87.3), Vector3.new(22, 3, 0.2), NAVY, "STARLIGHT CARNIVAL", GOLD)
		Kit.sign(
			arch,
			at(0, 17, 88.7) * CFrame.Angles(0, PI, 0),
			Vector3.new(22, 3, 0.2),
			NAVY,
			"STARLIGHT CARNIVAL",
			GOLD
		)
		for i = -5, 5 do
			Kit.glow(arch, at(i * 2.2, 19.3, 87.4), Vector3.new(0.6, 0.6, 0.6), BULBS[(i + 6) % #BULBS + 1], true)
		end
		local arc = Kit.glow(arch, at(0, 21, 88), Vector3.new(6, 1.4, 0.6), GOLD)
		Kit.light(arc, GOLD, 30, 1.6)
		-- Ticket booths either side of the gate.
		for _, side in { -1, 1 } do
			local booth = at(side * 19, 0, 82)
			Kit.solid(Kit.block(arch, booth * CFrame.new(0, 4, 0), Vector3.new(6, 8, 6), RED, Enum.Material.WoodPlanks))
			local glass = Kit.block(
				arch,
				booth * CFrame.new(0, 5, -3.05),
				Vector3.new(4, 2.6, 0.1),
				hex("#9FB8D6"),
				Enum.Material.Glass
			)
			glass.Transparency = 0.4
			Kit.wedge(arch, booth * CFrame.new(0, 9, 0) * CFrame.Angles(0, PI / 2, 0), Vector3.new(7, 2, 7), GOLD)
			Kit.sign(arch, booth * CFrame.new(0, 7.2, -3.1), Vector3.new(4.6, 1, 0.1), CREAM, "TICKETS", RED)
		end
	end
	spawnAt(-6, 0, 76)
	spawnAt(6, 0, 76)
	for _, spot in { { -18, 74 }, { 18, 74 }, { 0, 84 } } do
		coinAt(spot[1], 0, spot[2])
	end

	-- The midway: game booths either side of the main path ---------------
	room("Midway", -24, -10, 24, 66)
	local boothNames = {
		"RING TOSS",
		"DUCK POND",
		"BALLOON POP",
		"HOOP SHOT",
		"COIN TOSS",
		"BOTTLE BOWL",
		"HIGH STRIKER",
		"LUCKY WHEEL",
	}
	local boothColors = { RED, TEAL, PURPLE, hex("#FF8C1A"), hex("#3A86FF"), hex("#FF5D8F"), hex("#2E9E5B"), GOLD }
	local function booth(base: CFrame, index: number)
		local model = Kit.model(dressing, "Booth")
		local color = boothColors[index]
		local random = Kit.random(700 + index)
		-- Back and sides, the counter and the posts.
		Kit.solid(
			Kit.block(model, base * CFrame.new(0, 4.5, 3), Vector3.new(10, 9, 0.6), color, Enum.Material.WoodPlanks)
		)
		for _, side in { -1, 1 } do
			Kit.solid(
				Kit.block(
					model,
					base * CFrame.new(side * 4.8, 4.5, 0.4),
					Vector3.new(0.4, 9, 5.8),
					CREAM,
					Enum.Material.WoodPlanks
				)
			)
			Kit.post(model, base * CFrame.new(side * 4.8, 5, -3), 10, 0.5, CREAM)
		end
		Kit.solid(
			Kit.block(
				model,
				base * CFrame.new(0, 1.8, -2.4),
				Vector3.new(9.2, 3.6, 1.2),
				color,
				Enum.Material.WoodPlanks
			)
		)
		Kit.block(model, base * CFrame.new(0, 3.7, -2.5), Vector3.new(9.8, 0.25, 1.6), WOOD, Enum.Material.Wood)
		-- A striped awning sloping out over the counter.
		for stripe = 0, 4 do
			Kit.wedge(
				model,
				base * CFrame.new(-4 + stripe * 2, 9.4, -2.5) * CFrame.Angles(0, PI, 0),
				Vector3.new(2, 1.4, 3.4),
				if stripe % 2 == 0 then color else CREAM,
				Enum.Material.Fabric
			)
		end
		Kit.sign(model, base * CFrame.new(0, 10.8, 2.55), Vector3.new(8, 1.6, 0.2), NAVY, boothNames[index], GOLD)
		Kit.block(model, base * CFrame.new(0, 10.8, 2.75), Vector3.new(8.4, 2, 0.2), NAVY)
		-- Prizes on shelves at the back: plush balls and stars.
		for shelf = 0, 1 do
			Kit.block(model, base * CFrame.new(0, 4.5 + shelf * 2.2, 2.3), Vector3.new(9, 0.2, 1), WOOD)
			for i = -3, 3 do
				local prize = Kit.ball(
					model,
					base * CFrame.new(i * 1.25, 5.2 + shelf * 2.2, 2.2),
					Vector3.new(1, 1.1, 0.9),
					BULBS[random.integer(1, #BULBS)],
					Enum.Material.Fabric
				)
				prize.Name = "Prize"
			end
		end
		-- The game on the counter.
		if index % 2 == 0 then
			for i = -2, 2 do
				Kit.post(model, base * CFrame.new(i * 1.4, 4.3, -2.4), 1, 0.4, hex("#7FC97F"), Enum.Material.Glass)
			end
		else
			for i = -2, 2 do
				Kit.ball(model, base * CFrame.new(i * 1.4, 4.2, -2.4), Vector3.new(0.7, 0.7, 0.7), hex("#FFE066"))
			end
		end
		local bulb = Kit.glow(model, base * CFrame.new(0, 8.6, -1), Vector3.new(0.8, 0.8, 0.8), hex("#FFE7A3"), true)
		if index % 2 == 1 then
			Kit.light(bulb, hex("#FFE7A3"), 18, 1.2)
		end
		for i = -4, 4, 2 do
			Kit.glow(
				model,
				base * CFrame.new(i, 8.2, -3.2),
				Vector3.new(0.4, 0.4, 0.4),
				BULBS[(i + 5) % #BULBS + 1],
				true
			)
		end
		return model
	end
	for i, z in { 58, 42, 26, 10 } do
		booth(at(-14, 0, z) * CFrame.Angles(0, -PI / 2, 0), i * 2 - 1)
		booth(at(14, 0, z) * CFrame.Angles(0, PI / 2, 0), i * 2)
	end
	-- Light poles along the path, with bulbs strung between them.
	for _, z in { 66, 50, 34, 18, 2 } do
		for _, side in { -1, 1 } do
			Pieces.lamp(dressing, at(side * 8.5, 0, z), hex("#FFE7A3"), 12)
		end
		Pieces.stringLights(dressing, point(-8.5, 12.5, z), point(8.5, 12.5, z), BULBS, 2.5)
	end
	for _, z in { 66, 50, 34 } do
		Pieces.stringLights(dressing, point(-8.5, 12.5, z), point(8.5, 12.5, z - 16), BULBS, 2)
	end
	spawnAt(0, 0, 50)
	spawnAt(0, 0, 18)
	for _, spot in { { -5, 62 }, { 5, 54 }, { -5, 46 }, { 5, 38 }, { -5, 30 }, { 5, 22 }, { -5, 14 }, { 5, 6 } } do
		coinAt(spot[1], 0, spot[2])
	end
	clueAt(-20, 0, 50)
	clueAt(20, 0, 18)

	-- The carousel ----------------------------------------------------------
	room("Carousel", -70, 8, -26, 52)
	do
		local cx, cz, radius = -48, 30, 13
		local base = Kit.model(structure, "CarouselBase")
		Kit.solid(Kit.post(base, at(cx, 0.6, cz), 1.2, radius * 2, hex("#D9C7A6"), Enum.Material.WoodPlanks))
		Kit.post(base, at(cx, 0.4, cz), 0.8, radius * 2 + 1, GOLD, Enum.Material.Metal)
		Kit.solid(Kit.post(base, at(cx, 7, cz), 12, 4.5, hex("#F2E9D0")))
		-- Mirrored panels on the centre column.
		for _, spot in around(cx, cz, 2.3, 8) do
			local panel = Kit.block(
				base,
				at(spot[1], 7, spot[2]) * CFrame.Angles(0, -spot[3] + PI / 2, 0),
				Vector3.new(1.6, 6, 0.1),
				hex("#C9D6E8"),
				Enum.Material.Glass
			)
			panel.Reflectance = 0.5
		end
		local ride = Kit.model(dressing, "CarouselRide")
		-- The canopy: a scalloped valance, then a peaked roof in stripes.
		Kit.post(ride, at(cx, 13.2, cz), 0.6, radius * 2 + 2, GOLD, Enum.Material.Metal)
		for i, spot in around(cx, cz, radius + 0.6, 24) do
			Kit.block(
				ride,
				at(spot[1], 12.3, spot[2]) * CFrame.Angles(0, -spot[3] + PI / 2, 0),
				Vector3.new(3.6, 1.6, 0.3),
				if i % 2 == 0 then RED else CREAM,
				Enum.Material.Fabric
			)
			Kit.glow(ride, at(spot[1], 11.3, spot[2]), Vector3.new(0.5, 0.5, 0.5), BULBS[i % #BULBS + 1], true)
		end
		for tier = 0, 4 do
			Kit.post(
				ride,
				at(cx, 13.8 + tier * 1.1, cz),
				1.1,
				radius * 2 + 1 - tier * 5.5,
				if tier % 2 == 0 then RED else CREAM,
				Enum.Material.Fabric
			)
		end
		Kit.post(ride, at(cx, 20, cz), 2, 1, GOLD, Enum.Material.Metal)
		local top = Kit.ball(ride, at(cx, 21.5, cz), Vector3.new(2.4, 2.4, 2.4), GOLD, Enum.Material.Metal)
		Kit.light(top, hex("#FFE7A3"), 30, 1.4)
		-- Horses on brass poles, painted in turn.
		local coats = { CREAM, hex("#3A2F55"), hex("#C97B3A"), hex("#F2D27A"), hex("#7FB7E8"), hex("#E8A0BF") }
		for i, spot in around(cx, cz, 9.5, 10) do
			local horse = at(spot[1], 0, spot[2]) * CFrame.Angles(0, -spot[3], 0)
			local height = 3.2 + (i % 2) * 1
			Kit.post(ride, horse * CFrame.new(0, 7, 0), 12, 0.3, GOLD, Enum.Material.Metal)
			local coat = coats[(i - 1) % #coats + 1]
			Kit.ball(ride, horse * CFrame.new(0, height, 0), Vector3.new(1.5, 1.6, 3.6), coat)
			Kit.block(
				ride,
				horse * CFrame.new(0, height + 1.2, -1.7) * CFrame.Angles(-0.5, 0, 0),
				Vector3.new(1, 1.8, 1),
				coat
			)
			Kit.block(ride, horse * CFrame.new(0, height + 1.8, -2.4), Vector3.new(0.9, 0.9, 1.4), coat)
			Kit.block(
				ride,
				horse * CFrame.new(0, height + 1.9, -1.4),
				Vector3.new(0.3, 1.4, 1),
				hex("#D7263D"),
				Enum.Material.Fabric
			)
			Kit.block(
				ride,
				horse * CFrame.new(0, height + 0.8, 0),
				Vector3.new(1.6, 0.3, 1.4),
				PURPLE,
				Enum.Material.Fabric
			)
			for _, leg in { { 0.5, -1.2, -0.6 }, { -0.5, -1.2, 0.6 }, { 0.5, 1.2, 0.5 }, { -0.5, 1.2, -0.4 } } do
				Kit.block(
					ride,
					horse * CFrame.new(leg[1], height - 1.1, leg[2]) * CFrame.Angles(leg[3], 0, 0),
					Vector3.new(0.35, 1.8, 0.35),
					coat
				)
			end
		end
		Kit.spin(ride, at(cx, 0, cz), 24)
		-- A carousel organ out front.
		local organ = Kit.model(dressing, "Organ")
		Kit.solid(Kit.block(organ, at(cx + 16, 2.5, cz - 6), Vector3.new(3, 5, 6), RED, Enum.Material.WoodPlanks))
		for i = -2, 2 do
			Kit.post(
				organ,
				at(cx + 14.4, 3 + math.abs(i) * -0.3, cz - 6 + i * 1),
				3 - math.abs(i) * 0.4,
				0.6,
				GOLD,
				Enum.Material.Metal
			)
		end
		spawnAt(cx, 1.2, cz - 11)
		spawnAt(cx + 16, 0, cz + 10)
		for _, spot in around(cx, cz, 11.5, 6, 0.5) do
			coinAt(spot[1], 1.2, spot[2])
		end
		coinAt(cx - 18, 0, cz)
		clueAt(cx, 1.2, cz + 5)
		clueAt(cx - 19, 0, cz + 18)
	end

	-- The funhouse and its mirror maze ------------------------------------
	room("Funhouse", 30, 14, 66, 46)
	do
		local fun = Kit.model(structure, "Funhouse")
		local x0, z0, x1, z1 = 34, 18, 62, 42
		local wallColor = hex("#3A86FF")
		Kit.slab(
			fun,
			at((x0 + x1) / 2, 0.25, (z0 + z1) / 2),
			Vector3.new(x1 - x0, 0.5, z1 - z0),
			hex("#2A2244"),
			Enum.Material.SmoothPlastic
		)
		Kit.slab(fun, at((x0 + x1) / 2, 14.5, (z0 + z1) / 2), Vector3.new(x1 - x0 + 2, 1, z1 - z0 + 2), hex("#FF5D8F"))
		Kit.wall(
			fun,
			point(x0, 0, z0),
			point(x0, 0, z1),
			14,
			1,
			wallColor,
			Enum.Material.SmoothPlastic,
			{ { At = 12, Width = 7, Height = 9 } }
		)
		Kit.wall(
			fun,
			point(x1, 0, z0),
			point(x1, 0, z1),
			14,
			1,
			wallColor,
			Enum.Material.SmoothPlastic,
			{ { At = 6, Width = 6, Height = 9 } }
		)
		Kit.wall(
			fun,
			point(x0, 0, z0),
			point(x1, 0, z0),
			14,
			1,
			wallColor,
			Enum.Material.SmoothPlastic,
			{ { At = 22, Width = 6, Height = 9 } }
		)
		Kit.wall(fun, point(x0, 0, z1), point(x1, 0, z1), 14, 1, wallColor, Enum.Material.SmoothPlastic)
		-- Polka dots and a grinning moon over the door.
		local deco = Kit.model(dressing, "FunhouseFace")
		for i = 0, 9 do
			Kit.ball(
				deco,
				at(x0 - 0.55, 2 + (i % 3) * 4, z0 + 2 + i * 2.3),
				Vector3.new(0.1, 1.6, 1.6),
				BULBS[i % #BULBS + 1]
			)
		end
		Kit.ball(deco, at(x0 - 1, 18, 30), Vector3.new(2, 9, 9), hex("#FFE066"))
		Kit.ball(deco, at(x0 - 2, 19.5, 28.4), Vector3.new(0.4, 1.2, 1), hex("#1A1A1A"))
		Kit.ball(deco, at(x0 - 2, 19.5, 31.6), Vector3.new(0.4, 1.2, 1), hex("#1A1A1A"))
		for i = -2, 2 do
			Kit.block(
				deco,
				at(x0 - 2, 16.4 + math.abs(i) * 0.35, 30 + i * 0.9),
				Vector3.new(0.4, 0.5, 1),
				hex("#1A1A1A")
			)
		end
		Kit.sign(
			deco,
			at(x0 - 0.7, 11.5, 30) * CFrame.Angles(0, PI / 2, 0),
			Vector3.new(10, 2, 0.2),
			NAVY,
			"FUN HOUSE",
			hex("#FFE066")
		)
		-- The mirror maze: glass walls on a grid of 4-stud cells.
		local maze = Kit.model(structure, "Mirrors")
		local runs = {
			{ 38, 22, 38, 34 },
			{ 42, 26, 42, 42 },
			{ 46, 18, 46, 30 },
			{ 50, 22, 50, 38 },
			{ 54, 26, 54, 42 },
			{ 58, 18, 58, 34 },
			{ 38, 34, 46, 34 },
			{ 42, 22, 50, 22 },
			{ 54, 26, 58, 26 },
			{ 46, 38, 50, 38 },
		}
		for _, run in runs do
			local a, b = point(run[1], 0, run[2]), point(run[3], 0, run[4])
			local mirror = Kit.span(
				maze,
				a + Vector3.new(0, 5, 0),
				b + Vector3.new(0, 5, 0),
				0.4,
				10,
				hex("#C9D6E8"),
				Enum.Material.Glass
			)
			mirror.Reflectance = 0.6
			mirror.Transparency = 0.15
			Kit.solid(mirror)
			mirror.CastShadow = false
		end
		for _, spot in { { 40, 20 }, { 48, 32 }, { 56, 40 }, { 60, 22 } } do
			local lamp = Kit.glow(
				dressing,
				at(spot[1], 13.6, spot[2]),
				Vector3.new(1, 0.4, 1),
				BULBS[(spot[1] // 4) % #BULBS + 1],
				true
			)
			if spot[1] == 48 then
				Kit.light(lamp, hex("#FF8FE0"), 26, 1.2)
			end
		end
		spawnAt(44, 0.5, 28)
		for _, spot in { { 36, 40 }, { 40, 28 }, { 44, 20 }, { 48, 36 }, { 52, 30 }, { 56, 22 }, { 60, 38 } } do
			coinAt(spot[1], 0.5, spot[2])
		end
		clueAt(60, 0.5, 40)
		clueAt(36, 0.5, 20)
	end

	-- The big top --------------------------------------------------------
	room("Big Top", -28, -84, 28, -28)
	do
		local cx, cz, radius = 0, -56, 24
		local tent = Kit.model(structure, "BigTop")
		Kit.slab(tent, at(cx, 0.15, cz), Vector3.new(radius * 2, 0.3, radius * 2), hex("#C9A66B"), Enum.Material.Sand).Shape =
			Enum.PartType.Cylinder
		-- A cylinder lies along X; stand it up as a flat disc.
		local floorDisc = tent:FindFirstChildWhichIsA("BasePart") :: BasePart
		floorDisc.Size = Vector3.new(0.3, radius * 2, radius * 2)
		floorDisc.CFrame = at(cx, 0.15, cz) * CFrame.Angles(0, 0, PI / 2)
		local panels = 24
		for i = 0, panels - 1 do
			local angle = (i + 0.5) / panels * PI * 2
			local doorway = (i == 5 or i == 6) or (i == 17 or i == 18)
			local x, z = cx + math.cos(angle) * radius, cz + math.sin(angle) * radius
			local facing = at(x, 0, z) * CFrame.Angles(0, -angle + PI / 2, 0)
			local width = 2 * PI * radius / panels + 0.3
			local color = if i % 2 == 0 then RED else CREAM
			if doorway then
				Kit.block(tent, facing * CFrame.new(0, 11, 0), Vector3.new(width, 2, 0.6), color, Enum.Material.Fabric)
			else
				Kit.slab(tent, facing * CFrame.new(0, 6, 0), Vector3.new(width, 12, 0.6), color, Enum.Material.Fabric)
			end
			-- The roof panel from this wall up to the king pole.
			local foot = point(x, 12, z)
			local peak = point(cx + math.cos(angle) * 1.5, 28, cz + math.sin(angle) * 1.5)
			local panel = Kit.span(tent, foot, peak, width + 0.2, 0.5, color, Enum.Material.Fabric)
			panel.CastShadow = true
		end
		Kit.solid(Kit.post(tent, at(cx, 15, cz), 30, 1.4, GOLD, Enum.Material.Metal))
		local flag = Kit.block(dressing, at(cx + 1.6, 30, cz), Vector3.new(3, 1.8, 0.1), PURPLE, Enum.Material.Fabric)
		flag.Name = "Flag"
		-- The ring: a low red wall round a sawdust circle, with a pedestal.
		for i, spot in around(cx, cz, 9, 20) do
			if i ~= 5 and i ~= 15 then
				Kit.slab(
					tent,
					at(spot[1], 0.9, spot[2]) * CFrame.Angles(0, -spot[3] + PI / 2, 0),
					Vector3.new(3, 1.8, 0.8),
					if i % 2 == 0 then RED else GOLD,
					Enum.Material.WoodPlanks
				)
			end
		end
		Kit.solid(Kit.post(tent, at(cx, 1, cz), 2, 4, PURPLE))
		Kit.post(tent, at(cx, 2.1, cz), 0.3, 4.4, GOLD, Enum.Material.Metal)
		-- Bleachers round the back half, three steps high.
		for _, spot in around(cx, cz, 17.5, 14, 0.5) do
			local angle = spot[3]
			local nearDoor = math.abs(math.sin(angle)) < 0.35
			if not nearDoor then
				for step = 0, 2 do
					local r = 15 + step * 2
					Kit.slab(
						tent,
						at(cx + math.cos(angle) * r, 0.75 + step * 1.5, cz + math.sin(angle) * r)
							* CFrame.Angles(0, -angle + PI / 2, 0),
						Vector3.new(2 * PI * r / 14 + 0.4, 1.5 + step * 3, 2),
						if step % 2 == 0 then NAVY else hex("#2A2F6A"),
						Enum.Material.WoodPlanks
					)
				end
			end
		end
		-- Spotlights and a trapeze.
		for _, spot in around(cx, cz, 6, 4, 0.25) do
			local lamp = Kit.glow(dressing, at(spot[1], 22, spot[2]), Vector3.new(1.2, 1.2, 1.2), hex("#FFF2C2"), true)
			Kit.light(lamp, hex("#FFF2C2"), 24, 1.1)
		end
		Kit.span(dressing, point(cx - 5, 20, cz), point(cx - 5, 15, cz), 0.1, 0.1, hex("#2A2A30"))
		Kit.span(dressing, point(cx + 5, 20, cz), point(cx + 5, 15, cz), 0.1, 0.1, hex("#2A2A30"))
		Kit.span(dressing, point(cx - 5, 15, cz), point(cx + 5, 15, cz), 0.3, 0.3, GOLD)
		spawnAt(cx - 12, 0.3, cz)
		spawnAt(cx + 12, 0.3, cz)
		for _, spot in around(cx, cz, 12.5, 8, 0.5) do
			coinAt(spot[1], 0.3, spot[2])
		end
		-- On the pedestal beside the king pole (not inside it), and a page
		-- on the middle row of the bleachers, away from the doors.
		coinAt(cx + 1.5, 2.3, cz)
		clueAt(cx, 0.3, cz + 21)
		local seat = (9 + 0.5) / 14 * PI * 2
		clueAt(cx + math.cos(seat) * 17, 4.5, cz + math.sin(seat) * 17)
	end

	-- The ferris wheel ---------------------------------------------------
	room("Ferris Wheel", 34, -84, 84, -26)
	do
		local cx, cz, height, radius = 60, -56, 26, 20
		local stand = Kit.model(structure, "WheelStand")
		Kit.slab(stand, at(cx, 0.5, cz), Vector3.new(16, 1, 30), hex("#3A3F55"), Enum.Material.DiamondPlate)
		for _, side in { -1, 1 } do
			for _, lean in { -1, 1 } do
				Kit.span(
					stand,
					point(cx + side * 4, 0.5, cz + lean * 12),
					point(cx + side * 2, height, cz),
					1.2,
					1.2,
					hex("#E8E2D6"),
					Enum.Material.Metal
				)
			end
		end
		Kit.solid(Kit.block(stand, at(cx, 3, cz + 13), Vector3.new(6, 6, 3), RED, Enum.Material.WoodPlanks))
		Kit.solid(Kit.block(stand, at(cx, 3, cz - 13), Vector3.new(6, 6, 3), RED, Enum.Material.WoodPlanks))
		local wheel = Kit.model(dressing, "FerrisWheel")
		local hub = at(cx, height, cz)
		local rim = Kit.model(wheel, "Rim")
		Kit.log(rim, hub, 5, 2.4, GOLD, Enum.Material.Metal)
		local spokes = 16
		local lastPoint = nil
		for i = 0, spokes do
			local angle = i / spokes * PI * 2
			local rimPoint = (hub * CFrame.new(0, math.sin(angle) * radius, math.cos(angle) * radius)).Position
			if i < spokes then
				for _, side in { -1.2, 1.2 } do
					Kit.span(
						rim,
						(hub * CFrame.new(side, 0, 0)).Position,
						rimPoint + (hub.RightVector * side),
						0.3,
						0.3,
						hex("#E8E2D6"),
						Enum.Material.Metal
					)
				end
				Kit.glow(
					rim,
					CFrame.new(rimPoint + hub.RightVector * 1.4),
					Vector3.new(0.7, 0.7, 0.7),
					BULBS[i % #BULBS + 1],
					true
				)
			end
			if lastPoint then
				for _, side in { -1.2, 1.2 } do
					Kit.span(
						rim,
						lastPoint + hub.RightVector * side,
						rimPoint + hub.RightVector * side,
						0.5,
						0.5,
						hex("#E8E2D6"),
						Enum.Material.Metal
					)
				end
			end
			lastPoint = rimPoint
		end
		-- Gondolas, each hanging from its own point on the rim.
		for i = 0, 7 do
			local angle = i / 8 * PI * 2
			local gondola = Kit.model(wheel, `Gondola{i}`)
			gondola:SetAttribute("Angle", angle)
			local hang = hub * CFrame.new(0, math.sin(angle) * radius, math.cos(angle) * radius)
			Kit.block(gondola, hang * CFrame.new(0, -2.6, 0), Vector3.new(3.6, 2.4, 3.6), BULBS[i % #BULBS + 1])
			Kit.block(gondola, hang * CFrame.new(0, -0.8, 0), Vector3.new(4, 0.4, 4), CREAM)
			Kit.block(gondola, hang * CFrame.new(0, -0.4, 0), Vector3.new(0.3, 1, 0.3), hex("#2A2A30"))
			gondola.WorldPivot = hang
		end
		wheel.WorldPivot = hub
		wheel:SetAttribute("SpinSeconds", 40)
		wheel:AddTag("Wheel")
		local sign = Kit.sign(
			dressing,
			at(cx - 3.1, 7.5, cz + 13) * CFrame.Angles(0, PI / 2, 0),
			Vector3.new(5.6, 1.4, 0.1),
			NAVY,
			"SKY WHEEL",
			GOLD
		)
		sign.Name = "WheelSign"
		local glow = Kit.glow(dressing, at(cx, height, cz - 3), Vector3.new(1, 1, 1), hex("#FFE7A3"), true)
		Kit.light(glow, hex("#FFE7A3"), 40, 1.6)
		spawnAt(cx - 12, 0, cz + 20)
		for _, spot in { { cx - 10, cz }, { cx + 10, cz }, { cx, cz - 20 }, { cx - 14, cz - 20 }, { cx + 16, cz + 18 } } do
			coinAt(spot[1], 0, spot[2])
		end
		coinAt(cx, 1, cz)
		clueAt(cx + 20, 0, cz - 24)
	end

	-- The food court ------------------------------------------------------
	room("Food Court", -76, -36, -26, 6)
	do
		local food = Kit.model(dressing, "FoodCourt")
		-- A popcorn stand.
		local pop = at(-60, 0, -4)
		Kit.solid(Kit.block(food, pop * CFrame.new(0, 2, 0), Vector3.new(6, 4, 4), RED))
		for i = -1, 1 do
			Kit.block(food, pop * CFrame.new(i * 2, 2, -2.05), Vector3.new(0.6, 4, 0.1), CREAM)
		end
		local case =
			Kit.block(food, pop * CFrame.new(0, 5.5, 0), Vector3.new(5, 3, 3.4), hex("#CFE8FF"), Enum.Material.Glass)
		case.Transparency = 0.5
		for i = 0, 11 do
			Kit.ball(
				food,
				pop * CFrame.new(-1.8 + (i % 4) * 1.2, 4.5 + (i // 4) * 0.5, -0.6 + (i % 3) * 0.6),
				Vector3.new(0.9, 0.8, 0.9),
				hex("#FFF2B3")
			)
		end
		Kit.wedge(food, pop * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, PI / 2, 0), Vector3.new(4.4, 1.2, 6.4), RED)
		Kit.sign(food, pop * CFrame.new(0, 8.8, -1.3), Vector3.new(5, 1.2, 0.1), CREAM, "POPCORN", RED)
		-- A candy floss cart.
		local floss = at(-40, 0, -4)
		Kit.solid(Kit.block(food, floss * CFrame.new(0, 2, 0), Vector3.new(5, 3, 3.4), hex("#FF8FC8")))
		for _, side in { -1, 1 } do
			Kit.post(food, floss * CFrame.new(side * 2.6, 1, 1.2) * CFrame.Angles(0, PI / 2, 0), 0.4, 2, hex("#2A2A30"))
		end
		Kit.post(food, floss * CFrame.new(0, 3.8, 0), 0.6, 2.6, hex("#CFE8FF"), Enum.Material.Metal)
		for i = 0, 4 do
			Kit.ball(
				food,
				floss * CFrame.new(-1.4 + i * 0.7, 4.8 + (i % 2) * 0.3, 0),
				Vector3.new(1.2, 1.4, 1.2),
				hex(if i % 2 == 0 then "#FFB3D9" else "#B3E5FF"),
				Enum.Material.Fabric
			)
		end
		Kit.post(food, floss * CFrame.new(0, 7, 0), 0.4, 6, hex("#FF5D8F"), Enum.Material.Fabric)
		Kit.post(food, floss * CFrame.new(0, 5.2, 0), 4, 0.2, CREAM)
		-- Candy apples.
		local apples = at(-68, 0, -24)
		Kit.solid(
			Kit.block(
				food,
				apples * CFrame.new(0, 2, 0),
				Vector3.new(4, 4, 6),
				hex("#7A1F2B"),
				Enum.Material.WoodPlanks
			)
		)
		for i = 0, 5 do
			local spot = apples * CFrame.new(-0.8 + (i % 2) * 1.6, 4.5, -2 + (i // 2) * 2)
			Kit.ball(food, spot, Vector3.new(1, 1, 1), hex("#D7263D"))
			Kit.post(food, spot * CFrame.new(0, 0.8, 0), 0.8, 0.1, hex("#C9A66B"))
		end
		Kit.sign(
			food,
			apples * CFrame.new(2.05, 3, 0) * CFrame.Angles(0, -PI / 2, 0),
			Vector3.new(4.4, 1, 0.1),
			CREAM,
			"CANDY APPLES",
			hex("#7A1F2B")
		)
		-- Picnic tables with umbrellas.
		for i, spot in { { -60, -22 }, { -46, -26 }, { -36, -18 }, { -52, -32 } } do
			Pieces.table(food, at(spot[1], 0, spot[2]), Vector3.new(6, 3, 3), WOOD, nil)
			for _, side in { -1, 1 } do
				Kit.solid(
					Kit.block(
						food,
						at(spot[1], 1.6, spot[2] + side * 2.8),
						Vector3.new(6, 0.4, 1.2),
						WOOD,
						Enum.Material.Wood
					)
				)
			end
			Kit.post(food, at(spot[1], 5, spot[2]), 6, 0.3, hex("#E8E2D6"))
			for tier = 0, 1 do
				Kit.post(
					food,
					at(spot[1], 7.6 + tier * 0.5, spot[2]),
					0.5,
					7 - tier * 3,
					if (i + tier) % 2 == 0 then TEAL else CREAM,
					Enum.Material.Fabric
				)
			end
		end
		Pieces.stringLights(dressing, point(-72, 10, -2), point(-30, 10, -2), BULBS, 2)
		Pieces.stringLights(dressing, point(-72, 10, -36), point(-30, 10, -36), BULBS, 2)
		for _, spot in { { -72, -2 }, { -30, -2 }, { -72, -36 }, { -30, -36 } } do
			Pieces.lamp(dressing, at(spot[1], 0, spot[2]), hex("#FFE7A3"), 10)
		end
		spawnAt(-50, 0, -12)
		for _, spot in { { -64, -12 }, { -52, -16 }, { -40, -12 }, { -44, -32 }, { -32, -28 }, { -58, -30 } } do
			coinAt(spot[1], 0, spot[2])
		end
		clueAt(-74, 0, -30)
		clueAt(-34, 0, -6)
	end

	-- The ghost train tunnel ----------------------------------------------
	room("Ghost Train", -86, -86, -56, -40)
	do
		local tunnel = Kit.model(structure, "GhostTrain")
		local x0, x1, z0, z1 = -80, -64, -82, -46
		local wallColor = hex("#2B2238")
		Kit.slab(tunnel, at((x0 + x1) / 2, 0.25, (z0 + z1) / 2), Vector3.new(x1 - x0, 0.5, z1 - z0), hex("#1A1622"))
		Kit.slab(
			tunnel,
			at((x0 + x1) / 2, 12.5, (z0 + z1) / 2),
			Vector3.new(x1 - x0 + 2, 1, z1 - z0 + 2),
			hex("#1A1622")
		)
		Kit.wall(tunnel, point(x0, 0, z0), point(x0, 0, z1), 12, 1, wallColor, Enum.Material.Slate)
		Kit.wall(
			tunnel,
			point(x1, 0, z0),
			point(x1, 0, z1),
			12,
			1,
			wallColor,
			Enum.Material.Slate,
			{ { At = 18, Width = 7, Height = 9 } }
		)
		Kit.wall(
			tunnel,
			point(x0, 0, z1),
			point(x1, 0, z1),
			12,
			1,
			wallColor,
			Enum.Material.Slate,
			{ { At = 8, Width = 8, Height = 9 } }
		)
		Kit.wall(
			tunnel,
			point(x0, 0, z0),
			point(x1, 0, z0),
			12,
			1,
			wallColor,
			Enum.Material.Slate,
			{ { At = 8, Width = 8, Height = 9 } }
		)
		-- An inner wall makes the ride a loop.
		Kit.wall(tunnel, point(-72, 0, -76), point(-72, 0, -52), 12, 1, wallColor, Enum.Material.Slate)
		-- Rails along the loop.
		for _, x in { -76, -68 } do
			for _, offset in { -1, 1 } do
				Kit.block(
					dressing,
					at(x + offset, 0.6, -64),
					Vector3.new(0.3, 0.2, 34),
					hex("#5A5A66"),
					Enum.Material.Metal
				)
			end
		end
		-- The front: a huge ghost face over the entrance.
		local face = Kit.model(dressing, "GhostFace")
		Kit.ball(face, at(-72, 14, -45), Vector3.new(16, 14, 3), hex("#F4F8FF"))
		Kit.ball(face, at(-75, 15, -43.8), Vector3.new(2.4, 3.6, 1), hex("#1C1C28"))
		Kit.ball(face, at(-69, 15, -43.8), Vector3.new(2.4, 3.6, 1), hex("#1C1C28"))
		Kit.ball(face, at(-72, 10.5, -43.8), Vector3.new(4, 3, 1), hex("#1C1C28"))
		Kit.sign(
			face,
			at(-72, 21.5, -45) * CFrame.Angles(0, PI, 0),
			Vector3.new(12, 2, 0.2),
			PURPLE,
			"GHOST TRAIN",
			hex("#B9FFB0")
		)
		-- Glowing eyes peering from the walls inside.
		for i = 0, 7 do
			local x = if i % 2 == 0 then -79.3 else -64.7
			local z = -78 + i * 4
			for _, offset in { -0.35, 0.35 } do
				Kit.glow(dressing, at(x, 6 + (i % 3), z + offset), Vector3.new(0.2, 0.3, 0.3), hex("#7CFF6B"), true)
			end
		end
		for _, z in { -70, -58 } do
			local glow = Kit.glow(dressing, at(-72, 11.6, z), Vector3.new(1, 0.4, 1), hex("#7CFF6B"), true)
			Kit.light(glow, hex("#7CFF6B"), 18, 0.8, true)
		end
		spawnAt(-76, 0.5, -60)
		for _, spot in { { -76, -76 }, { -68, -76 }, { -76, -54 }, { -68, -54 }, { -76, -66 }, { -68, -66 } } do
			coinAt(spot[1], 0.5, spot[2])
		end
		clueAt(-72, 0.5, -80)
	end

	-- The back lot: trailers, crates and a bandstand -----------------------
	room("Back Lot", 30, -24, 90, 14)
	room("Bandstand", -90, 52, -26, 90)
	room("Trailers", 26, 46, 90, 90)
	do
		local lot = Kit.model(structure, "BackLot")
		local function trailer(base: CFrame, color: Color3)
			Kit.solid(Kit.block(lot, base * CFrame.new(0, 5, 0), Vector3.new(9, 8, 22), color))
			Kit.block(lot, base * CFrame.new(0, 9.2, 0), Vector3.new(9.4, 0.4, 22.4), CREAM)
			for _, z in { -7, 0, 7 } do
				local window = Kit.block(
					lot,
					base * CFrame.new(-4.55, 6, z),
					Vector3.new(0.1, 2, 3),
					hex("#FFE7A3"),
					Enum.Material.Neon
				)
				window.Transparency = 0.2
			end
			for _, z in { -6, 6 } do
				for _, side in { -1, 1 } do
					Kit.post(
						lot,
						base * CFrame.new(side * 4.6, 1, z) * CFrame.Angles(0, PI / 2, 0) * CFrame.Angles(0, 0, PI / 2),
						0.8,
						2,
						hex("#1A1A1A")
					)
				end
			end
		end
		trailer(at(70, 0, 66), hex("#3A86FF"))
		trailer(at(52, 0, 70) * CFrame.Angles(0, 0.2, 0), hex("#FF8C1A"))
		trailer(at(76, 0, -4), hex("#2E9E5B"))
		for i, spot in { { 40, 0 }, { 44, -12 }, { 60, 8 }, { 62, -16 }, { 84, 30 }, { 36, 56 } } do
			Pieces.crate(dressing, at(spot[1], 0, spot[2]), 3 + (i % 2))
			if i % 2 == 0 then
				Pieces.crate(dressing, at(spot[1], 3 + (i % 2), spot[2]) * CFrame.Angles(0, 0.4, 0), 2.6)
			end
		end
		for _, spot in { { 52, -2 }, { 66, 10 }, { 46, 50 } } do
			Pieces.barrel(dressing, at(spot[1], 0, spot[2]))
		end
		-- Hay bales stacked by the fence.
		for i = 0, 5 do
			Kit.solid(
				Kit.block(
					dressing,
					at(84, 1.2 + (i // 3) * 2.4, -20 + (i % 3) * 5),
					Vector3.new(3.6, 2.4, 4.8),
					hex("#D9B65A"),
					Enum.Material.Fabric
				)
			)
		end
		-- The bandstand.
		local band = Kit.model(dressing, "Bandstand")
		local bc = at(-64, 0, 72)
		Kit.slab(band, bc * CFrame.new(0, 1, 0), Vector3.new(18, 2, 14), WOOD, Enum.Material.WoodPlanks)
		Kit.stairs(structure, bc * CFrame.new(0, 0, -9.4), 6, 2, 2.4, WOOD, Enum.Material.WoodPlanks)
		for _, corner in { { -8, -6 }, { 8, -6 }, { -8, 6 }, { 8, 6 } } do
			Kit.solid(Kit.post(band, bc * CFrame.new(corner[1], 6, corner[2]), 8, 0.8, CREAM))
		end
		for stripe = 0, 8 do
			Kit.wedge(
				band,
				bc * CFrame.new(-8 + stripe * 2, 11, 0) * CFrame.Angles(0, 0, 0),
				Vector3.new(2, 2, 15),
				if stripe % 2 == 0 then RED else CREAM,
				Enum.Material.Fabric
			)
		end
		Kit.ball(band, bc * CFrame.new(-4, 3.5, 3), Vector3.new(2.6, 2.6, 1.4), hex("#D7263D"))
		Kit.post(band, bc * CFrame.new(3, 3, 3), 1.8, 0.2, hex("#2A2A30"))
		Kit.ball(band, bc * CFrame.new(3, 4.2, 3), Vector3.new(0.7, 0.9, 0.7), hex("#3A3A3A"))
		local stageLight = Kit.glow(band, bc * CFrame.new(0, 9.6, -5), Vector3.new(1, 1, 1), hex("#FF8FE0"), true)
		Kit.light(stageLight, hex("#FF8FE0"), 22, 1.2)
		spawnAt(64, 0, 40)
		spawnAt(-64, 2, 74)
		for _, spot in
			{
				{ 50, 8 },
				{ 70, -14 },
				{ 84, 6 },
				{ 60, 56 },
				{ 82, 80 },
				{ 40, 80 },
				{ -64, 2, 70 },
				{ -48, 80 },
				{ -80, 60 },
			}
		do
			if #spot == 3 then
				coinAt(spot[1], spot[2], spot[3])
			else
				coinAt(spot[1], 0, spot[2])
			end
		end
		clueAt(86, 0, -24)
		clueAt(60, 0, 82)
		clueAt(-84, 0, 84)
	end

	-- The swing ride, between the ghost train and the big top ---------------
	room("Swings", -56, -86, -26, -46)
	do
		local cx, cz = -42, -66
		local base = Kit.model(structure, "SwingBase")
		Kit.solid(Kit.post(base, at(cx, 0.4, cz), 0.8, 10, hex("#3A3F55"), Enum.Material.DiamondPlate))
		Kit.solid(Kit.post(base, at(cx, 8, cz), 16, 1.6, CREAM, Enum.Material.Metal))
		for i = 0, 3 do
			Kit.glow(base, at(cx, 3 + i * 3.5, cz - 0.85), Vector3.new(0.5, 0.5, 0.5), BULBS[i + 1], true)
		end
		local ride = Kit.model(dressing, "SwingRide")
		for tier = 0, 3 do
			Kit.post(
				ride,
				at(cx, 16 + tier * 0.8, cz),
				0.8,
				18 - tier * 4,
				if tier % 2 == 0 then TEAL else CREAM,
				Enum.Material.Fabric
			)
		end
		local top = Kit.ball(ride, at(cx, 19.6, cz), Vector3.new(2, 2, 2), GOLD, Enum.Material.Metal)
		Kit.light(top, hex("#9FFFF2"), 26, 1.2)
		for i, spot in around(cx, cz, 8, 12) do
			local angle = spot[3]
			local seat = point(cx + math.cos(angle) * 11, 7, cz + math.sin(angle) * 11)
			local hang = point(spot[1], 15.6, spot[2])
			Kit.span(ride, hang, seat + Vector3.new(0, 1, 0), 0.12, 0.12, hex("#C9C9D1"), Enum.Material.Metal)
			local tilt = Kit.facing(hang, seat)
			Kit.block(
				ride,
				CFrame.new(seat) * (tilt - tilt.Position) * CFrame.Angles(PI / 2, 0, 0),
				Vector3.new(1.4, 0.3, 1.4),
				BULBS[i % #BULBS + 1]
			)
			Kit.glow(ride, at(spot[1], 15.6, spot[2]), Vector3.new(0.4, 0.4, 0.4), BULBS[(i + 2) % #BULBS + 1], true)
		end
		Kit.spin(ride, at(cx, 0, cz), 14)
		spawnAt(cx + 12, 0, cz + 12)
		for _, spot in around(cx, cz, 6, 4, 0.5) do
			coinAt(spot[1], 0.8, spot[2])
		end
		clueAt(cx - 10, 0, cz - 16)
	end

	-- The hay maze, past the funhouse: low walls of bales with a scarecrow ---
	room("Hay Maze", 64, 16, 90, 46)
	do
		local hay = Kit.model(structure, "HayMaze")
		local bale = hex("#D9B65A")
		local function bales(x0: number, z0: number, x1: number, z1: number)
			local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
			local length = (b - a).Magnitude
			local count = math.max(1, math.floor(length / 4 + 0.5))
			for i = 0, count - 1 do
				local mid = a:Lerp(b, (i + 0.5) / count)
				local along = Kit.facing(a, b) - Kit.facing(a, b).Position
				for row = 0, 1 do
					Kit.solid(
						Kit.block(
							hay,
							origin * CFrame.new(mid.X, 1.25 + row * 2.5, mid.Z) * along,
							Vector3.new(2.6, 2.5, length / count - 0.15),
							if (i + row) % 3 == 0 then hex("#C9A54A") else bale,
							Enum.Material.Fabric
						)
					)
				end
			end
		end
		for _, run in
			{
				{ 66, 18, 88, 18 },
				{ 66, 44, 82, 44 },
				{ 66, 18, 66, 30 },
				{ 88, 18, 88, 44 },
				{ 72, 24, 72, 38 },
				{ 72, 24, 82, 24 },
				{ 78, 30, 78, 44 },
				{ 82, 30, 88, 30 },
				{ 66, 36, 72, 36 },
			}
		do
			bales(run[1], run[2], run[3], run[4])
		end
		-- The scarecrow keeping watch in the middle.
		local crow = Kit.model(dressing, "Scarecrow")
		local sc = at(75, 0, 34)
		Kit.post(crow, sc * CFrame.new(0, 4, 0), 8, 0.4, WOOD)
		Kit.block(crow, sc * CFrame.new(0, 6, 0), Vector3.new(5, 0.4, 0.4), WOOD)
		Kit.block(crow, sc * CFrame.new(0, 5.2, 0), Vector3.new(2, 2.6, 1), hex("#6A8E4E"), Enum.Material.Fabric)
		Kit.block(crow, sc * CFrame.new(-1.8, 6, 0), Vector3.new(1.8, 0.8, 0.8), hex("#6A8E4E"), Enum.Material.Fabric)
		Kit.block(crow, sc * CFrame.new(1.8, 6, 0), Vector3.new(1.8, 0.8, 0.8), hex("#6A8E4E"), Enum.Material.Fabric)
		Pieces.pumpkin(crow, sc * CFrame.new(0, 7.3, 0), 2, true)
		Kit.post(crow, sc * CFrame.new(0, 8.6, 0), 0.3, 3.4, hex("#7A5A2A"), Enum.Material.Fabric)
		Kit.post(crow, sc * CFrame.new(0, 9.1, 0), 0.8, 1.8, hex("#7A5A2A"), Enum.Material.Fabric)
		for i, spot in { { 68, 20 }, { 86, 42 }, { 70, 42 }, { 86, 20 }, { 80, 27 } } do
			Pieces.pumpkin(dressing, at(spot[1], 0, spot[2]), 1.4 + (i % 2) * 0.6, i % 2 == 1)
		end
		spawnAt(84, 0, 36)
		for _, spot in { { 69, 22 }, { 69, 40 }, { 75, 21 }, { 85, 26 }, { 81, 37 }, { 75, 41 } } do
			coinAt(spot[1], 0, spot[2])
		end
		clueAt(85, 0, 21)
	end

	-- A strength tester and benches along the back path ---------------------
	do
		local striker = Kit.model(dressing, "Striker")
		local base = at(32, 0, -66)
		Kit.solid(
			Kit.block(striker, base * CFrame.new(0, 0.6, 0), Vector3.new(4, 1.2, 4), RED, Enum.Material.WoodPlanks)
		)
		Kit.solid(
			Kit.block(
				striker,
				base * CFrame.new(0, 10, 0.8),
				Vector3.new(1.4, 18, 0.6),
				CREAM,
				Enum.Material.WoodPlanks
			)
		)
		for i = 0, 7 do
			Kit.glow(
				striker,
				base * CFrame.new(0, 3 + i * 2, 0.4),
				Vector3.new(0.8, 0.5, 0.2),
				BULBS[i % #BULBS + 1],
				false
			)
		end
		local bell = Kit.ball(striker, base * CFrame.new(0, 19.6, 0.8), Vector3.new(2, 2, 2), GOLD, Enum.Material.Metal)
		Kit.light(bell, GOLD, 14, 1)
		Kit.block(
			striker,
			base * CFrame.new(0, 1.4, -0.8),
			Vector3.new(1.6, 0.4, 1.6),
			hex("#3A3A3A"),
			Enum.Material.Metal
		)
		Kit.sign(striker, base * CFrame.new(0, 7, 0.45), Vector3.new(1.3, 5, 0.1), NAVY, "TEST", GOLD)
		for _, spot in
			{
				{ 30, -40, 0 },
				{ 24, 0, PI / 2 },
				{ -24, 0, -PI / 2 },
				{ -30, -40, 0 },
				{ 10, 70, PI / 2 },
				{ -10, 70, -PI / 2 },
			}
		do
			Pieces.bench(dressing, at(spot[1], 0, spot[2]) * CFrame.Angles(0, spot[3], 0), WOOD)
		end
		coinAt(32, 0, -60)
		coinAt(28, 0, -46)
	end

	-- Secret passages: the fortune teller's tent and a manhole ------------
	do
		local tent = Kit.model(dressing, "FortuneTeller")
		local base = at(-30, 0, 62)
		for i = 0, 7 do
			local angle = i / 8 * PI * 2
			if i ~= 6 then
				Kit.slab(
					tent,
					base
						* CFrame.new(math.cos(angle) * 5, 4, math.sin(angle) * 5)
						* CFrame.Angles(0, -angle + PI / 2, 0),
					Vector3.new(4.4, 8, 0.4),
					if i % 2 == 0 then PURPLE else NAVY,
					Enum.Material.Fabric
				)
			end
		end
		Kit.post(tent, base * CFrame.new(0, 8.4, 0), 0.8, 11, PURPLE, Enum.Material.Fabric)
		Kit.post(tent, base * CFrame.new(0, 9.2, 0), 0.8, 7, GOLD, Enum.Material.Fabric)
		Kit.post(tent, base * CFrame.new(0, 10, 0), 0.8, 3, PURPLE, Enum.Material.Fabric)
		Kit.solid(Kit.block(tent, base * CFrame.new(0, 1.5, 1.5), Vector3.new(3, 3, 2), NAVY, Enum.Material.Fabric))
		local ball = Kit.ball(
			tent,
			base * CFrame.new(0, 3.6, 1.5),
			Vector3.new(1.4, 1.4, 1.4),
			hex("#B9A6FF"),
			Enum.Material.Glass
		)
		ball.Transparency = 0.2
		Kit.light(ball, hex("#B067FF"), 12, 1, true)
		Kit.sign(tent, base * CFrame.new(0, 9, -5.6), Vector3.new(5, 1, 0.1), NAVY, "MADAME LUNA", GOLD)
		local manhole = Kit.model(dressing, "Manhole")
		Kit.post(
			manhole,
			at(36, 0.1, -38) * CFrame.Angles(0, 0, PI / 2),
			0.2,
			3.4,
			hex("#3A3A44"),
			Enum.Material.DiamondPlate
		)
		Kit.glow(manhole, at(36, 0.25, -38), Vector3.new(0.3, 0.1, 2), hex("#B067FF"))
		local manhole2 = Kit.model(dressing, "Manhole")
		Kit.post(
			manhole2,
			at(-84, 0.1, 10) * CFrame.Angles(0, 0, PI / 2),
			0.2,
			3.4,
			hex("#3A3A44"),
			Enum.Material.DiamondPlate
		)
		Kit.glow(manhole2, at(-84, 0.25, 10), Vector3.new(0.3, 0.1, 2), hex("#B067FF"))
		passage(
			base * CFrame.new(0, 3, -1.5) * CFrame.Angles(0, PI, 0),
			at(64, 3, 74) * CFrame.Angles(0, PI / 2, 0),
			"Behind the curtain"
		)
		passage(at(36, 3, -34), at(-84, 3, 14), "Manhole")
	end

	map.WorldPivot = origin
	return map
end

return Carnival
