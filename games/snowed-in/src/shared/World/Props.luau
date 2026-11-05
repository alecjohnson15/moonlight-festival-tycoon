-- The small things the town is made of: pines, boulders, coal seams, buried
-- junk, fishing holes, frostberry bushes, supply crates, lamp posts, signs,
-- snowed-in houses, cabins and mountains. Each builder takes the ground
-- spot (a CFrame at Y = 0, facing the way the prop should face) and returns
-- a Model.
--
-- Gatherable props are tagged with a "Node" attribute (their kind in
-- Config/Resources) and have a PrimaryPart named "Hit" for the prompt.

local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)

local Props = {}

local SNOW = Enum.Material.Snow
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local ROCK = Enum.Material.Slate
local ICE = Enum.Material.Ice
local METAL = Enum.Material.DiamondPlate

local function node(model: Model, kind: string, hit: BasePart): Model
	hit.Name = "Hit"
	model.PrimaryPart = hit
	model:SetAttribute("Node", kind)
	return model
end

-- A snowy pine: a trunk and three tiers of branches, each dusted with snow.
-- scale 1 is about 22 studs tall.
function Props.pine(parent: Instance, at: CFrame, scale: number, shade: number?): Model
	local model = Kit.model(parent, "Pine")
	local s = scale
	local green = if (shade or 0) > 0.5 then Palette.PineLight else Palette.Pine
	local trunk = Kit.solid(Kit.post(model, at * CFrame.new(0, 3 * s, 0), 6 * s, 1.6 * s, Palette.Bark, WOOD))
	local tiers = { { 2.2, 11, 5 }, { 6.6, 8.4, 4.4 }, { 10.6, 5.6, 3.6 } }
	for index, tier in tiers do
		local y, width, height = tier[1] * s, tier[2] * s, tier[3] * s
		-- A tier is a squat cylinder with a snow cap on top.
		Kit.post(model, at * CFrame.new(0, 3 * s + y, 0), height, width, green, Enum.Material.Grass)
		if index < #tiers then
			Kit.post(model, at * CFrame.new(0, 3 * s + y + height / 2, 0), 0.5 * s, width * 0.82, Palette.Snow, SNOW)
		end
	end
	Kit.ball(model, at * CFrame.new(0, 3 * s + 13.4 * s, 0), Vector3.new(3.6, 2.4, 3.6) * s, Palette.Snow, SNOW)
	return node(model, "Pine", trunk)
end

-- A boulder: a few lumps of rock with snow on top.
function Props.rock(parent: Instance, at: CFrame, scale: number): Model
	local model = Kit.model(parent, "Rock")
	local s = scale
	local main = Kit.solid(
		Kit.block(
			model,
			at * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0.2, 0.6, 0.15),
			Vector3.new(7, 5, 6) * s,
			Palette.Stone,
			ROCK
		)
	)
	Kit.block(
		model,
		at * CFrame.new(2.6 * s, 1.4 * s, 1.5 * s) * CFrame.Angles(-0.2, 0.3, 0.4),
		Vector3.new(4, 3, 4) * s,
		Palette.StoneDark,
		ROCK
	)
	Kit.ball(model, at * CFrame.new(-0.3 * s, 4.6 * s, 0), Vector3.new(6, 1.6, 5) * s, Palette.Snow, SNOW)
	return node(model, "Rock", main)
end

-- A coal seam: dark rock shot through with black, glinting coal.
function Props.coalSeam(parent: Instance, at: CFrame, scale: number): Model
	local model = Kit.model(parent, "CoalSeam")
	local s = scale
	local main = Kit.solid(
		Kit.block(
			model,
			at * CFrame.new(0, 2 * s, 0) * CFrame.Angles(0.1, 0.4, -0.2),
			Vector3.new(6, 4.5, 5) * s,
			Palette.StoneDark,
			ROCK
		)
	)
	for index, offset in { Vector3.new(1.8, 3.4, 1.2), Vector3.new(-1.6, 2.6, 1.9), Vector3.new(0.4, 4.2, -1.4) } do
		local lump = Kit.block(
			model,
			at * CFrame.new(offset * s) * CFrame.Angles(index, index * 0.7, 0),
			Vector3.new(1.6, 1.4, 1.5) * s,
			Palette.Coal,
			Enum.Material.Basalt
		)
		lump.Reflectance = 0.15
	end
	Kit.ball(model, at * CFrame.new(0, 4.4 * s, 0), Vector3.new(4.5, 1.2, 4) * s, Palette.Snow, SNOW)
	return node(model, "CoalSeam", main)
