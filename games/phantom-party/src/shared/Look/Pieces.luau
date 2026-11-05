-- Furniture and scenery shared by the lobby and the maps: lamps, tables,
-- bookshelves, beds, trees, hedges, fountains and the rest. Each builder
-- takes the CFrame of the piece's base, at floor level, facing -Z. Big
-- furniture people would bump into is solid; small dressing isn't.

local Kit = require(script.Parent.Kit)

local Pieces = {}

local hex = Kit.color
local PI = math.pi

local WOOD = hex("#5A3A22")
local DARK_WOOD = hex("#3B2416")
local IRON = hex("#2A2A30")
local BRASS = hex("#C9A44C")
local WARM = hex("#FFC98A")
local STONE = hex("#8E8A96")

-- A street lamp: a post with a glowing lantern on top.
function Pieces.lamp(parent: Instance, base: CFrame, light: Color3?, height: number?)
	local model = Kit.model(parent, "Lamp")
	local h = height or 10
	local color = light or WARM
	Kit.solid(Kit.post(model, base * CFrame.new(0, h / 2, 0), h, 0.5, IRON, Enum.Material.Metal))
	Kit.post(model, base * CFrame.new(0, 0.3, 0), 0.6, 1.2, IRON, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(0, h + 0.1, 0), Vector3.new(1.4, 0.2, 1.4), IRON, Enum.Material.Metal)
	local bulb = Kit.glow(model, base * CFrame.new(0, h + 0.9, 0), Vector3.new(1, 1.4, 1), color)
	Kit.wedge(model, base * CFrame.new(0, h + 1.85, 0.0), Vector3.new(1.5, 0.5, 1.5), IRON, Enum.Material.Metal)
	Kit.light(bulb, color, 22, 1.6)
	return model
end

-- A candle sconce on a wall, facing out of the wall along -Z.
function Pieces.sconce(parent: Instance, at: CFrame, color: Color3?, withLight: boolean?)
	local model = Kit.model(parent, "Sconce")
	Kit.block(model, at * CFrame.new(0, 0, 0.1), Vector3.new(0.5, 1, 0.2), BRASS, Enum.Material.Metal)
	Kit.block(model, at * CFrame.new(0, -0.2, -0.35), Vector3.new(0.6, 0.12, 0.6), BRASS, Enum.Material.Metal)
	Kit.post(model, at * CFrame.new(0, 0.15, -0.35), 0.6, 0.22, hex("#F5EEDC"))
	local flame = Kit.glow(model, at * CFrame.new(0, 0.6, -0.35), Vector3.new(0.18, 0.3, 0.18), color or WARM, true)
	if withLight ~= false then
		Kit.light(flame, color or WARM, 14, 1.1, true)
	end
	return model
end

