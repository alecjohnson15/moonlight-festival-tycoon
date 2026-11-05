-- Moonlit Plaza, the lobby between rounds. Everyone waits here, so it's
-- built to hang out in: a fountain under a giant spinning mask, a stage to
-- dance on, benches, string lights, and a shop front on every side.
--
-- Plan, looking down with the gate at the top (-Z):
--
--   Leaderboards     Grand gate + next map     VIP balcony
--   Mask Boutique         Fountain              Crate Vault
--   Trading Hall        Emote stage            Moon Pass board
--
-- The server reads what it needs by name: Spawns, Stations (one marker per
-- shop, with a Station attribute), Boards (each has a Screen part and a Stat
-- attribute), MapBoard (a sign whose text says what's next) and VipGate (a
-- velvet rope only VIP holders can walk through).

local Gear = require(script.Parent.Gear)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

local Lobby = {}

Lobby.Id = "lobby"
Lobby.Name = "Moonlit Plaza"

Lobby.Lighting = {
	ClockTime = 23.6,
	Brightness = 2.2,
	Ambient = "#5A5378",
	OutdoorAmbient = "#7570A8",
	FogColor = "#2B2550",
	Atmosphere = { Density = 0.2, Haze = 1, Color = "#8C7FD0", Decay = "#40306A" },
	ColorShift = "#FFC9E0",
	Exposure = 0.4,
}

local hex = Kit.color
local PI = math.pi

local STONE = hex("#8C8FA6")
local PAVING = hex("#5D5F78")
local GOLD = hex("#F5C451")
local PLUM = hex("#4B2A6B")
local VELVET = hex("#8E1F3B")
local CREAM = hex("#F2E9D0")
local NAVY = hex("#1B1F4A")
local LEAVES = hex("#264A36")
local BULBS = { hex("#FFD166"), hex("#FF5D8F"), hex("#B39DFF"), hex("#5DE2E7"), hex("#FFFFFF") }

-- A cosmetic's model, grown by factor and set down at cframe, for displays.
local function showcase(parent: Instance, model: Model, cframe: CFrame, factor: number): Model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Size *= factor
			local cf = part.CFrame
			part.CFrame = cframe * (cf - cf.Position + cf.Position * factor)
			part.Anchored = true
			part.CanCollide = false
		end
	end
	model.WorldPivot = cframe
	model.Parent = parent
	return model
end