end

-- Buried junk: a snowdrift with metal poking out of it.
function Props.salvage(parent: Instance, at: CFrame, seed: number): Model
	local model = Kit.model(parent, "Salvage")
	local random = Kit.random(seed)
	local drift =
		Kit.solid(Kit.ball(model, at * CFrame.new(0, 0.8, 0), Vector3.new(8, 3.2, 7), Palette.SnowShade, SNOW))
	Kit.block(
		model,
		at * CFrame.new(-1.5, 2, 0.8) * CFrame.Angles(0.5, random.number(0, 3), 0.3),
		Vector3.new(3.4, 0.3, 2.2),
		Palette.Rust,
		Enum.Material.CorrodedMetal
	)
	Kit.log(
		model,
		at * CFrame.new(1.4, 2.1, -0.6) * CFrame.Angles(0, random.number(0, 3), 0.6),
		4,
		0.6,
		Palette.Metal,
		METAL
	)
	Kit.block(
		model,
		at * CFrame.new(0.6, 2.3, 1.6) * CFrame.Angles(0.2, 0.4, -0.5),
		Vector3.new(1.4, 1.4, 1.4),
		Palette.MetalDark,
		METAL
	)
	return node(model, "Salvage", drift)
end

-- A round hole cut in the lake ice, with a stool and a rod beside it.
function Props.fishingHole(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "FishingHole")
	local hole = Kit.new("Part", model, {
		Anchored = true,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 4.5, 4.5),
		CFrame = at * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(28, 70, 110),
		Material = Enum.Material.Glass,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	Kit.post(model, at * CFrame.new(0, 0.15, 0), 0.25, 5.6, Palette.Frost, ICE)
	Kit.post(model, at * CFrame.new(3.6, 0.9, 0), 1.8, 1.6, Palette.PlankDark, WOOD)
	Kit.span(model, at * Vector3.new(3.6, 2, 0.4), at * Vector3.new(0.6, 5, 0), 0.2, 0.2, Palette.PlankDark, WOOD)
	Kit.span(model, at * Vector3.new(0.6, 5, 0), at * Vector3.new(0.4, 0.4, 0), 0.06, 0.06, Palette.White)
	return node(model, "FishingHole", hole)
end

-- A frostberry bush: a dark green mound dotted with purple berries.
function Props.bush(parent: Instance, at: CFrame, seed: number): Model
	local model = Kit.model(parent, "BerryBush")
	local random = Kit.random(seed)
	local body = Kit.solid(
		Kit.ball(model, at * CFrame.new(0, 1.6, 0), Vector3.new(5, 3.4, 5), Palette.Leaf, Enum.Material.Grass)
	)
	Kit.ball(model, at * CFrame.new(0, 2.9, 0), Vector3.new(3.6, 1, 3.6), Palette.Snow, SNOW)
	local berries = Kit.model(model, "Berries")
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2 + random.number(0, 0.5)
		local y = random.number(1.2, 2.4)
		Kit.glow(
			berries,
			at * CFrame.new(math.cos(angle) * 2.3, y, math.sin(angle) * 2.3),
			Vector3.new(0.7, 0.7, 0.7),
			Palette.Berry,
			true
		)
	end
	return node(model, "BerryBush", body)
end

-- A supply crate dropped in the snow, banded with iron, with a flag so it
-- can be found.
function Props.crate(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "SupplyCrate")
	local box = Kit.solid(Kit.block(model, at * CFrame.new(0, 1.6, 0), Vector3.new(4, 3.2, 3), Palette.Plank, PLANKS))
	Kit.block(model, at * CFrame.new(0, 1.6, 0), Vector3.new(4.1, 0.4, 3.1), Palette.MetalDark, METAL)
	Kit.block(model, at * CFrame.new(0, 3.3, 0), Vector3.new(3.6, 0.3, 2.6), Palette.Snow, SNOW)
	Kit.post(model, at * CFrame.new(1.6, 5, 1.1), 4, 0.2, Palette.MetalDark)
	Kit.glow(model, at * CFrame.new(2.4, 6.4, 1.1), Vector3.new(1.6, 1, 0.1), Palette.Ember)
	box.Name = "Hit"
	model.PrimaryPart = box
	return model
end

-- A lamp post with a glowing bulb. Bulbs are neon, not lights, so a road
-- of them costs nothing at night.
function Props.lampPost(parent: Instance, at: CFrame, lit: boolean?): Model
	local model = Kit.model(parent, "LampPost")
	Kit.solid(Kit.post(model, at * CFrame.new(0, 4, 0), 8, 0.5, Palette.MetalDark, METAL))
	Kit.block(model, at * CFrame.new(0, 8.2, 0), Vector3.new(1.4, 0.3, 1.4), Palette.MetalDark, METAL)
	local bulb = Kit.glow(model, at * CFrame.new(0, 7.5, 0), Vector3.new(1, 1.1, 1), Palette.Warm, true)
	if lit then
		Kit.light(bulb, Palette.Warm, 22, 1.2)
	end
	return model
end

-- A wooden sign on a post, with words on both faces.
function Props.sign(parent: Instance, at: CFrame, text: string, width: number?): Model
	local model = Kit.model(parent, "Sign")
	local w = width or 8
	Kit.solid(Kit.post(model, at * CFrame.new(-w / 2 + 0.6, 2.5, 0), 5, 0.5, Palette.Bark, WOOD))
	Kit.solid(Kit.post(model, at * CFrame.new(w / 2 - 0.6, 2.5, 0), 5, 0.5, Palette.Bark, WOOD))
	local board = Kit.block(model, at * CFrame.new(0, 4.4, 0), Vector3.new(w, 2.2, 0.4), Palette.Plank, PLANKS)
	Kit.block(model, at * CFrame.new(0, 5.6, 0), Vector3.new(w + 0.2, 0.3, 0.6), Palette.Snow, SNOW)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Kit.new("SurfaceGui", board, { Face = face, PixelsPerStud = 40, LightInfluence = 0.4 })
		Kit.new("TextLabel", gui, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.fromRGB(58, 36, 22),
		})
	end
	return model