-- A chandelier hanging from a ceiling at top (the ceiling's underside).
function Pieces.chandelier(parent: Instance, top: CFrame, radius: number, color: Color3?, drop: number?)
	local model = Kit.model(parent, "Chandelier")
	local hang = drop or 4
	local glow = color or WARM
	Kit.post(model, top * CFrame.new(0, -hang / 2, 0), hang, 0.15, BRASS, Enum.Material.Metal)
	local ringY = -hang - 0.3
	local arms = 8
	for i = 1, arms do
		local angle = i / arms * PI * 2
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		Kit.span(
			model,
			(top * CFrame.new(0, ringY, 0)).Position,
			(top * CFrame.new(x, ringY, z)).Position,
			0.15,
			0.15,
			BRASS
		)
		Kit.post(model, top * CFrame.new(x, ringY + 0.4, z), 0.7, 0.25, hex("#F5EEDC"))
		Kit.glow(model, top * CFrame.new(x, ringY + 0.95, z), Vector3.new(0.22, 0.38, 0.22), glow, true)
		-- Crystal drops.
		local drop2 = Kit.ball(
			model,
			top * CFrame.new(x * 0.7, ringY - 0.6, z * 0.7),
			Vector3.new(0.25, 0.45, 0.25),
			hex("#E8F4FF"),
			Enum.Material.Glass
		)
		drop2.Transparency = 0.3
	end
	Kit.ball(model, top * CFrame.new(0, ringY, 0), Vector3.new(1.2, 1.2, 1.2), BRASS, Enum.Material.Metal)
	local core = Kit.glow(model, top * CFrame.new(0, ringY - 0.9, 0), Vector3.new(0.5, 0.5, 0.5), glow, true)
	Kit.light(core, glow, radius * 6 + 16, 2.2)
	return model
end

-- A table with four legs, optionally with a cloth over it.
function Pieces.table(parent: Instance, base: CFrame, size: Vector3, wood: Color3?, cloth: Color3?)
	local model = Kit.model(parent, "Table")
	local color = wood or WOOD
	local top = Kit.solid(
		Kit.block(
			model,
			base * CFrame.new(0, size.Y - 0.2, 0),
			Vector3.new(size.X, 0.4, size.Z),
			color,
			Enum.Material.Wood
		)
	)
	top.Name = "Top"
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		Kit.block(
			model,
			base * CFrame.new(corner[1] * (size.X / 2 - 0.4), (size.Y - 0.4) / 2, corner[2] * (size.Z / 2 - 0.4)),
			Vector3.new(0.4, size.Y - 0.4, 0.4),
			color,
			Enum.Material.Wood
		)
	end
	if cloth then
		Kit.block(
			model,
			base * CFrame.new(0, size.Y + 0.02, 0),
			Vector3.new(size.X + 0.6, 0.06, size.Z * 0.6),
			cloth,
			Enum.Material.Fabric
		)
	end
	-- Something's always blocking under a table, so it can't be hidden in.
	Kit.barrier(
		model,
		base * CFrame.new(0, (size.Y - 0.4) / 2, 0),
		Vector3.new(size.X - 0.4, size.Y - 0.4, size.Z - 0.4)
	)
	return model
end

-- A high-backed chair, its seat facing -Z.
function Pieces.chair(parent: Instance, base: CFrame, wood: Color3?, seat: Color3?)
	local model = Kit.model(parent, "Chair")
	local color = wood or DARK_WOOD
	Kit.block(
		model,
		base * CFrame.new(0, 1.8, 0),
		Vector3.new(1.8, 0.3, 1.8),
		seat or hex("#7A1F2B"),
		Enum.Material.Fabric
	)
	Kit.block(model, base * CFrame.new(0, 3.4, 0.8), Vector3.new(1.8, 3, 0.25), color, Enum.Material.Wood)
	Kit.block(model, base * CFrame.new(0, 4.95, 0.8), Vector3.new(2, 0.3, 0.35), color, Enum.Material.Wood)
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		Kit.block(
			model,
			base * CFrame.new(corner[1] * 0.75, 0.85, corner[2] * 0.75),
			Vector3.new(0.25, 1.7, 0.25),
			color
		)
	end
	return model
end

-- A tall bookshelf standing against a wall, its shelves facing -Z.
function Pieces.bookshelf(parent: Instance, base: CFrame, width: number, height: number, seed: number)
	local model = Kit.model(parent, "Bookshelf")
	local random = Kit.random(seed)
	local depth = 1.6
	Kit.solid(
		Kit.block(
			model,
			base * CFrame.new(0, height / 2, 0.6),
			Vector3.new(width, height, 0.4),
			DARK_WOOD,
			Enum.Material.Wood
		)
	)
	for _, side in { -1, 1 } do
		Kit.solid(
			Kit.block(
				model,
				base * CFrame.new(side * (width / 2 - 0.2), height / 2, 0),
				Vector3.new(0.4, height, depth),
				DARK_WOOD,
				Enum.Material.Wood
			)
		)
	end
	Kit.block(
		model,
		base * CFrame.new(0, height - 0.2, 0),
		Vector3.new(width, 0.4, depth),
		DARK_WOOD,
		Enum.Material.Wood
	)
	local shelves = math.max(2, math.floor(height / 2.6))
	local colors = { hex("#7A1F2B"), hex("#1F4E5F"), hex("#2E5E3A"), hex("#8C6A2E"), hex("#4A2E6B"), hex("#B5651D") }
	for s = 0, shelves - 1 do
		local y = 0.3 + s * (height - 0.6) / shelves
		Kit.block(
			model,
			base * CFrame.new(0, y, 0),
			Vector3.new(width - 0.4, 0.2, depth),
			DARK_WOOD,
			Enum.Material.Wood
		)
		-- Books, packed in with the odd gap and one leaning.
		local x = -width / 2 + 0.5
		while x < width / 2 - 0.6 do
			local w = random.number(0.25, 0.45)
			local h = random.number(1.2, (height - 0.6) / shelves - 0.3)
			if random.next() > 0.12 then
				Kit.block(
					model,
					base * CFrame.new(x + w / 2, y + 0.1 + h / 2, -0.05),
					Vector3.new(w, h, depth - 0.5),
					random.pick(colors),
					Enum.Material.Fabric
				)
			end
			x += w + 0.04
		end
	end
	-- A solid front so nobody walks into the shelves.
	Kit.barrier(model, base * CFrame.new(0, height / 2, -0.2), Vector3.new(width, height, depth - 0.4))
	return model
end

-- A four-poster bed, its pillows at +Z.
function Pieces.bed(parent: Instance, base: CFrame, frame: Color3?, sheet: Color3?)
	local model = Kit.model(parent, "Bed")
	local wood = frame or DARK_WOOD
	Kit.solid(Kit.block(model, base * CFrame.new(0, 1.2, 0), Vector3.new(7, 1.6, 10), wood, Enum.Material.Wood))
	Kit.block(
		model,
		base * CFrame.new(0, 2.3, -0.5),
		Vector3.new(6.6, 0.8, 8.6),
		sheet or hex("#6B2D5C"),
		Enum.Material.Fabric
	)
	Kit.block(model, base * CFrame.new(0, 2.5, 3.9), Vector3.new(6, 0.7, 1.6), hex("#F2EEE6"), Enum.Material.Fabric)
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		Kit.solid(
			Kit.post(model, base * CFrame.new(corner[1] * 3.3, 4, corner[2] * 4.8), 8, 0.4, wood, Enum.Material.Wood)
		)
	end
	Kit.block(model, base * CFrame.new(0, 8, 0), Vector3.new(7, 0.3, 10), wood, Enum.Material.Wood)
	-- Curtains drawn back at the corners.
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		Kit.block(
			model,
			base * CFrame.new(corner[1] * 3.1, 5, corner[2] * 4.5),
			Vector3.new(0.6, 5.8, 0.8),
			sheet or hex("#6B2D5C"),
			Enum.Material.Fabric
		)
	end
	return model
end

-- A wardrobe big enough to hide in: open at the front (-Z), its doors
-- swung wide.
function Pieces.wardrobe(parent: Instance, base: CFrame, wood: Color3?)
	local model = Kit.model(parent, "Wardrobe")
	local color = wood or DARK_WOOD
	local w, h, d = 6, 9, 4
	Kit.solid(
		Kit.block(model, base * CFrame.new(0, h / 2, d / 2 - 0.2), Vector3.new(w, h, 0.4), color, Enum.Material.Wood)
	)
	for _, side in { -1, 1 } do
		Kit.solid(
			Kit.block(
				model,
				base * CFrame.new(side * (w / 2 - 0.2), h / 2, 0),
				Vector3.new(0.4, h, d),
				color,
				Enum.Material.Wood
			)
		)
		Kit.block(
			model,
			base * CFrame.new(side * (w / 2 + 1.2), h / 2 - 0.3, -d / 2 - 1.1) * CFrame.Angles(0, side * 1.1, 0),
			Vector3.new(2.8, h - 0.8, 0.3),
			color,
			Enum.Material.Wood
		)
	end
	Kit.solid(
		Kit.block(
			model,
			base * CFrame.new(0, h + 0.2, 0),
			Vector3.new(w + 0.4, 0.4, d + 0.4),
			color,
			Enum.Material.Wood
		)
	)
	Kit.block(model, base * CFrame.new(0, h - 1.2, 0.2), Vector3.new(w - 0.8, 0.12, 0.12), BRASS, Enum.Material.Metal)
	-- Coats on the rail.
	for i = -1, 1 do
		Kit.block(
			model,
			base * CFrame.new(i * 1.4, h - 3.5, 0.6),
			Vector3.new(1.2, 4.2, 0.3),
			hex(({ "#3A2F55", "#5E2129", "#22403A" })[i + 2]),
			Enum.Material.Fabric
		)
	end
	return model
end

-- A stone fireplace against a wall, its hearth facing -Z.
function Pieces.fireplace(parent: Instance, base: CFrame, stone: Color3?, fire: Color3?)
	local model = Kit.model(parent, "Fireplace")
	local color = stone or hex("#6E6676")
	Kit.solid(Kit.block(model, base * CFrame.new(-3.2, 3.5, 0), Vector3.new(1.6, 7, 2.4), color, Enum.Material.Slate))
	Kit.solid(Kit.block(model, base * CFrame.new(3.2, 3.5, 0), Vector3.new(1.6, 7, 2.4), color, Enum.Material.Slate))
	Kit.solid(Kit.block(model, base * CFrame.new(0, 6.2, 0), Vector3.new(8, 1.6, 2.4), color, Enum.Material.Slate))
	Kit.solid(Kit.block(model, base * CFrame.new(0, 7.2, -0.3), Vector3.new(9, 0.4, 3), DARK_WOOD, Enum.Material.Wood))
	Kit.block(model, base * CFrame.new(0, 3, 0.9), Vector3.new(4.8, 6, 0.6), hex("#1A1414"), Enum.Material.Slate)
	Kit.block(model, base * CFrame.new(0, 0.2, -0.6), Vector3.new(6, 0.4, 2.4), color, Enum.Material.Slate)
	for i = -1, 1 do
		Kit.log(
			model,
			base * CFrame.new(i * 0.6, 0.6, 0.1) * CFrame.Angles(0, PI / 2 + i * 0.4, 0),
			2.6,
			0.5,
			WOOD,
			Enum.Material.Wood
		)
	end
	local flame =
		Kit.glow(model, base * CFrame.new(0, 1.3, 0.1), Vector3.new(1.6, 1.4, 0.8), fire or hex("#FF8A3D"), true)
	Kit.light(flame, fire or hex("#FF8A3D"), 18, 2, true)
	local fireEmitter = Instance.new("ParticleEmitter")
	fireEmitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	fireEmitter.Color = ColorSequence.new(fire or hex("#FF8A3D"))
	fireEmitter.LightEmission = 1
	fireEmitter.Rate = 14
	fireEmitter.Lifetime = NumberRange.new(0.5, 0.9)
	fireEmitter.Speed = NumberRange.new(1, 2)
	fireEmitter.Size = NumberSequence.new(1, 0.1)
	fireEmitter.Acceleration = Vector3.new(0, 3, 0)
	fireEmitter.Parent = flame
	return model
end

-- A framed painting on a wall, facing -Z: a few colour bands as a
-- landscape, or a portrait's oval.
function Pieces.painting(
	parent: Instance,
	at: CFrame,
	size: Vector2,
	frame: Color3,
	colors: { Color3 },
	portrait: boolean?
)
	local model = Kit.model(parent, "Painting")
	Kit.block(
		model,
		at * CFrame.new(0, 0, 0.1),
		Vector3.new(size.X + 0.6, size.Y + 0.6, 0.2),
		frame,
		Enum.Material.Metal
	)
	if portrait then
		Kit.block(
			model,
			at * CFrame.new(0, 0, -0.02),
			Vector3.new(size.X, size.Y, 0.05),
			colors[1],
			Enum.Material.Fabric
		)
		Kit.ball(
			model,
			at * CFrame.new(0, size.Y * 0.12, -0.06),
			Vector3.new(size.X * 0.42, size.Y * 0.42, 0.05),
			colors[2] or colors[1]
		)
		Kit.ball(
			model,
			at * CFrame.new(0, -size.Y * 0.3, -0.05),
			Vector3.new(size.X * 0.7, size.Y * 0.45, 0.04),
			colors[3] or colors[1]
		)
		-- A mask over the portrait's eyes: everyone here wears one.
		Kit.block(
			model,
			at * CFrame.new(0, size.Y * 0.15, -0.09),
			Vector3.new(size.X * 0.36, size.Y * 0.08, 0.03),
			hex("#15121C")
		)
	else
		local bands = #colors
		for i, color in colors do
			Kit.block(
				model,
				at * CFrame.new(0, size.Y / 2 - (i - 0.5) * size.Y / bands, -0.02),
				Vector3.new(size.X, size.Y / bands, 0.05),
				color,
				Enum.Material.Fabric
			)
		end
	end
	return model
end

-- A rug on the floor.
function Pieces.rug(parent: Instance, base: CFrame, size: Vector2, color: Color3, trim: Color3)
	local model = Kit.model(parent, "Rug")
	Kit.block(model, base * CFrame.new(0, 0.03, 0), Vector3.new(size.X, 0.06, size.Y), trim, Enum.Material.Fabric)
	Kit.block(
		model,
		base * CFrame.new(0, 0.05, 0),
		Vector3.new(size.X - 1, 0.06, size.Y - 1),
		color,
		Enum.Material.Fabric
	)
	Kit.block(
		model,
		base * CFrame.new(0, 0.07, 0),
		Vector3.new(size.X * 0.4, 0.06, size.Y * 0.4),
		trim,
		Enum.Material.Fabric
	)
	return model
end

-- A potted plant: a pot and a cluster of leafy balls.
function Pieces.plant(parent: Instance, base: CFrame, seed: number, leaves: Color3?)
	local model = Kit.model(parent, "Plant")
	local random = Kit.random(seed)
	Kit.solid(Kit.post(model, base * CFrame.new(0, 1, 0), 2, 1.8, hex("#8C4A2F"), Enum.Material.Slate))
	local green = leaves or hex("#2F6B3A")
	for _ = 1, 5 do
		local size = random.number(1.2, 2)
		Kit.ball(
			model,
			base * CFrame.new(random.number(-0.6, 0.6), random.number(2.4, 3.8), random.number(-0.6, 0.6)),
			Vector3.new(size, size, size),
			green,
			Enum.Material.Grass
		)
	end
	return model
end

-- A grand piano, its keys facing -Z.
function Pieces.piano(parent: Instance, base: CFrame)
	local model = Kit.model(parent, "Piano")
	local black = hex("#121016")
	Kit.solid(Kit.block(model, base * CFrame.new(0, 3, 0.8), Vector3.new(6, 1.6, 6), black))
	Kit.block(model, base * CFrame.new(0, 4.1, 1.8) * CFrame.Angles(-0.6, 0, 0), Vector3.new(5.6, 0.2, 4), black)
	Kit.block(model, base * CFrame.new(0, 3.3, -2.6), Vector3.new(5.4, 0.3, 0.9), hex("#F4F1E8"))
	for i = -6, 6 do
		Kit.block(model, base * CFrame.new(i * 0.4, 3.5, -2.45), Vector3.new(0.18, 0.12, 0.5), black)
	end
	for _, spot in { { -2.6, -1.8 }, { 2.6, -1.8 }, { 0, 3.6 } } do
		Kit.post(model, base * CFrame.new(spot[1], 1.1, spot[2]), 2.2, 0.4, black)
	end
	Kit.block(model, base * CFrame.new(0, 1.6, -4.2), Vector3.new(3.4, 0.5, 1.4), black)
	return model
end

-- A grandfather clock against a wall, its face to -Z.
function Pieces.clock(parent: Instance, base: CFrame)
	local model = Kit.model(parent, "Clock")
	Kit.solid(Kit.block(model, base * CFrame.new(0, 4, 0), Vector3.new(2.4, 8, 1.6), DARK_WOOD, Enum.Material.Wood))
	Kit.wedge(
		model,
		base * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, PI / 2, 0),
		Vector3.new(1.6, 1.2, 2.6),
		DARK_WOOD,
		Enum.Material.Wood
	)
	Kit.post(
		model,
		base * CFrame.new(0, 6.6, -0.85) * CFrame.Angles(PI / 2, 0, 0) * CFrame.Angles(0, 0, PI / 2),
		0.1,
		1.8,
		hex("#F2E9D0")
	)
	Kit.block(model, base * CFrame.new(0, 6.8, -0.92), Vector3.new(0.08, 0.7, 0.05), hex("#121016"))
	Kit.block(
		model,
		base * CFrame.new(0.2, 6.6, -0.92) * CFrame.Angles(0, 0, 1.2),
		Vector3.new(0.08, 0.5, 0.05),
		hex("#121016")
	)
	local window = Kit.block(
		model,
		base * CFrame.new(0, 3.4, -0.82),
		Vector3.new(1.4, 3.6, 0.05),
		hex("#2A1C12"),
		Enum.Material.Glass
	)
	window.Transparency = 0.3
	Kit.ball(model, base * CFrame.new(0, 2.4, -0.7), Vector3.new(0.8, 0.8, 0.1), BRASS, Enum.Material.Metal)
	return model