function Lobby.build(origin: CFrame): Model
	local lobby = Kit.model(nil, "Lobby")
	local structure = Kit.model(lobby, "Structure")
	local dressing = Kit.model(lobby, "Dressing")
	local spawns = Kit.new("Folder", lobby, { Name = "Spawns" })
	local stations = Kit.new("Folder", lobby, { Name = "Stations" })
	local boards = Kit.new("Folder", lobby, { Name = "Boards" })

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function point(x: number, y: number, z: number): Vector3
		return (origin * CFrame.new(x, y, z)).Position
	end
	local function station(name: string, cframe: CFrame, label: string)
		local marker = Kit.marker(stations, name, cframe)
		marker:SetAttribute("Station", name)
		marker:SetAttribute("Label", label)
		return marker
	end

	-- Ground, hedges and the trees beyond -----------------------------------
	Kit.slab(structure, at(0, -1, 0), Vector3.new(220, 2, 220), hex("#2B4A30"), Enum.Material.Grass)
	Kit.slab(structure, at(0, 0.1, 0), Vector3.new(150, 0.2, 150), PAVING, Enum.Material.Cobblestone)
	-- A ring of pale stone round the fountain, and paths out to each shop.
	Kit.post(structure, at(0, 0.25, 0), 0.1, 44, STONE, Enum.Material.Slate)
	for _, angle in { 0, PI / 2, PI, -PI / 2 } do
		Kit.slab(structure, at(0, 0.22, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -45), Vector3.new(10, 0.05, 50), STONE, Enum.Material.Slate)
	end
	for _, edge in { { -75, -75, 75, -75 }, { -75, 75, 75, 75 }, { -75, -75, -75, 75 }, { 75, -75, 75, 75 } } do
		Pieces.hedge(dressing, point(edge[1], 0, edge[2]), point(edge[3], 0, edge[4]), 6, LEAVES)
		local a, b = Vector3.new(edge[1], 0, edge[2]), Vector3.new(edge[3], 0, edge[4])
		local mid = (a + b) / 2
		local size = Vector3.new(math.max(2, math.abs(b.X - a.X)), 40, math.max(2, math.abs(b.Z - a.Z)))
		Kit.barrier(structure, at(mid.X, 20, mid.Z), size)
	end
	Kit.barrier(structure, at(0, 60, 0), Vector3.new(152, 1, 152))
	for i = 0, 15 do
		local x = -86 + i * 11.5
		Pieces.tree(dressing, at(x, 0, -86 - (i % 2) * 5), 22 + (i % 3) * 4, 800 + i, LEAVES)
		Pieces.tree(dressing, at(x + 4, 0, 86 + (i % 2) * 5), 20 + (i % 4) * 3, 820 + i, LEAVES)
		Pieces.tree(dressing, at(-86 - (i % 2) * 5, 0, x), 21 + (i % 3) * 3, 840 + i, LEAVES)
		Pieces.tree(dressing, at(86 + (i % 2) * 5, 0, x + 4), 23 + (i % 2) * 4, 860 + i, LEAVES)
	end

	-- The fountain and the giant mask ---------------------------------------
	do
		Pieces.fountain(structure, at(0, 0, 0), 10, hex("#B9B4CC"), hex("#3A6FB0"))
		local plinth = Kit.model(structure, "Plinth")
		Kit.solid(Kit.post(plinth, at(0, 3, 0), 5, 4, hex("#B9B4CC"), Enum.Material.Marble))
		Kit.post(plinth, at(0, 5.6, 0), 0.4, 5, GOLD, Enum.Material.Metal)
		local glow = Kit.glow(plinth, at(0, 1.7, 0), Vector3.new(0.3, 18, 18), hex("#7FB8FF"))
		glow.Shape = Enum.PartType.Cylinder
		glow.CFrame = at(0, 1.7, 0) * CFrame.Angles(0, 0, PI / 2)
		glow.Transparency = 0.6
		local statue = Kit.model(dressing, "Statue")
		-- The mask itself: two velvet lobes rimmed in gold, eye holes both
		-- sides, a fan of feathers and a jewel, on a gilded stick.
		local centre = at(0, 13, 0)
		for _, side in { -1, 1 } do
			local lobe = centre * CFrame.new(side * 2.7, 0, 0) * CFrame.Angles(0, 0, side * 0.18)
			Kit.ball(statue, lobe, Vector3.new(6.2, 3.8, 1.4), hex("#5B1A6E"))
			Kit.ball(statue, lobe * CFrame.new(side * 0.1, 0.05, 0), Vector3.new(6.9, 4.5, 0.9), GOLD, Enum.Material.Metal)
			for _, face in { -1, 1 } do
				Kit.ball(statue, lobe * CFrame.new(side * 0.2, 0.1, face * 0.45), Vector3.new(2.8, 1.5, 0.7), hex("#120A1C"))
			end
			Kit.ball(statue, lobe * CFrame.new(side * 3.2, 1.2, 0), Vector3.new(1, 1, 1), GOLD, Enum.Material.Metal)
		end
		Kit.ball(statue, centre * CFrame.new(0, -0.6, 0), Vector3.new(1.6, 2, 1.2), hex("#5B1A6E"))
		local jewel = Kit.glow(statue, centre * CFrame.new(0, 1.6, 0), Vector3.new(1.2, 1.6, 1.2), hex("#FF5DA2"), true)
		jewel.Name = "Jewel"
		local feathers = { hex("#2EC4B6"), GOLD, hex("#FF5DA2"), hex("#B39DFF"), hex("#2EC4B6") }
		for i, color in feathers do
			local angle = -0.9 + (i - 1) * 0.32
			local root = centre * CFrame.new(-4.6, 1.6, 0) * CFrame.Angles(0, 0, angle)
			Kit.ball(statue, root * CFrame.new(0, 3.6, 0), Vector3.new(1.1, 7, 0.4), color, Enum.Material.Fabric)
			Kit.block(statue, root * CFrame.new(0, 3, 0), Vector3.new(0.12, 6, 0.5), CREAM)
		end
		Kit.span(statue, point(5.6, 11.4, 0), point(1.2, 5.8, 0), 0.5, 0.5, GOLD, Enum.Material.Metal)
		local beacon = Kit.glow(statue, at(0, 16, 0), Vector3.new(1, 1, 1), hex("#FFE7A3"), true)
		beacon.Transparency = 1
		Kit.light(beacon, hex("#FFD6F0"), 40, 2)
		Kit.float(statue, at(0, 11, 0), 0.8, 6, 30)
		-- Twelve spawns round the fountain.
		for i = 0, 11 do
			local angle = i / 12 * PI * 2
			Kit.marker(spawns, "Spawn", at(math.cos(angle) * 17, 3, math.sin(angle) * 17) * CFrame.Angles(0, -angle - PI / 2, 0))
		end
		-- Lamps round the ring.
		for i = 0, 7 do
			local angle = (i + 0.5) / 8 * PI * 2
			Pieces.lamp(dressing, at(math.cos(angle) * 22.5, 0, math.sin(angle) * 22.5), hex("#FFE7A3"), 12)
		end
	end

	-- The grand gate and the next-map board ---------------------------------
	do
		local gate = Kit.model(structure, "Gate")
		for _, side in { -1, 1 } do
			Pieces.column(gate, at(side * 12, 0, -60), 22, CREAM)
			Kit.ball(gate, at(side * 12, 23.5, -60), Vector3.new(3, 3, 3), GOLD, Enum.Material.Metal)
		end
		Kit.solid(Kit.block(gate, at(0, 22, -60), Vector3.new(28, 3, 3), CREAM, Enum.Material.Marble))
		Kit.block(gate, at(0, 23.7, -60), Vector3.new(29, 0.4, 3.4), GOLD, Enum.Material.Metal)
		Kit.sign(gate, at(0, 22, -58.4) * CFrame.Angles(0, PI, 0), Vector3.new(24, 2.4, 0.2), PLUM, "PHANTOM PARTY", GOLD)
		-- Iron doors stand shut: rounds start by teleport, not by walking in.
		for _, side in { -1, 1 } do
			for bar = 0, 9 do
				Kit.post(gate, at(side * (1.2 + bar * 1.05), 10, -60), 20, 0.25, hex("#2A2A36"), Enum.Material.Metal)
			end
			Kit.block(gate, at(side * 5.9, 6, -60), Vector3.new(10.2, 0.4, 0.4), hex("#2A2A36"), Enum.Material.Metal)
			Kit.block(gate, at(side * 5.9, 14, -60), Vector3.new(10.2, 0.4, 0.4), hex("#2A2A36"), Enum.Material.Metal)
		end
		Kit.barrier(gate, at(0, 10, -60), Vector3.new(22, 20, 1))
		-- The board: what's next, and the vote.
		local board = Kit.model(structure, "MapBoardFrame")
		Kit.solid(Kit.block(board, at(0, 7, -52), Vector3.new(16, 9, 1), NAVY))
		Kit.block(board, at(0, 7, -52.1), Vector3.new(16.6, 9.6, 0.6), GOLD, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			Kit.post(board, at(side * 6, 1.25, -52), 2.5, 0.6, hex("#2A2A36"), Enum.Material.Metal)
		end
		local sign = Kit.sign(lobby, at(0, 7, -51.45) * CFrame.Angles(0, PI, 0), Vector3.new(15, 8, 0.1), NAVY, "Waiting for players...", CREAM)
		sign.Name = "MapBoard"
		Pieces.stringLights(dressing, point(-12, 21, -60), point(-24, 12, -40), BULBS, 1.5)
		Pieces.stringLights(dressing, point(12, 21, -60), point(24, 12, -40), BULBS, 1.5)
	end

	-- The Mask Boutique (west) ---------------------------------------------
	do
		local shop = Kit.model(structure, "Boutique")
		local x0, x1, z0, z1 = -66, -44, -22, 4
		local walls = hex("#3B2B5C")
		Kit.slab(shop, at((x0 + x1) / 2, 0.3, (z0 + z1) / 2), Vector3.new(x1 - x0, 0.6, z1 - z0), hex("#6B3E7A"), Enum.Material.WoodPlanks)
		Kit.wall(shop, point(x0, 0, z0), point(x0, 0, z1), 14, 1, walls, Enum.Material.Plaster)
		Kit.wall(shop, point(x0, 0, z0), point(x1, 0, z0), 14, 1, walls, Enum.Material.Plaster)
		Kit.wall(shop, point(x0, 0, z1), point(x1, 0, z1), 14, 1, walls, Enum.Material.Plaster)
		Kit.wall(shop, point(x1, 0, z0), point(x1, 0, z1), 14, 1, walls, Enum.Material.Plaster, {
			{ At = 13, Width = 10, Height = 10 },
			{ At = 4, Width = 4, Height = 5, Bottom = 3 },
			{ At = 22, Width = 4, Height = 5, Bottom = 3 },
		})
		Kit.slab(shop, at((x0 + x1) / 2, 14.5, (z0 + z1) / 2), Vector3.new(x1 - x0 + 2, 1, z1 - z0 + 2), hex("#2A1E40"))
		-- An awning and the sign.
		for stripe = 0, 6 do
			Kit.wedge(
				shop,
				at(x1 + 1.8, 12.6, z0 + 4 + stripe * 3) * CFrame.Angles(0, PI / 2, 0),
				Vector3.new(3, 1.6, 3.6),
				if stripe % 2 == 0 then VELVET else CREAM,
				Enum.Material.Fabric
			)
		end
		Kit.sign(shop, at(x1 + 0.6, 16.6, (z0 + z1) / 2) * CFrame.Angles(0, -PI / 2, 0), Vector3.new(16, 3, 0.2), PLUM, "MASK BOUTIQUE", GOLD)
		Kit.block(shop, at(x1 + 0.5, 16.6, (z0 + z1) / 2), Vector3.new(0.2, 3.6, 16.8), GOLD, Enum.Material.Metal)
		-- Inside: a counter, a mirror and masks on stands round the walls.
		Pieces.counter(dressing, at(-61, 0, -9) * CFrame.Angles(0, PI / 2, 0), 10, GOLD, VELVET)
		local mirror = Kit.block(dressing, at(-65.3, 6, 0), Vector3.new(0.2, 8, 4), hex("#C9D6E8"), Enum.Material.Glass)
		mirror.Reflectance = 0.6
		Kit.block(dressing, at(-65.4, 6, 0), Vector3.new(0.2, 8.6, 4.6), GOLD, Enum.Material.Metal)
		local displays = { "mask_velvet", "mask_cat", "mask_fox", "mask_moon", "mask_butterfly", "mask_jester" }
		for i, id in displays do
			local z = z0 + 3 + (i - 1) * 4
			local stand = at(x0 + 2.5, 0, z)
			Kit.solid(Kit.post(dressing, stand * CFrame.new(0, 2, 0), 4, 1.4, CREAM, Enum.Material.Marble))
			Kit.post(dressing, stand * CFrame.new(0, 4.3, 0), 0.6, 0.3, GOLD, Enum.Material.Metal)
			Kit.ball(dressing, stand * CFrame.new(0, 5.4, 0), Vector3.new(1.4, 1.8, 1.4), hex("#2A2A36"))
			local ok = pcall(function()
				showcase(dressing, Gear.maskModel(id), stand * CFrame.new(0, 5.5, -0.7) * CFrame.Angles(0, -PI / 2, 0), 1.4)
			end)
			if not ok then
				Kit.ball(dressing, stand * CFrame.new(0, 5.5, -0.7), Vector3.new(1.6, 0.8, 0.3), GOLD)
			end
		end
		for _, z in { -14, 0 } do
			Pieces.chandelier(dressing, at(-55, 14, z), 2.5, GOLD, 3)
		end
		station("Shop", at(-58, 3, -9), "Mask Boutique")
		station("Wardrobe", at(-63, 3, 0), "Wardrobe")
	end

	-- The Crate Vault (east) ----------------------------------------------
	do
		local vault = Kit.model(structure, "Vault")
		local x0, x1, z0, z1 = 44, 66, -22, 4
		local stone = hex("#4A4D63")
		Kit.slab(vault, at((x0 + x1) / 2, 0.3, (z0 + z1) / 2), Vector3.new(x1 - x0, 0.6, z1 - z0), hex("#2E3044"), Enum.Material.Slate)
		Kit.wall(vault, point(x1, 0, z0), point(x1, 0, z1), 16, 1.6, stone, Enum.Material.Slate)
		Kit.wall(vault, point(x0, 0, z0), point(x1, 0, z0), 16, 1.6, stone, Enum.Material.Slate)
		Kit.wall(vault, point(x0, 0, z1), point(x1, 0, z1), 16, 1.6, stone, Enum.Material.Slate)
		Kit.wall(vault, point(x0, 0, z0), point(x0, 0, z1), 16, 1.6, stone, Enum.Material.Slate, { { At = 13, Width = 10, Height = 11 } })
		Kit.slab(vault, at((x0 + x1) / 2, 16.5, (z0 + z1) / 2), Vector3.new(x1 - x0 + 2, 1, z1 - z0 + 2), hex("#2A2C3C"), Enum.Material.Slate)
		-- The round vault door, swung open beside the entrance.
		local door = Kit.model(dressing, "VaultDoor")
		local hinge = at(x0 - 1.2, 6, -14)
		local disc = Kit.post(door, hinge * CFrame.new(-0.5, 0, -1) * CFrame.Angles(PI / 2, 0, 0), 1.2, 11, hex("#B8B9C9"), Enum.Material.DiamondPlate)
		disc.CFrame = hinge * CFrame.new(-5, 0, -1) * CFrame.Angles(0, 0, PI / 2) * CFrame.Angles(0, PI / 2, 0)
		for i = 0, 5 do
			local angle = i / 6 * PI * 2
			Kit.block(door, hinge * CFrame.new(-5.7, math.sin(angle) * 2.4, -1 + math.cos(angle) * 2.4), Vector3.new(0.4, 0.4, 2.2), GOLD, Enum.Material.Metal)
		end
		Kit.sign(dressing, at(x0 - 0.9, 14, -9) * CFrame.Angles(0, PI / 2, 0), Vector3.new(14, 2.6, 0.2), NAVY, "CRATE VAULT", GOLD)
		-- Two great crates on glowing pedestals, one per kind.
		local crates = { { "masquerade", hex("#7B2CBF"), hex("#E0B3FF"), -16 }, { "harvest", hex("#D9661A"), hex("#FFD08A"), -2 } }
		for _, info in crates do
			local base = at(58, 0, info[4])
			Kit.solid(Kit.post(dressing, base * CFrame.new(0, 1, 0), 2, 7, hex("#2A2C3C"), Enum.Material.Marble))
			local ring = Kit.glow(dressing, base * CFrame.new(0, 2.05, 0), Vector3.new(0.1, 6.4, 6.4), info[3])
			ring.Shape = Enum.PartType.Cylinder
			ring.CFrame = base * CFrame.new(0, 2.05, 0) * CFrame.Angles(0, 0, PI / 2)
			local crate = Kit.model(dressing, `Crate_{info[1]}`)
			local body = base * CFrame.new(0, 5, 0)
			Kit.block(crate, body, Vector3.new(4.4, 4.4, 4.4), info[2], Enum.Material.WoodPlanks)
			for _, edge in { { 0, 2.1, 0 }, { 0, -2.1, 0 } } do
				Kit.block(crate, body * CFrame.new(edge[1], edge[2], edge[3]), Vector3.new(4.7, 0.5, 4.7), GOLD, Enum.Material.Metal)
			end
			Kit.block(crate, body, Vector3.new(4.7, 4.7, 0.6), GOLD, Enum.Material.Metal)
			Kit.block(crate, body, Vector3.new(0.6, 4.7, 4.7), GOLD, Enum.Material.Metal)
			local star = Kit.glow(crate, body * CFrame.new(0, 3.4, 0), Vector3.new(1, 1, 1), info[3], true)
			Kit.light(star, info[3], 16, 1.4)
			crate:SetAttribute("Crate", info[1])
			Kit.float(crate, body, 0.6, 3, 12)
		end
		Pieces.chandelier(dressing, at(55, 16, -9), 3, GOLD, 3)
		station("Crates", at(53, 3, -9), "Crate Vault")
	end

	-- The Trading Hall (south-west): an open pavilion with four tables ----
	do
		local hall = Kit.model(structure, "TradingHall")
		local cx, cz = -44, 44
		Kit.slab(hall, at(cx, 0.6, cz), Vector3.new(30, 1.2, 26), hex("#D8D1BE"), Enum.Material.Marble)
		Kit.stairs(structure, at(cx + 15.6, 0, cz) * CFrame.Angles(0, PI / 2, 0), 8, 1.2, 1.6, hex("#D8D1BE"), Enum.Material.Marble)
		Kit.stairs(structure, at(cx, 0, cz - 13.6), 8, 1.2, 1.6, hex("#D8D1BE"), Enum.Material.Marble)
		for _, corner in { { -13, -11 }, { 13, -11 }, { -13, 11 }, { 13, 11 }, { 0, -11 }, { 0, 11 } } do
			Pieces.column(hall, at(cx + corner[1], 1.2, cz + corner[2]), 12, CREAM)
		end
		Kit.slab(hall, at(cx, 13.8, cz), Vector3.new(32, 1.2, 28), CREAM, Enum.Material.Marble)
		Kit.wedge(hall, at(cx, 15.9, cz - 7) * CFrame.Angles(0, PI, 0), Vector3.new(32, 3, 14), hex("#2E6E6A"), Enum.Material.Slate)
		Kit.wedge(hall, at(cx, 15.9, cz + 7), Vector3.new(32, 3, 14), hex("#2E6E6A"), Enum.Material.Slate)
		Kit.sign(hall, at(cx, 13.8, cz - 14.05), Vector3.new(16, 1.1, 0.1), CREAM, "TRADING HALL", hex("#2E6E6A"))
		for i, spot in { { -6, -4 }, { 6, -4 }, { -6, 5 }, { 6, 5 } } do
			local base = at(cx + spot[1], 1.2, cz + spot[2])
			Pieces.table(dressing, base, Vector3.new(5, 3, 3), hex("#6B4426"), if i % 2 == 0 then hex("#2E6E6A") else VELVET)
			for _, side in { -1, 1 } do
				Pieces.chair(dressing, base * CFrame.new(0, 0, side * 2.6) * CFrame.Angles(0, if side > 0 then 0 else PI, 0), hex("#6B4426"), GOLD)
			end
			local lamp = Kit.glow(dressing, base * CFrame.new(0, 3.3, 0), Vector3.new(0.6, 0.8, 0.6), hex("#FFE7A3"), true)
			if i % 2 == 1 then
				Kit.light(lamp, hex("#FFE7A3"), 12, 0.9)
			end
		end
		station("Trade", at(cx, 4, cz), "Trading Hall")
	end

	-- The Moon Pass board (south-east) ------------------------------------
	do
		local pass = Kit.model(structure, "PassBoard")
		local cx, cz = 46, 44
		Kit.slab(pass, at(cx, 0.4, cz), Vector3.new(26, 0.8, 14), hex("#2A2C3C"), Enum.Material.Marble)
		Kit.solid(Kit.block(pass, at(cx, 9, cz + 4), Vector3.new(22, 16, 1.2), NAVY))
		Kit.block(pass, at(cx, 9, cz + 4.2), Vector3.new(23, 17, 1), GOLD, Enum.Material.Metal)
		local moon = Kit.glow(pass, at(cx, 18.5, cz + 4), Vector3.new(1, 7, 7), hex("#FFF2C2"))
		moon.Shape = Enum.PartType.Cylinder
		moon.CFrame = at(cx, 18.5, cz + 3.5) * CFrame.Angles(0, PI / 2, 0)
		Kit.light(moon, hex("#FFF2C2"), 30, 1.4)
		local bite = Kit.post(pass, at(cx + 1.6, 19.3, cz + 3.2), 1.2, 5.6, NAVY)
		bite.CFrame = at(cx + 1.6, 19.3, cz + 3.1) * CFrame.Angles(PI / 2, 0, 0)
		Kit.sign(pass, at(cx, 14.8, cz + 3.35), Vector3.new(18, 2.4, 0.1), NAVY, "MOON PASS", GOLD)
		Kit.sign(pass, at(cx, 12.6, cz + 3.35), Vector3.new(18, 1.2, 0.1), NAVY, "Season 1: Midnight Gala", CREAM)
		-- Thirty tier lamps, three rows of ten.
		for tier = 0, 29 do
			local col, row = tier % 10, tier // 10
			Kit.glow(
				pass,
				at(cx - 8.1 + col * 1.8, 9.6 - row * 2.4, cz + 3.35),
				Vector3.new(1.2, 1.2, 0.1),
				if tier % 5 == 4 then GOLD else hex("#8C7FD0"),
				true
			)
		end
		for _, side in { -1, 1 } do
			Kit.post(pass, at(cx + side * 12, 7, cz + 4), 14, 1, GOLD, Enum.Material.Metal)
		end
		station("Pass", at(cx, 3, cz - 1), "Moon Pass")
	end

	-- The emote stage (south) ---------------------------------------------
	do
		local stage = Kit.model(structure, "Stage")
		local cx, cz = 0, 54
		Kit.solid(Kit.post(stage, at(cx, 1, cz), 2, 26, hex("#2A1E40"), Enum.Material.WoodPlanks))
		Kit.post(stage, at(cx, 2.05, cz), 0.1, 24, hex("#3C2A5C"), Enum.Material.WoodPlanks)
		Kit.post(stage, at(cx, 1.9, cz), 0.3, 26.6, GOLD, Enum.Material.Metal)
		Kit.stairs(structure, at(cx, 0, cz - 13.6), 8, 2, 2.4, hex("#2A1E40"), Enum.Material.WoodPlanks)
		-- A shell at the back.
		for i = 0, 10 do
			local angle = PI * (i / 10)
			local x, z = math.cos(angle) * 13, math.sin(angle) * 4 + 8
			Kit.block(
				stage,
				at(cx + x, 9, cz + z) * CFrame.Angles(0, -angle + PI / 2, 0),
				Vector3.new(4.4, 14, 0.8),
				if i % 2 == 0 then VELVET else hex("#6E1530"),
				Enum.Material.Fabric
			)
		end
		Kit.block(stage, at(cx, 16.4, cz + 9), Vector3.new(28, 1, 6), GOLD, Enum.Material.Metal)
		Kit.sign(stage, at(cx, 16.4, cz + 5.9), Vector3.new(14, 0.9, 0.1), GOLD, "THE MOONLIGHT STAGE", PLUM)
		local floor = Kit.marker(stations, "Stage", at(cx, 3, cz))
		floor:SetAttribute("Station", "Stage")
		floor:SetAttribute("Label", "Dance floor")
		-- Spotlights on poles, aimed at the middle.
		for i, spot in { { -14, -12 }, { 14, -12 } } do
			Kit.post(dressing, at(cx + spot[1], 6, cz + spot[2]), 12, 0.6, hex("#2A2A36"), Enum.Material.Metal)
			local lamp = Kit.glow(dressing, at(cx + spot[1], 12.5, cz + spot[2]), Vector3.new(1.6, 1.6, 1.6), BULBS[i + 1], true)
			local beam = Kit.new("SpotLight", lamp, {
				Color = BULBS[i + 1],
				Range = 30,
				Brightness = 4,
				Angle = 40,
				Face = Enum.NormalId.Front,
				Shadows = true,
			})
			lamp.CFrame = CFrame.lookAt(lamp.CFrame.Position, point(cx, 2, cz))
			beam.Name = "Spot"
		end
		-- A disco ball.
		local ball = Kit.ball(dressing, at(cx, 13, cz), Vector3.new(2.6, 2.6, 2.6), hex("#DDE3F0"), Enum.Material.Glass)
		ball.Reflectance = 0.8
		Kit.post(dressing, at(cx, 15, cz), 3, 0.1, hex("#2A2A36"))
		Kit.light(ball, hex("#FFB3F0"), 20, 1)
	end

	-- The VIP balcony (north-east) ------------------------------------------
	do
		local vip = Kit.model(structure, "VipBalcony")
		local x0, x1, z0, z1, floorY = 40, 70, -70, -42, 8
		Kit.slab(vip, at((x0 + x1) / 2, floorY - 0.5, (z0 + z1) / 2), Vector3.new(x1 - x0, 1, z1 - z0), hex("#2A1E40"), Enum.Material.Marble)
		Kit.slab(vip, at((x0 + x1) / 2, floorY + 0.02, (z0 + z1) / 2), Vector3.new(x1 - x0 - 2, 0.05, z1 - z0 - 2), VELVET, Enum.Material.Fabric)
		for _, x in { x0 + 1, x1 - 1 } do
			for _, z in { z0 + 1, z1 - 1, (z0 + z1) / 2 } do
				Pieces.column(vip, at(x, 0, z), floorY - 1, CREAM)
			end
		end
		-- Stairs up from the plaza, a velvet rope at the top.
		Kit.stairs(structure, at(28, 0, -46) * CFrame.Angles(0, -PI / 2, 0), 6, floorY, 12, CREAM, Enum.Material.Marble)
		local rope = Kit.model(dressing, "VelvetRope")
		for _, z in { -49.2, -42.8 } do
			Kit.post(rope, at(40.5, floorY + 1.6, z), 3.2, 0.4, GOLD, Enum.Material.Metal)
			Kit.ball(rope, at(40.5, floorY + 3.3, z), Vector3.new(0.6, 0.6, 0.6), GOLD, Enum.Material.Metal)
		end
		Kit.span(rope, point(40.5, floorY + 2.6, -49), point(40.5, floorY + 2.6, -43), 0.3, 0.3, VELVET, Enum.Material.Fabric)
		local gate = Kit.barrier(lobby, at(40.5, floorY + 6, -46), Vector3.new(1, 12, 6.4))
		gate.Name = "VipGate"
		Kit.sign(dressing, at(40.2, floorY + 6.4, -46) * CFrame.Angles(0, PI / 2, 0), Vector3.new(5, 1.2, 0.1), PLUM, "VIP", GOLD)
		-- Railings round the open sides.
		for _, edge in { { x0, z1, x1, z1 }, { x0, z0, x0, -49.5 }, { x0, -42.5, x0, z1 } } do
			local a, b = point(edge[1], floorY, edge[2]), point(edge[3], floorY, edge[4])
			Kit.span(vip, a + Vector3.new(0, 3, 0), b + Vector3.new(0, 3, 0), 0.4, 0.4, GOLD, Enum.Material.Metal)
			local length = (b - a).Magnitude
			for i = 0, math.floor(length / 2) do
				Kit.post(vip, CFrame.new(a:Lerp(b, i / math.max(1, math.floor(length / 2))) + Vector3.new(0, 1.5, 0)), 3, 0.2, GOLD, Enum.Material.Metal)
			end
			local mid = (a + b) / 2
			Kit.barrier(vip, CFrame.new(mid + Vector3.new(0, 5, 0)), Vector3.new(math.max(0.5, math.abs(b.X - a.X)), 10, math.max(0.5, math.abs(b.Z - a.Z))))
		end
		Kit.wall(vip, point(x0, floorY, z0), point(x1, floorY, z0), 12, 1, hex("#3B2B5C"), Enum.Material.Plaster)
		Kit.wall(vip, point(x1, floorY, z0), point(x1, floorY, z1), 12, 1, hex("#3B2B5C"), Enum.Material.Plaster)
		-- Comfy things: sofas, a fireplace, a chandelier and a view.
		Pieces.fireplace(dressing, at(55, floorY, z0 + 1.7) * CFrame.Angles(0, PI, 0), hex("#B9B4CC"), hex("#FF9A3C"))
		for _, spot in { { 48, -58, PI / 2 }, { 62, -58, -PI / 2 }, { 55, -50, PI } } do
			local base = at(spot[1], floorY, spot[2]) * CFrame.Angles(0, spot[3], 0)
			Kit.solid(Kit.block(dressing, base * CFrame.new(0, 1, 0), Vector3.new(7, 2, 3), VELVET, Enum.Material.Fabric))
			Kit.block(dressing, base * CFrame.new(0, 2.6, 1.2), Vector3.new(7, 2.4, 0.8), VELVET, Enum.Material.Fabric)
			for _, side in { -1, 1 } do
				Kit.block(dressing, base * CFrame.new(side * 3.3, 2.1, 0), Vector3.new(0.8, 1.6, 3), hex("#6E1530"), Enum.Material.Fabric)
			end
		end
		Pieces.table(dressing, at(55, floorY, -57), Vector3.new(4, 2, 3), GOLD, nil)
		Pieces.chandelier(dressing, at(55, floorY + 12, -56), 3, GOLD, 3)
		local trophy = showcase(dressing, Gear.bladeModel("blade_gala"), at(55, floorY + 3.4, -57) * CFrame.Angles(0, PI / 4, 0), 1.4)
		trophy.Name = "Trophy"
		Kit.marker(lobby, "VipSpawn", at(55, floorY + 3, -52))
	end

	-- Leaderboards (north-west) -------------------------------------------
	do
		local stats = { { "Wins", "MOST WINS", -60 }, { "Takedowns", "TOP GUARDIANS", -44 }, { "CoinsEarned", "RICHEST", -28 } }
		for _, info in stats do
			local board = Kit.model(boards, `Board_{info[1]}`)
			board:SetAttribute("Stat", info[1])
			local base = at(info[3], 0, -60)
			Kit.solid(Kit.block(board, base * CFrame.new(0, 9, 0), Vector3.new(12, 16, 1), NAVY))
			Kit.block(board, base * CFrame.new(0, 9, -0.2), Vector3.new(12.8, 16.8, 0.8), GOLD, Enum.Material.Metal)
			for _, side in { -1, 1 } do
				Kit.post(board, base * CFrame.new(side * 5, 0.6, 0), 1.2, 1.4, hex("#2A2A36"), Enum.Material.Metal)
			end
			Kit.sign(board, base * CFrame.new(0, 15.6, 0.55) * CFrame.Angles(0, PI, 0), Vector3.new(11, 1.8, 0.1), NAVY, info[2], GOLD)
			local screen = Kit.block(board, base * CFrame.new(0, 7.6, 0.55), Vector3.new(11, 12, 0.1), hex("#141633"))
			screen.Name = "Screen"
			local cap = Kit.glow(board, base * CFrame.new(0, 17.8, 0.2), Vector3.new(1.4, 1.4, 1.4), GOLD, true)
			cap.Name = "Cap"
		end
	end

	-- Benches, string lights, pumpkins and lanterns -----------------------
	do
		for _, spot in {
			{ -28, -10, PI / 2 },
			{ -28, 10, PI / 2 },
			{ 28, -10, -PI / 2 },
			{ 28, 10, -PI / 2 },
			{ -12, 30, PI },
			{ 12, 30, PI },
			{ -14, -36, 0 },
			{ 14, -36, 0 },
		} do
			Pieces.bench(dressing, at(spot[1], 0.2, spot[2]) * CFrame.Angles(0, spot[3], 0), hex("#6B4426"))
		end
		local poles = { { -30, -30 }, { 30, -30 }, { 30, 30 }, { -30, 30 } }
		for i, pole in poles do
			Pieces.lamp(dressing, at(pole[1], 0, pole[2]), hex("#FFE7A3"), 14)
			local nextPole = poles[i % #poles + 1]
			Pieces.stringLights(dressing, point(pole[1], 13.5, pole[2]), point(nextPole[1], 13.5, nextPole[2]), BULBS, 3)
			Pieces.stringLights(dressing, point(pole[1], 13.5, pole[2]), point(0, 16, 0), BULBS, 1.5, 7)
		end
		for i, spot in { { -40, -30 }, { 40, -30 }, { -24, 64 }, { 24, 64 }, { -70, 20 }, { 70, 20 }, { -70, -40 }, { 70, -30 }, { 20, -68 }, { -20, -68 } } do
			Pieces.pumpkin(dressing, at(spot[1], 0.2, spot[2]), 1.6 + (i % 3) * 0.6, i % 2 == 0)
		end
		for i, spot in { { -70, -70 }, { 70, 70 }, { -70, 70 }, { -20, 70 }, { 20, 70 } } do
			Pieces.tree(dressing, at(spot[1], 0, spot[2]), 18, 900 + i, LEAVES)
		end
	end

	lobby.WorldPivot = origin
	return lobby
end

return Lobby