end

-- An arrow-shaped board for the signpost at the hearth, pointing along the
-- CFrame's -Z.
function Props.arrow(parent: Instance, at: CFrame, text: string)
	local board = Kit.block(parent, at, Vector3.new(0.3, 1.4, 7), Palette.Plank, PLANKS)
	Kit.wedge(
		parent,
		at * CFrame.new(0, 0, -4.2) * CFrame.Angles(0, 0, 0),
		Vector3.new(0.3, 1.4, 1.4),
		Palette.Plank,
		PLANKS
	)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Kit.new("SurfaceGui", board, { Face = face, PixelsPerStud = 40, LightInfluence = 0.4 })
		Kit.new("TextLabel", gui, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.fromRGB(58, 36, 22),
		})
	end
end

-- A house of the old town, half buried in snow, its door blocked and its
-- windows dark.
function Props.house(parent: Instance, at: CFrame, seed: number): Model
	local model = Kit.model(parent, "OldHouse")
	local random = Kit.random(seed)
	local roof = random.pick({ Palette.RoofRed, Palette.RoofTeal, Palette.RoofBlue })
	local wall = random.pick(Palette.Paint)
	local w, d, h = 16, 12, 9
	Kit.solid(Kit.block(model, at * CFrame.new(0, h / 2, 0), Vector3.new(w, h, d), wall, PLANKS))
	-- A gable roof from two slabs.
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(0, h + 2.2, side * d / 4 + side * 0.4) * CFrame.Angles(side * 0.62, 0, 0),
				Vector3.new(w + 1.4, 0.8, d / 2 + 2.6),
				roof,
				Enum.Material.Slate
			)
		)
		Kit.block(
			model,
			at * CFrame.new(0, h + 2.7, side * d / 4 + side * 0.4) * CFrame.Angles(side * 0.62, 0, 0),
			Vector3.new(w + 1.2, 0.5, d / 2 + 2),
			Palette.Snow,
			SNOW
		)
	end
	-- The gable ends.
	for side = -1, 1, 2 do
		Kit.wedge(
			model,
			at * CFrame.new(side * (w / 2 - 0.3), h + 1.6, d / 4) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(0.6, 3.2, d / 2),
			wall,
			PLANKS
		)
		Kit.wedge(
			model,
			at * CFrame.new(side * (w / 2 - 0.3), h + 1.6, -d / 4),
			Vector3.new(0.6, 3.2, d / 2),
			wall,
			PLANKS
		)
	end
	-- Dark windows and a door, on the front (-Z).
	Kit.block(
		model,
		at * CFrame.new(-4.5, 5, -d / 2 - 0.1),
		Vector3.new(3, 2.6, 0.2),
		Palette.MetalDark,
		Enum.Material.Glass
	)
	Kit.block(
		model,
		at * CFrame.new(4.5, 5, -d / 2 - 0.1),
		Vector3.new(3, 2.6, 0.2),
		Palette.MetalDark,
		Enum.Material.Glass
	)
	Kit.block(model, at * CFrame.new(0, 3.2, -d / 2 - 0.1), Vector3.new(3.2, 6.4, 0.2), Palette.PlankDark, WOOD)
	-- Drifts against the walls.
	Kit.solid(Kit.ball(model, at * CFrame.new(-3, 1.6, -d / 2 - 1.2), Vector3.new(10, 5, 5), Palette.Snow, SNOW))
	Kit.ball(model, at * CFrame.new(w / 2 + 1, 1.2, 2), Vector3.new(5, 4, 12), Palette.Snow, SNOW)
	-- A chimney.
	Kit.solid(
		Kit.block(
			model,
			at * CFrame.new(w / 2 - 3, h + 4.4, 2),
			Vector3.new(2, 4, 2),
			Palette.StoneDark,
			Enum.Material.Brick
		)
	)
	Kit.block(model, at * CFrame.new(w / 2 - 3, h + 6.5, 2), Vector3.new(2.3, 0.4, 2.3), Palette.Snow, SNOW)
	return model