end

-- A suit of armour on a plinth, facing -Z.
function Pieces.armor(parent: Instance, base: CFrame)
	local model = Kit.model(parent, "Armor")
	local steel = hex("#A7ADBA")
	Kit.solid(Kit.block(model, base * CFrame.new(0, 0.5, 0), Vector3.new(3, 1, 3), STONE, Enum.Material.Slate))
	Kit.block(model, base * CFrame.new(-0.5, 2.5, 0), Vector3.new(0.8, 3, 0.8), steel, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(0.5, 2.5, 0), Vector3.new(0.8, 3, 0.8), steel, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(0, 5.2, 0), Vector3.new(2.2, 2.6, 1.2), steel, Enum.Material.Metal)
	Kit.ball(model, base * CFrame.new(-1.3, 6.2, 0), Vector3.new(0.9, 0.9, 0.9), steel, Enum.Material.Metal)
	Kit.ball(model, base * CFrame.new(1.3, 6.2, 0), Vector3.new(0.9, 0.9, 0.9), steel, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(-1.4, 4.9, 0), Vector3.new(0.6, 2.2, 0.6), steel, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(1.4, 4.9, -0.2), Vector3.new(0.6, 2.2, 0.6), steel, Enum.Material.Metal)
	Kit.ball(model, base * CFrame.new(0, 7.1, 0), Vector3.new(1.3, 1.5, 1.3), steel, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(0, 7.1, -0.6), Vector3.new(0.9, 0.12, 0.1), hex("#121016"))
	Kit.block(model, base * CFrame.new(0, 7.9, 0), Vector3.new(0.2, 0.6, 1.2), hex("#8C1C3A"), Enum.Material.Fabric)
	-- A banner held upright instead of a weapon.
	Kit.post(model, base * CFrame.new(1.4, 5, -0.6), 7, 0.15, BRASS, Enum.Material.Metal)
	Kit.block(
		model,
		base * CFrame.new(1.4, 7.3, -1.2),
		Vector3.new(0.1, 1.6, 1.1),
		hex("#4A2E6B"),
		Enum.Material.Fabric
	)
	return model