end

-- A mountain peak at the edge of the valley: a rocky ridge with a snow cap.
function Props.peak(parent: Instance, at: CFrame, scale: number)
	local model = Kit.model(parent, "Peak")
	local s = scale
	local w, h, d = 70 * s, 90 * s, 50 * s
	Kit.wedge(model, at * CFrame.new(0, h / 2, -d / 2), Vector3.new(w, h, d), Palette.StoneDark, ROCK)
	Kit.wedge(
		model,
		at * CFrame.new(0, h / 2, d / 2) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(w, h, d),
		Palette.StoneDark,
		ROCK
	)
	local capH, capD = h * 0.35, d * 0.35
	Kit.wedge(
		model,
		at * CFrame.new(0, h - capH / 2 + 0.6, -capD / 2),
		Vector3.new(w + 0.4, capH, capD),
		Palette.Snow,
		SNOW
	)
	Kit.wedge(
		model,
		at * CFrame.new(0, h - capH / 2 + 0.6, capD / 2) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(w + 0.4, capH, capD),
		Palette.Snow,
		SNOW
	)
	return model
end

-- A soft drift of snow.
function Props.drift(parent: Instance, at: CFrame, size: Vector3): Part
	return Kit.ball(parent, at * CFrame.new(0, size.Y * 0.3, 0), size, Palette.Snow, SNOW)
end

return Props