end

-- A kitchen counter, its front at -Z.
function Pieces.counter(parent: Instance, base: CFrame, length: number, top: Color3?, body: Color3?)
	local model = Kit.model(parent, "Counter")
	Kit.solid(
		Kit.block(
			model,
			base * CFrame.new(0, 1.8, 0),
			Vector3.new(length, 3.6, 2.6),
			body or hex("#E7DCC8"),
			Enum.Material.Wood
		)
	)
	Kit.block(
		model,
		base * CFrame.new(0, 3.75, -0.1),
		Vector3.new(length + 0.2, 0.3, 2.9),
		top or hex("#3C3A40"),
		Enum.Material.Marble
	)
	local doors = math.max(1, math.floor(length / 2.4))
	for i = 1, doors do
		local x = -length / 2 + (i - 0.5) * length / doors
		Kit.block(
			model,
			base * CFrame.new(x, 1.8, -1.32),
			Vector3.new(length / doors - 0.3, 2.8, 0.06),
			hex("#D4C6AC"),
			Enum.Material.Wood
		)
		Kit.block(model, base * CFrame.new(x, 2.8, -1.38), Vector3.new(0.6, 0.1, 0.08), BRASS, Enum.Material.Metal)
	end
	return model
end

-- An iron range with a glowing oven and a pot on top.
function Pieces.stove(parent: Instance, base: CFrame)
	local model = Kit.model(parent, "Stove")
	Kit.solid(Kit.block(model, base * CFrame.new(0, 2, 0), Vector3.new(5, 4, 3), IRON, Enum.Material.Metal))
	local oven = Kit.glow(model, base * CFrame.new(0, 1.6, -1.52), Vector3.new(2.6, 1.6, 0.05), hex("#FF7A2E"))
	Kit.light(oven, hex("#FF7A2E"), 10, 1, true)
	Kit.post(model, base * CFrame.new(-1.2, 4.6, 0), 1.2, 1.6, hex("#4A4A52"), Enum.Material.Metal)
	Kit.post(model, base * CFrame.new(-1.2, 5.25, 0), 0.1, 1.4, hex("#7FC97F"), Enum.Material.Neon)
	Kit.post(model, base * CFrame.new(1.3, 4.3, 0), 0.6, 1.4, hex("#4A4A52"), Enum.Material.Metal)
	Kit.post(model, base * CFrame.new(0, 7, 1.2), 6, 0.8, IRON, Enum.Material.Metal)
	return model
end

-- A barrel, upright.
function Pieces.barrel(parent: Instance, base: CFrame, color: Color3?)
	local model = Kit.model(parent, "Barrel")
	Kit.solid(Kit.post(model, base * CFrame.new(0, 1.6, 0), 3.2, 2.4, color or hex("#7A5230"), Enum.Material.Wood))
	for _, y in { 0.5, 2.7 } do
		Kit.post(model, base * CFrame.new(0, y, 0), 0.25, 2.5, IRON, Enum.Material.Metal)
	end
	return model
end

-- A wooden crate.
function Pieces.crate(parent: Instance, base: CFrame, size: number?, color: Color3?)
	local model = Kit.model(parent, "Crate")
	local s = size or 3
	Kit.solid(
		Kit.block(
			model,
			base * CFrame.new(0, s / 2, 0),
			Vector3.new(s, s, s),
			color or hex("#9C6B3C"),
			Enum.Material.WoodPlanks
		)
	)
	for _, side in { -1, 1 } do
		Kit.block(
			model,
			base * CFrame.new(side * (s / 2 - 0.15), s / 2, -s / 2 - 0.02),
			Vector3.new(0.3, s, 0.05),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	Kit.block(
		model,
		base * CFrame.new(0, s / 2, -s / 2 - 0.03) * CFrame.Angles(0, 0, PI / 4),
		Vector3.new(0.3, s * 1.3, 0.05),
		DARK_WOOD,
		Enum.Material.Wood
	)
	return model
end

-- A leafy tree.
function Pieces.tree(parent: Instance, base: CFrame, height: number, seed: number, leaves: Color3?)
	local model = Kit.model(parent, "Tree")
	local random = Kit.random(seed)
	Kit.solid(
		Kit.post(
			model,
			base * CFrame.new(0, height * 0.35, 0),
			height * 0.7,
			height * 0.09,
			hex("#4A3426"),
			Enum.Material.Wood
		)
	)
	local green = leaves or hex("#24452C")
	for _ = 1, 6 do
		local size = random.number(height * 0.3, height * 0.45)
		Kit.ball(
			model,
			base
				* CFrame.new(
					random.number(-1, 1) * height * 0.15,
					height * random.number(0.65, 0.9),
					random.number(-1, 1) * height * 0.15
				),
			Vector3.new(size, size * 0.85, size),
			green,
			Enum.Material.Grass
		)
	end
	return model
end

-- A bare, twisted tree for spooky places.
function Pieces.deadTree(parent: Instance, base: CFrame, height: number, seed: number)
	local model = Kit.model(parent, "DeadTree")
	local random = Kit.random(seed)
	local bark = hex("#2E2621")
	Kit.solid(
		Kit.post(model, base * CFrame.new(0, height * 0.3, 0), height * 0.6, height * 0.08, bark, Enum.Material.Wood)
	)
	local top = base * CFrame.new(0, height * 0.6, 0)
	for i = 1, 5 do
		local angle = i / 5 * PI * 2 + random.number(-0.3, 0.3)
		local reach = height * random.number(0.25, 0.4)
		local tip = top * CFrame.new(math.cos(angle) * reach, random.number(0.1, 0.4) * height, math.sin(angle) * reach)
		Kit.span(model, top.Position, tip.Position, height * 0.035, height * 0.035, bark, Enum.Material.Wood)
		local twig = tip
			* CFrame.new(math.cos(angle + 0.8) * reach * 0.4, reach * 0.3, math.sin(angle + 0.8) * reach * 0.4)
		Kit.span(model, tip.Position, twig.Position, height * 0.02, height * 0.02, bark, Enum.Material.Wood)
	end
	return model
end

-- A trimmed hedge from a to b on the ground.
function Pieces.hedge(parent: Instance, a: Vector3, b: Vector3, height: number, color: Color3?)
	local part = Kit.span(
		parent,
		a + Vector3.new(0, height / 2, 0),
		b + Vector3.new(0, height / 2, 0),
		3,
		height,
		color or hex("#1F3D26"),
		Enum.Material.Grass
	)
	part.Name = "Hedge"
	return Kit.solid(part)
end

-- A park bench, its seat facing -Z.
function Pieces.bench(parent: Instance, base: CFrame, wood: Color3?)
	local model = Kit.model(parent, "Bench")
	local color = wood or hex("#6B4426")
	Kit.solid(Kit.block(model, base * CFrame.new(0, 1.7, 0), Vector3.new(6, 0.3, 1.8), color, Enum.Material.Wood))
	Kit.block(
		model,
		base * CFrame.new(0, 3, 0.8) * CFrame.Angles(-0.2, 0, 0),
		Vector3.new(6, 1.6, 0.25),
		color,
		Enum.Material.Wood
	)
	for _, side in { -1, 1 } do
		Kit.block(model, base * CFrame.new(side * 2.6, 0.8, 0), Vector3.new(0.3, 1.6, 1.8), IRON, Enum.Material.Metal)
		Kit.block(model, base * CFrame.new(side * 2.6, 2.4, 0.2), Vector3.new(0.3, 0.2, 1.6), IRON, Enum.Material.Metal)
	end
	return model
end

-- A round fountain with a basin and water.
function Pieces.fountain(parent: Instance, base: CFrame, radius: number, stone: Color3?, water: Color3?)
	local model = Kit.model(parent, "Fountain")
	local color = stone or STONE
	local sides = 16
	for i = 1, sides do
		local angle = i / sides * PI * 2
		local edge = 2 * PI * radius / sides + 0.4
		Kit.solid(
			Kit.block(
				model,
				base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.2, -radius),
				Vector3.new(edge, 2.4, 1.4),
				color,
				Enum.Material.Marble
			)
		)
	end
	local pool = Kit.post(
		model,
		base * CFrame.new(0, 1.4, 0),
		0.4,
		radius * 2 - 0.6,
		water or hex("#2C6E9E"),
		Enum.Material.Glass
	)
	pool.Transparency = 0.25
	Kit.post(model, base * CFrame.new(0, 0.4, 0), 0.8, radius * 2, color, Enum.Material.Marble)
	return model
end

-- A string of glowing bulbs sagging from a to b.
function Pieces.stringLights(parent: Instance, a: Vector3, b: Vector3, colors: { Color3 }, sag: number?, count: number?)
	local model = Kit.model(parent, "StringLights")
	local bulbs = count or math.max(4, math.floor((b - a).Magnitude / 3))
	local drop = sag or 2
	local previous = a
	for i = 1, bulbs do
		local t = i / (bulbs + 1)
		local point = a:Lerp(b, t) - Vector3.new(0, math.sin(t * PI) * drop, 0)
		Kit.span(model, previous, point, 0.08, 0.08, IRON)
		Kit.glow(
			model,
			CFrame.new(point - Vector3.new(0, 0.25, 0)),
			Vector3.new(0.4, 0.5, 0.4),
			colors[(i - 1) % #colors + 1],
			true
		)
		previous = point
	end
	Kit.span(model, previous, b, 0.08, 0.08, IRON)
	return model
end

-- A wrought-iron fence from a to b, with spiked railings.
function Pieces.fence(parent: Instance, a: Vector3, b: Vector3, height: number?, color: Color3?)
	local model = Kit.model(parent, "Fence")
	local h = height or 6
	local iron = color or IRON
	local length = (b - a).Magnitude
	local posts = math.max(2, math.floor(length / 2))
	for _, y in { h * 0.2, h * 0.85 } do
		Kit.span(model, a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.2, 0.2, iron, Enum.Material.Metal)
	end
	for i = 0, posts do
		local point = a:Lerp(b, i / posts)
		Kit.block(
			model,
			CFrame.new(point + Vector3.new(0, h / 2, 0)),
			Vector3.new(0.18, h, 0.18),
			iron,
			Enum.Material.Metal
		)
		Kit.ball(
			model,
			CFrame.new(point + Vector3.new(0, h + 0.15, 0)),
			Vector3.new(0.35, 0.5, 0.35),
			iron,
			Enum.Material.Metal
		)
	end
	-- Players can't climb over it.
	Kit.barrier(
		model,
		Kit.facing((a + b) / 2 + Vector3.new(0, h / 2 + 4, 0), b + Vector3.new(0, h / 2 + 4, 0)),
		Vector3.new(0.6, h + 8, length)
	)
	return model
end

-- A candelabra standing on a table or the floor.
function Pieces.candelabra(parent: Instance, base: CFrame, withLight: boolean?)
	local model = Kit.model(parent, "Candelabra")
	Kit.post(model, base * CFrame.new(0, 0.1, 0), 0.2, 1, BRASS, Enum.Material.Metal)
	Kit.post(model, base * CFrame.new(0, 0.9, 0), 1.6, 0.18, BRASS, Enum.Material.Metal)
	Kit.block(model, base * CFrame.new(0, 1.6, 0), Vector3.new(2, 0.14, 0.14), BRASS, Enum.Material.Metal)
	for i = -1, 1 do
		Kit.post(model, base * CFrame.new(i * 0.9, 2, 0), 0.7, 0.2, hex("#F5EEDC"))
		Kit.glow(model, base * CFrame.new(i * 0.9, 2.5, 0), Vector3.new(0.14, 0.24, 0.14), WARM, true)
	end
	if withLight then
		Kit.light(model:FindFirstChildWhichIsA("BasePart") :: BasePart, WARM, 12, 0.9, true)
	end
	return model
end

-- A stone gravestone, its face to -Z.
function Pieces.gravestone(parent: Instance, base: CFrame, seed: number)
	local model = Kit.model(parent, "Gravestone")
	local random = Kit.random(seed)
	local tilt = random.number(-0.12, 0.12)
	local stone = hex("#77737F")
	local h = random.number(2.6, 3.6)
	Kit.solid(
		Kit.block(
			model,
			base * CFrame.Angles(tilt, 0, tilt * 0.5) * CFrame.new(0, h / 2, 0),
			Vector3.new(2.2, h, 0.6),
			stone,
			Enum.Material.Slate
		)
	)
	Kit.post(
		model,
		base * CFrame.Angles(tilt, 0, tilt * 0.5) * CFrame.new(0, h, 0) * CFrame.Angles(PI / 2, 0, 0),
		0.6,
		2.2,
		stone,
		Enum.Material.Slate
	)
	Kit.block(model, base * CFrame.new(0, 0.1, -1.2), Vector3.new(2.4, 0.2, 2), hex("#3E3A2E"), Enum.Material.Ground)
	return model
end

-- A pumpkin, sometimes carved and glowing.
function Pieces.pumpkin(parent: Instance, base: CFrame, size: number, glowing: boolean?)
	local model = Kit.model(parent, "Pumpkin")
	local orange = hex("#E8731C")
	Kit.ball(model, base * CFrame.new(0, size * 0.42, 0), Vector3.new(size, size * 0.8, size), orange)
	Kit.ball(
		model,
		base * CFrame.new(size * 0.22, size * 0.42, 0),
		Vector3.new(size * 0.55, size * 0.82, size * 0.9),
		orange
	)
	Kit.ball(
		model,
		base * CFrame.new(-size * 0.22, size * 0.42, 0),
		Vector3.new(size * 0.55, size * 0.82, size * 0.9),
		orange
	)
	Kit.post(model, base * CFrame.new(0, size * 0.88, 0), size * 0.2, size * 0.12, hex("#3E5A26"))
	if glowing then
		local face = Kit.glow(
			model,
			base * CFrame.new(0, size * 0.48, -size * 0.47),
			Vector3.new(size * 0.5, size * 0.12, 0.05),
			hex("#FFB627")
		)
		Kit.glow(
			model,
			base * CFrame.new(-size * 0.17, size * 0.62, -size * 0.45),
			Vector3.new(size * 0.14, size * 0.14, 0.05),
			hex("#FFB627")
		)
		Kit.glow(
			model,
			base * CFrame.new(size * 0.17, size * 0.62, -size * 0.45),
			Vector3.new(size * 0.14, size * 0.14, 0.05),
			hex("#FFB627")
		)
		Kit.light(face, hex("#FFB627"), 8, 0.8, true)
	end
	return model
end

-- A column with a base and capital.
function Pieces.column(parent: Instance, base: CFrame, height: number, color: Color3?)
	local model = Kit.model(parent, "Column")
	local stone = color or hex("#E8E2D6")
	Kit.solid(Kit.post(model, base * CFrame.new(0, height / 2, 0), height, 1.8, stone, Enum.Material.Marble))
	Kit.solid(Kit.block(model, base * CFrame.new(0, 0.4, 0), Vector3.new(2.6, 0.8, 2.6), stone, Enum.Material.Marble))
	Kit.block(model, base * CFrame.new(0, height - 0.3, 0), Vector3.new(2.6, 0.6, 2.6), stone, Enum.Material.Marble)
	return model
end

return Pieces
