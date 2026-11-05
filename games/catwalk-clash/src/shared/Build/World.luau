--!strict
-- Builds the whole map from parts at server start: Glow Plaza (the lobby),
-- the Runway hall, Backstage, the Boutique, the VIP Lounge and the skyline
-- around them. Positions come from Config/Layout. Everything here is
-- original and made in code, so the place needs no uploaded models.
--
-- World.build returns the parts other scripts update: the screens, the
-- leaderboard, the Hall of Fame plinth and the VIP gate.

local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Parent.Config.Layout)

local make, part = Kit.make, Kit.part

local World = {}

-- The look of the place.
World.Colors = {
	Floor = Color3.fromRGB(246, 232, 244),
	FloorDark = Color3.fromRGB(44, 30, 66),
	Wall = Color3.fromRGB(58, 38, 86),
	WallLight = Color3.fromRGB(252, 236, 246),
	Pink = Color3.fromRGB(255, 70, 170),
	Aqua = Color3.fromRGB(70, 230, 240),
	Gold = Color3.fromRGB(255, 205, 90),
	Violet = Color3.fromRGB(160, 100, 255),
	Runway = Color3.fromRGB(18, 16, 26),
	Glass = Color3.fromRGB(190, 230, 255),
	Velvet = Color3.fromRGB(150, 20, 70),
	Cream = Color3.fromRGB(255, 244, 228),
}
local C = World.Colors

local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic
local MARBLE = Enum.Material.Marble
local GLASS = Enum.Material.Glass
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

export type Refs = {
	Root: Folder,
	PlazaScreen: SurfaceGui,
	StageScreen: SurfaceGui,
	BackstageScreen: SurfaceGui,
	Leaderboard: SurfaceGui,
	HallOfFame: SurfaceGui,
	Statue: Model,
	VipGate: BasePart,
	Fans: Folder,
	Prompts: { [string]: ProximityPrompt },
	StageLights: Folder,
	LaneLights: { A: { BasePart }, B: { BasePart } },
}

-- An upright disc (a cylinder standing on its end).
local function disc(
	parent: Instance,
	centre: Vector3,
	radius: number,
	height: number,
	props: { [string]: any }
): BasePart
	local values = {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(centre) * UPRIGHT,
	}
	for key, value in props do
		values[key] = value
	end
	return part(parent, values)
end

local function ball(parent: Instance, centre: Vector3, diameter: number, props: { [string]: any }): BasePart
	local values = {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Position = centre,
		CanCollide = false,
	}
	for key, value in props do
		values[key] = value
	end
	return part(parent, values)
end

-- A row of glowing bulbs hanging between two points.
local function stringLights(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	count: number,
	sag: number,
	colors: { Color3 }
)
	for index = 0, count do
		local alpha = index / count
		local position = from:Lerp(to, alpha) - Vector3.new(0, math.sin(alpha * math.pi) * sag, 0)
		ball(parent, position, 0.5, {
			Color = colors[index % #colors + 1],
			Material = NEON,
			CastShadow = false,
		})
	end
end

-- A screen made of a SurfaceGui with named labels for the clients to fill.
local function screen(parent: Instance, cframe: CFrame, size: Vector3, name: string): SurfaceGui
	local board = part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(12, 10, 20),
		Material = SMOOTH,
		CanCollide = false,
	})
	-- A glowing frame round the screen.
	local frame = size + Vector3.new(0.8, 0.8, -0.2)
	part(parent, {
		Name = `{name}Frame`,
		Size = Vector3.new(frame.X, frame.Y, math.max(0.2, size.Z - 0.2)),
		CFrame = cframe * CFrame.new(0, 0, 0.15),
		Color = C.Pink,
		Material = NEON,
		CanCollide = false,
	})
	local gui = make("SurfaceGui", {
		Name = "Screen",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 24,
		LightInfluence = 0,
		Brightness = 1.6,
	}, board)
	local background = make("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(28, 14, 46),
	}, gui)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(70, 20, 90), Color3.fromRGB(14, 10, 34)),
		Rotation = 90,
	}, background)
	local function label(labelName: string, y: number, height: number, text: string, color: Color3)
		local item = make("TextLabel", {
			Name = labelName,
			Position = UDim2.fromScale(0.05, y),
			Size = UDim2.fromScale(0.9, height),
			BackgroundTransparency = 1,
			Text = text,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			TextColor3 = color,
		}, background)
		make("UIStroke", { Color = Color3.fromRGB(20, 0, 30), Thickness = 2 }, item)
		return item
	end
	label("Top", 0.06, 0.18, "CATWALK CLASH", C.Gold)
	label("Main", 0.28, 0.36, "Next show soon", Color3.new(1, 1, 1))
	label("Sub", 0.68, 0.2, "", C.Aqua)
	return gui
end

-- A tree of glowing balls on a pole, for the plaza.
local function lightTree(parent: Instance, base: Vector3, color: Color3)
	disc(parent, base + Vector3.new(0, 0.5, 0), 1.6, 1, { Color = C.FloorDark, Material = MARBLE })
	part(parent, {
		Size = Vector3.new(0.5, 9, 0.5),
		Position = base + Vector3.new(0, 5, 0),
		Color = C.Gold,
		Material = METAL,
	})
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		local offset = Vector3.new(math.sin(angle) * 1.8, 9 + (index % 2) * 1.2, math.cos(angle) * 1.8)
		ball(parent, base + offset, 1.6, { Color = color, Material = NEON, CastShadow = false })
	end
	local top =
		ball(parent, base + Vector3.new(0, 11, 0), 2.2, { Color = C.Cream, Material = NEON, CastShadow = false })
	make("PointLight", { Color = color, Range = 18, Brightness = 1.2, Shadows = false }, top)
end

-- A bench with a velvet seat.
local function bench(parent: Instance, cframe: CFrame)
	part(
		parent,
		{ Size = Vector3.new(6, 1, 2.4), CFrame = cframe * CFrame.new(0, 1.2, 0), Color = C.Velvet, Material = FABRIC }
	)
	part(
		parent,
		{ Size = Vector3.new(6, 2.4, 0.6), CFrame = cframe * CFrame.new(0, 2.3, 1), Color = C.Velvet, Material = FABRIC }
	)
	part(
		parent,
		{ Size = Vector3.new(6.2, 0.7, 2.6), CFrame = cframe * CFrame.new(0, 0.35, 0), Color = C.Gold, Material = METAL }
	)
end

-- A dressmaker's dummy on a stand.
local function mannequin(parent: Instance, cframe: CFrame, dress: Color3, trim: Color3)
	part(
		parent,
		{ Size = Vector3.new(0.3, 3, 0.3), CFrame = cframe * CFrame.new(0, 1.5, 0), Color = C.Gold, Material = METAL }
	)
	disc(parent, (cframe * CFrame.new(0, 0.15, 0)).Position, 1, 0.3, { Color = C.Gold, Material = METAL })
	local body = part(parent, {
		Size = Vector3.new(1.8, 2.2, 1.1),
		CFrame = cframe * CFrame.new(0, 4.4, 0),
		Color = dress,
		Material = FABRIC,
	})
	make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, body)
	local skirt = part(parent, {
		Size = Vector3.new(3, 2.6, 3),
		CFrame = cframe * CFrame.new(0, 3, 0),
		Color = dress,
		Material = FABRIC,
		CanCollide = false,
	})
	make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, skirt)
	disc(
		parent,
		(cframe * CFrame.new(0, 3.3, 0)).Position,
		0.95,
		0.2,
		{ Color = trim, Material = NEON, CanCollide = false }
	)
	ball(parent, (cframe * CFrame.new(0, 5.8, 0)).Position, 0.6, { Color = C.Cream, Material = SMOOTH })
end

-- A rack of hanging clothes.
local function rack(parent: Instance, cframe: CFrame, colors: { Color3 })
	part(
		parent,
		{ Size = Vector3.new(0.3, 5, 0.3), CFrame = cframe * CFrame.new(-3, 2.5, 0), Color = C.Gold, Material = METAL }
	)
	part(
		parent,
		{ Size = Vector3.new(0.3, 5, 0.3), CFrame = cframe * CFrame.new(3, 2.5, 0), Color = C.Gold, Material = METAL }
	)
	part(
		parent,
		{ Size = Vector3.new(6.4, 0.25, 0.25), CFrame = cframe * CFrame.new(0, 5, 0), Color = C.Gold, Material = METAL }
	)
	for index = 0, 6 do
		local x = -2.4 + index * 0.8
		part(parent, {
			Size = Vector3.new(0.2, 2.6, 1.3),
			CFrame = cframe * CFrame.new(x, 3.5, 0),
			Color = colors[index % #colors + 1],
			Material = FABRIC,
			CanCollide = false,
		})
	end
end

-- A walled hall with an open archway in one end wall.
local function hall(
	parent: Instance,
	bounds: { MinX: number, MaxX: number, MinZ: number, MaxZ: number, Height: number },
	doorZ: number,
	doorWidth: number,
	doorHeight: number,
	wall: Color3
)
	local width = bounds.MaxX - bounds.MinX
	local depth = bounds.MaxZ - bounds.MinZ
	local centreX = (bounds.MinX + bounds.MaxX) / 2
	local centreZ = (bounds.MinZ + bounds.MaxZ) / 2
	local h = bounds.Height
	local function wallPart(size: Vector3, position: Vector3)
		part(parent, { Name = "Wall", Size = size, Position = position, Color = wall, Material = SMOOTH })
	end
	wallPart(Vector3.new(1, h, depth), Vector3.new(bounds.MinX, h / 2, centreZ))
	wallPart(Vector3.new(1, h, depth), Vector3.new(bounds.MaxX, h / 2, centreZ))
	local otherZ = if doorZ == bounds.MinZ then bounds.MaxZ else bounds.MinZ
	wallPart(Vector3.new(width, h, 1), Vector3.new(centreX, h / 2, otherZ))
	local side = (width - doorWidth) / 2
	wallPart(Vector3.new(side, h, 1), Vector3.new(bounds.MinX + side / 2, h / 2, doorZ))
	wallPart(Vector3.new(side, h, 1), Vector3.new(bounds.MaxX - side / 2, h / 2, doorZ))
	wallPart(Vector3.new(doorWidth, h - doorHeight, 1), Vector3.new(centreX, doorHeight + (h - doorHeight) / 2, doorZ))
	part(parent, {
		Name = "Roof",
		Size = Vector3.new(width + 2, 1, depth + 2),
		Position = Vector3.new(centreX, h + 0.5, centreZ),
		Color = wall,
		Material = SMOOTH,
	})
	-- A neon line round the archway.
	local facing = if doorZ > centreZ then 0.6 else -0.6
	part(parent, {
		Size = Vector3.new(doorWidth + 1.2, 0.6, 0.4),
		Position = Vector3.new(centreX, doorHeight + 0.3, doorZ + facing),
		Color = C.Pink,
		Material = NEON,
		CanCollide = false,
	})
	for _, x in { centreX - doorWidth / 2 - 0.3, centreX + doorWidth / 2 + 0.3 } do
		part(parent, {
			Size = Vector3.new(0.6, doorHeight, 0.4),
			Position = Vector3.new(x, doorHeight / 2, doorZ + facing),
			Color = C.Pink,
			Material = NEON,
			CanCollide = false,
		})
	end
end

local function prompt(parent: BasePart, action: string, objectText: string): ProximityPrompt
	return make("ProximityPrompt", {
		ActionText = action,
		ObjectText = objectText,
		HoldDuration = 0,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
	}, parent)
end

-- A kiosk: a glowing pillar with a sign and a prompt.
local function kiosk(parent: Instance, cframe: CFrame, title: string, action: string, color: Color3): ProximityPrompt
	disc(parent, (cframe * CFrame.new(0, 0.3, 0)).Position, 3.4, 0.6, { Color = C.FloorDark, Material = MARBLE })
	local pillar = part(parent, {
		Name = title,
		Size = Vector3.new(3, 7, 1.6),
		CFrame = cframe * CFrame.new(0, 4, 0),
		Color = C.Wall,
		Material = SMOOTH,
	})
	part(parent, {
		Size = Vector3.new(3.2, 0.3, 1.8),
		CFrame = cframe * CFrame.new(0, 7.6, 0),
		Color = color,
		Material = NEON,
		CanCollide = false,
	})
	Kit.sign(parent, cframe * CFrame.new(0, 9.6, 0), Vector3.new(7, 2.4, 0.4), title, {
		Back = C.Wall,
		Text = color,
		Stroke = Color3.fromRGB(20, 0, 30),
	})
	return prompt(pillar, action, title)
end

local function buildPlaza(root: Instance, refs: Refs)
	local plaza = Kit.folder("Plaza", root)
	-- The ground, the plaza floor and its glowing rim.
	part(plaza, {
		Name = "Ground",
		Size = Vector3.new(420, 1, 420),
		Position = Vector3.new(0, -0.5, -10),
		Color = Color3.fromRGB(70, 50, 100),
		Material = SMOOTH,
	})
	disc(plaza, Vector3.new(0, 0.05, 0), Layout.PlazaRadius + 1.2, 0.2, { Color = C.Pink, Material = NEON })
	disc(plaza, Vector3.new(0, 0.15, 0), Layout.PlazaRadius, 0.3, {
		Color = C.Floor,
		Material = MARBLE,
		Reflectance = 0.08,
	})
	-- Paths to the runway and backstage, and to the side kiosks.
	part(plaza, {
		Name = "RedCarpet",
		Size = Vector3.new(14, 0.34, 26),
		Position = Vector3.new(0, 0.17, -58),
		Color = C.Velvet,
		Material = FABRIC,
	})
	part(plaza, {
		Size = Vector3.new(14, 0.34, 26),
		Position = Vector3.new(0, 0.17, 58),
		Color = C.FloorDark,
		Material = MARBLE,
	})
	for _, x in { -7.4, 7.4 } do
		part(plaza, {
			Size = Vector3.new(0.6, 0.4, 26),
			Position = Vector3.new(x, 0.2, -58),
			Color = C.Gold,
			Material = NEON,
			CanCollide = false,
		})
	end

	-- The fountain in the middle.
	local fountain = Kit.folder("Fountain", plaza)
	disc(fountain, Vector3.new(0, 0.9, 0), 12, 1.6, { Color = C.Cream, Material = MARBLE })
	disc(fountain, Vector3.new(0, 1.55, 0), 11, 0.4, { Color = C.Aqua, Material = GLASS, Transparency = 0.35 })
	disc(fountain, Vector3.new(0, 1.8, 0), 12.3, 0.3, { Color = C.Gold, Material = NEON, CanCollide = false })
	disc(fountain, Vector3.new(0, 3.4, 0), 3, 4, { Color = C.Cream, Material = MARBLE })
	disc(fountain, Vector3.new(0, 5.6, 0), 6, 0.6, { Color = C.Cream, Material = MARBLE })
	disc(fountain, Vector3.new(0, 5.95, 0), 5.4, 0.2, { Color = C.Aqua, Material = GLASS, Transparency = 0.3 })
	disc(fountain, Vector3.new(0, 7.6, 0), 1.2, 3.4, { Color = C.Gold, Material = METAL })
	local star = ball(fountain, Vector3.new(0, 10.6, 0), 3, { Color = C.Gold, Material = NEON })
	make("PointLight", { Color = C.Gold, Range = 26, Brightness = 1.5, Shadows = false }, star)
	local spray = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(C.Aqua, Color3.new(1, 1, 1)),
		Rate = 30,
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(6, 9),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -12, 0),
		LightEmission = 0.8,
		Size = NumberSequence.new(0.4),
	}, star)
	spray.Name = "Spray"

	-- Spawns round the fountain.
	for index, cframe in Layout.Spawns do
		local pad = part(plaza, {
			ClassName = "SpawnLocation",
			Name = `Spawn{index}`,
			Size = Vector3.new(8, 0.4, 8),
			CFrame = cframe * CFrame.new(0, -0.3, 0),
			Color = C.Pink,
			Material = NEON,
			Transparency = 0.4,
			CanCollide = true,
		}) :: SpawnLocation
		pad.Neutral = true
		pad.Duration = 0
		local decal = pad:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end

	-- Light trees, benches and string lights round the edge.
	local colors = { C.Pink, C.Aqua, C.Violet, C.Gold }
	for index = 0, 7 do
		local angle = math.rad(22.5 + index * 45)
		local base = Vector3.new(math.sin(angle) * 42, 0.3, math.cos(angle) * 42)
		lightTree(plaza, base, colors[index % 4 + 1])
		local benchAngle = angle + math.rad(22.5)
		local benchAt = Vector3.new(math.sin(benchAngle) * 38, 0.3, math.cos(benchAngle) * 38)
		if math.abs(benchAt.X) > 10 then
			bench(plaza, CFrame.lookAt(benchAt, Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(180), 0))
		end
	end
	for index = 0, 7 do
		local a = math.rad(22.5 + index * 45)
		local b = math.rad(22.5 + (index + 1) * 45)
		stringLights(
			plaza,
			Vector3.new(math.sin(a) * 42, 11, math.cos(a) * 42),
			Vector3.new(math.sin(b) * 42, 11, math.cos(b) * 42),
			8,
			2.5,
			colors
		)
	end

	-- The Hall of Fame plinth, where last show's winner stands as a statue.
	local fame = Kit.folder("HallOfFame", plaza)
	local base = Layout.HallOfFame.Position - Vector3.new(0, 4.9, 0)
	disc(fame, base + Vector3.new(0, 0.6, 0), 5, 1.2, { Color = C.FloorDark, Material = MARBLE })
	disc(fame, base + Vector3.new(0, 1.5, 0), 3.6, 0.6, { Color = C.Gold, Material = METAL })
	disc(fame, base + Vector3.new(0, 1.85, 0), 3.7, 0.15, { Color = C.Gold, Material = NEON, CanCollide = false })
	local plaque = part(fame, {
		Name = "Plaque",
		Size = Vector3.new(8, 2.4, 0.4),
		CFrame = Layout.HallOfFame * CFrame.new(0, -3.4, -5.4) * CFrame.Angles(math.rad(15), 0, 0),
		Color = C.Wall,
		Material = SMOOTH,
	})
	local fameGui = make("SurfaceGui", {
		Name = "Plaque",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
	}, plaque)
	make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.45),
		BackgroundTransparency = 1,
		Text = "LAST SHOW'S STAR",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.Gold,
	}, fameGui)
	make("TextLabel", {
		Name = "Name",
		Position = UDim2.fromScale(0, 0.45),
		Size = UDim2.fromScale(1, 0.55),
		BackgroundTransparency = 1,
		Text = "Could be you!",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
	}, fameGui)
	refs.HallOfFame = fameGui
	Kit.spot(fame, CFrame.lookAt(base + Vector3.new(0, 20, 6), base + Vector3.new(0, 4, 0)), C.Gold, 26, 30, 4)
	refs.Statue = Kit.model("Statue", fame)

	-- The skyline behind everything: towers with glowing windows.
	local sky = Kit.folder("Skyline", root)
	for index = 0, 15 do
		local angle = math.rad(index * 22.5 + 8)
		local distance = 185 + (index % 3) * 18
		local height = 50 + ((index * 37) % 60)
		local width = 22 + (index % 4) * 6
		local position = Vector3.new(math.sin(angle) * distance, height / 2, math.cos(angle) * distance - 10)
		local tower = part(sky, {
			Size = Vector3.new(width, height, width),
			CFrame = CFrame.lookAt(position, Vector3.new(0, height / 2, -10)),
			Color = Color3.fromRGB(34, 26, 56),
			Material = SMOOTH,
			CanCollide = false,
		})
		local stripeColor = colors[index % 4 + 1]
		for stripe = 1, 3 do
			part(sky, {
				Size = Vector3.new(width + 0.4, 0.8, width + 0.4),
				CFrame = tower.CFrame * CFrame.new(0, -height / 2 + stripe * height / 4, 0),
				Color = stripeColor,
				Material = NEON,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
end

local function buildRunway(root: Instance, refs: Refs)
	local hallFolder = Kit.folder("Runway", root)
	local bounds = Layout.Hall
	local stage = Layout.Stage
	hall(hallFolder, bounds, bounds.MaxZ, 34, 20, C.Wall)
	part(hallFolder, {
		Name = "HallFloor",
		Size = Vector3.new(bounds.MaxX - bounds.MinX, 0.4, bounds.MaxZ - bounds.MinZ),
		Position = Vector3.new(0, 0.2, (bounds.MinZ + bounds.MaxZ) / 2),
		Color = C.FloorDark,
		Material = MARBLE,
		Reflectance = 0.12,
	})
	-- The sign over the archway, seen from the plaza.
	Kit.sign(
		hallFolder,
		CFrame.new(0, 23, bounds.MaxZ + 0.7) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(30, 5, 0.4),
		"THE RUNWAY",
		{ Back = C.Wall, Text = C.Gold, Stroke = C.Velvet }
	)
	refs.PlazaScreen = screen(
		hallFolder,
		CFrame.new(0, 27.5, bounds.MaxZ + 0.8) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(26, 7, 0.4),
		"PlazaScreen"
	)

	-- The stage: the runway with two lanes and the T at the end.
	local laneLength = stage.EndZ - stage.StartZ
	local runwayLength = stage.TStartZ - (stage.StartZ - 10)
	local runwayCentreZ = (stage.TStartZ + stage.StartZ - 10) / 2
	part(hallFolder, {
		Name = "Runway",
		Size = Vector3.new(stage.Width, stage.Top, runwayLength),
		Position = Vector3.new(0, stage.Top / 2, runwayCentreZ),
		Color = C.Runway,
		Material = SMOOTH,
		Reflectance = 0.3,
	})
	part(hallFolder, {
		Name = "RunwayT",
		Size = Vector3.new(stage.Width + 10, stage.Top, stage.TEndZ - stage.TStartZ),
		Position = Vector3.new(0, stage.Top / 2, (stage.TStartZ + stage.TEndZ) / 2),
		Color = C.Runway,
		Material = SMOOTH,
		Reflectance = 0.3,
	})
	-- Lane edges light up while each walker strides (client/Show).
	refs.LaneLights = { A = {}, B = {} }
	for side, x in { A = -stage.LaneX, B = stage.LaneX } do
		local laneColor = if side == "A" then C.Pink else C.Aqua
		for _, offset in { -3.6, 3.6 } do
			local strip = part(hallFolder, {
				Name = `Lane{side}`,
				Size = Vector3.new(0.4, 0.12, laneLength + 6),
				Position = Vector3.new(x + offset, stage.Top + 0.06, (stage.StartZ + stage.EndZ) / 2),
				Color = laneColor,
				Material = NEON,
				CanCollide = false,
				CastShadow = false,
			})
			table.insert(refs.LaneLights[side :: "A" | "B"], strip)
		end
		-- The glowing circle where each walker poses.
		local poseAt = (Layout.Lanes :: any)[side].Pose.Position
		disc(hallFolder, Vector3.new(poseAt.X, stage.Top + 0.04, poseAt.Z), 2.6, 0.08, {
			Color = laneColor,
			Material = NEON,
			CanCollide = false,
			Transparency = 0.2,
		})
	end
	-- Steps from the hall floor up to each end of the T, for practice walks.
	for _, sideSign in { -1, 1 } do
		for step = 1, 3 do
			part(hallFolder, {
				Name = "Step",
				Size = Vector3.new(1.4, step, 6),
				Position = Vector3.new(sideSign * (18 + 4.2 - step * 1.4 + 0.7), step / 2, -95),
				Color = C.Runway,
				Material = SMOOTH,
			})
		end
	end
	-- The podium on the T.
	for place, x in { First = 0, Second = -5.5, Third = 5.5 } do
		local height = (Layout.Podium.Heights :: any)[place]
		part(hallFolder, {
			Name = `Podium{place}`,
			Size = Vector3.new(4.6, height, 4.6),
			Position = Vector3.new(x, stage.Top + height / 2, -95),
			Color = if place == "First"
				then C.Gold
				else if place == "Second" then Color3.fromRGB(210, 214, 230) else Color3.fromRGB(220, 150, 100),
			Material = METAL,
			Reflectance = 0.2,
		})
	end

	-- The stage door at the north end: two glowing curtained doorways.
	local doorZ = stage.StartZ - 6
	part(hallFolder, {
		Name = "Backdrop",
		Size = Vector3.new(stage.Width + 16, 26, 1),
		Position = Vector3.new(0, stage.Top + 13, doorZ - 0.6),
		Color = Color3.fromRGB(26, 16, 40),
		Material = SMOOTH,
	})
	for side, x in { A = -stage.LaneX, B = stage.LaneX } do
		local laneColor = if side == "A" then C.Pink else C.Aqua
		part(hallFolder, {
			Name = `Curtain{side}`,
			Size = Vector3.new(6, 9, 0.3),
			Position = Vector3.new(x, stage.Top + 4.5, doorZ),
			Color = C.Velvet,
			Material = FABRIC,
			CanCollide = false,
			Transparency = 0.15,
		})
		part(hallFolder, {
			Size = Vector3.new(7, 0.6, 0.6),
			Position = Vector3.new(x, stage.Top + 9.3, doorZ + 0.2),
			Color = laneColor,
			Material = NEON,
			CanCollide = false,
		})
		for _, edge in { -3.3, 3.3 } do
			part(hallFolder, {
				Size = Vector3.new(0.6, 9.6, 0.6),
				Position = Vector3.new(x + edge, stage.Top + 4.8, doorZ + 0.2),
				Color = laneColor,
				Material = NEON,
				CanCollide = false,
			})
		end
	end
	refs.StageScreen = screen(
		hallFolder,
		CFrame.new(0, stage.Top + 18, doorZ + 0.4) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(30, 12, 0.4),
		"StageScreen"
	)

	-- Lights over the runway, recoloured to each theme by the clients.
	local lights = Kit.folder("StageLights", hallFolder)
	refs.StageLights = lights
	part(hallFolder, {
		Name = "Truss",
		Size = Vector3.new(1, 1, laneLength + 20),
		Position = Vector3.new(-11, 22, (stage.StartZ + stage.EndZ) / 2),
		Color = Color3.fromRGB(80, 80, 96),
		Material = METAL,
		CanCollide = false,
	})
	part(hallFolder, {
		Name = "Truss",
		Size = Vector3.new(1, 1, laneLength + 20),
		Position = Vector3.new(11, 22, (stage.StartZ + stage.EndZ) / 2),
		Color = Color3.fromRGB(80, 80, 96),
		Material = METAL,
		CanCollide = false,
	})
	for z = stage.StartZ + 6, stage.EndZ, 14 do
		for _, x in { -11, 11 } do
			local target = Vector3.new(if x < 0 then stage.LaneX else -stage.LaneX, stage.Top, z + 4)
			Kit.spot(lights, CFrame.lookAt(Vector3.new(x, 21, z), target), C.Pink, 40, 35, 3)
		end
	end
	Kit.spot(
		lights,
		CFrame.lookAt(Vector3.new(0, 24, -82), Vector3.new(0, stage.Top, -100)),
		Color3.new(1, 1, 1),
		50,
		30,
		4
	)

	-- Audience tiers on both sides, with velvet rails.
	for _, sideSign in { -1, 1 } do
		for tier = 1, 3 do
			local x = sideSign * (15 + tier * 5)
			part(hallFolder, {
				Name = "Tier",
				Size = Vector3.new(5, tier * 1.5, 48),
				Position = Vector3.new(x, tier * 0.75, -130),
				Color = if tier % 2 == 0 then C.Wall else Color3.fromRGB(70, 46, 104),
				Material = FABRIC,
			})
			part(hallFolder, {
				Size = Vector3.new(0.3, 0.2, 48),
				Position = Vector3.new(x - sideSign * 2.5, tier * 1.5 + 0.1, -130),
				Color = C.Gold,
				Material = NEON,
				CanCollide = false,
			})
		end
		-- A rail between the runway and the first tier.
		part(hallFolder, {
			Size = Vector3.new(0.4, 3, 56),
			Position = Vector3.new(sideSign * 14.2, 1.5, -130),
			Color = C.Gold,
			Material = METAL,
		})
	end

	-- Cheering fans on the back rows (they bob on the clients).
	local fans = Kit.folder("Fans", hallFolder)
	refs.Fans = fans
	local shirtColors =
		{ C.Pink, C.Aqua, C.Violet, C.Gold, Color3.fromRGB(255, 120, 90), Color3.fromRGB(120, 230, 140) }
	local skins = {
		Color3.fromRGB(255, 220, 190),
		Color3.fromRGB(214, 160, 112),
		Color3.fromRGB(150, 98, 64),
		Color3.fromRGB(96, 62, 42),
	}
	local count = 0
	for _, sideSign in { -1, 1 } do
		for z = -152, -108, 4 do
			count += 1
			local x = sideSign * 34.5
			local fan = Kit.model("Fan", fans)
			local base = CFrame.lookAt(Vector3.new(x, 4.5, z), Vector3.new(0, 4.5, z))
			part(fan, {
				Name = "Body",
				Size = Vector3.new(1.8, 2.2, 1),
				CFrame = base * CFrame.new(0, 1.1, 0),
				Color = shirtColors[count % #shirtColors + 1],
				Material = FABRIC,
				CanCollide = false,
			})
			ball(
				fan,
				(base * CFrame.new(0, 2.9, 0)).Position,
				1.3,
				{ Name = "Head", Color = skins[count % #skins + 1], Material = SMOOTH }
			)
			local stick = part(fan, {
				Name = "Glowstick",
				Size = Vector3.new(0.3, 1.6, 0.3),
				CFrame = base
					* CFrame.new(if count % 2 == 0 then 1.1 else -1.1, 3, -0.2)
					* CFrame.Angles(0, 0, math.rad(if count % 2 == 0 then -20 else 20)),
				Color = shirtColors[(count + 2) % #shirtColors + 1],
				Material = NEON,
				CanCollide = false,
				CastShadow = false,
			})
			stick:SetAttribute("Sway", count % 3)
			fan.PrimaryPart = fan:FindFirstChild("Body") :: BasePart
		end
	end
	part(hallFolder, {
		Name = "FanRiser",
		Size = Vector3.new(6, 4.5, 48),
		Position = Vector3.new(-34.5, 2.25, -130),
		Color = C.Wall,
		Material = FABRIC,
	})
	part(hallFolder, {
		Name = "FanRiser",
		Size = Vector3.new(6, 4.5, 48),
		Position = Vector3.new(34.5, 2.25, -130),
		Color = C.Wall,
		Material = FABRIC,
	})

	-- The judges' table, and the judges themselves (named by client/Show).
	part(hallFolder, {
		Name = "JudgesTable",
		Size = Vector3.new(24, 3, 3),
		Position = Vector3.new(0, 1.5, -87),
		Color = C.Wall,
		Material = SMOOTH,
	})
	part(hallFolder, {
		Size = Vector3.new(24.4, 0.4, 3.4),
		Position = Vector3.new(0, 3.2, -87),
		Color = C.Gold,
		Material = METAL,
	})
	part(hallFolder, {
		Size = Vector3.new(24.2, 0.5, 0.2),
		Position = Vector3.new(0, 2.2, -88.6),
		Color = C.Pink,
		Material = NEON,
		CanCollide = false,
	})
	local judgeColors = { C.Velvet, Color3.fromRGB(40, 200, 220), Color3.fromRGB(240, 170, 200) }
	local judgeHair = { Color3.fromRGB(20, 20, 30), Color3.fromRGB(255, 80, 200), Color3.fromRGB(235, 235, 240) }
	for index, seat in Layout.Judges do
		local judge = Kit.model(`Judge{index}`, hallFolder)
		part(
			judge,
			{
				Name = "Chair",
				Size = Vector3.new(3, 5, 1),
				CFrame = seat * CFrame.new(0, 2.5, 1.4),
				Color = C.Gold,
				Material = METAL,
			}
		)
		part(
			judge,
			{
				Name = "Body",
				Size = Vector3.new(2, 2.4, 1.2),
				CFrame = seat * CFrame.new(0, 3.2, 0.4),
				Color = judgeColors[index],
				Material = FABRIC,
			}
		)
		local head = ball(
			judge,
			(seat * CFrame.new(0, 5.1, 0.4)).Position,
			1.5,
			{ Name = "Head", Color = skins[index + 1], Material = SMOOTH }
		)
		local hair = part(judge, {
			Name = "Hair",
			Size = Vector3.new(1.7, 1.1, 1.7),
			CFrame = seat * CFrame.new(0, 5.6, 0.55),
			Color = judgeHair[index],
			Material = SMOOTH,
			CanCollide = false,
		})
		make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, hair)
		make("BillboardGui", {
			Name = "Tag",
			Size = UDim2.fromOffset(160, 40),
			StudsOffset = Vector3.new(0, 1.8, 0),
			AlwaysOnTop = false,
			MaxDistance = 80,
		}, head)
		judge.PrimaryPart = head
		part(judge, {
			Name = "Card",
			Size = Vector3.new(3, 1.2, 0.2),
			CFrame = seat * CFrame.new(0, 3.9, -2.6) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = C.Cream,
			Material = SMOOTH,
			CanCollide = false,
		})
	end

	-- Ceiling glitter balls.
	for _, z in { -150, -128, -106 } do
		local glitter = ball(
			hallFolder,
			Vector3.new(0, 27, z),
			4,
			{ Color = Color3.fromRGB(230, 230, 245), Material = Enum.Material.Foil, Reflectance = 0.5 }
		)
		glitter.Name = "GlitterBall"
		make("PointLight", { Color = C.Violet, Range = 30, Brightness = 1, Shadows = false }, glitter)
	end
end

local function buildBackstage(root: Instance, refs: Refs)
	local folder = Kit.folder("Backstage", root)
	local bounds = Layout.Backstage
	hall(folder, bounds, bounds.MinZ, 26, 16, Color3.fromRGB(250, 228, 240))
	part(folder, {
		Name = "BackstageFloor",
		Size = Vector3.new(bounds.MaxX - bounds.MinX, 0.4, bounds.MaxZ - bounds.MinZ),
		Position = Vector3.new(0, 0.2, (bounds.MinZ + bounds.MaxZ) / 2),
		Color = Color3.fromRGB(255, 214, 232),
		Material = MARBLE,
		Reflectance = 0.1,
	})
	Kit.sign(
		folder,
		CFrame.new(0, 19, bounds.MinZ - 0.7),
		Vector3.new(26, 4.4, 0.4),
		"BACKSTAGE",
		{ Back = C.Pink, Text = Color3.new(1, 1, 1), Stroke = C.Velvet }
	)
	refs.BackstageScreen =
		screen(folder, CFrame.new(0, 15, bounds.MaxZ - 0.8), Vector3.new(24, 8, 0.4), "BackstageScreen")

	-- The dressing booths: a glowing mirror, a rug and vanity bulbs each.
	for index, booth in Layout.Booths do
		local base = booth * CFrame.new(0, -3, 0)
		local wallAt = base * CFrame.new(0, 0, 6.5)
		disc(folder, (base * CFrame.new(0, 0.45, 0)).Position, 3, 0.1, {
			Color = if index % 2 == 0 then C.Aqua else C.Pink,
			Material = NEON,
			CanCollide = false,
			Transparency = 0.3,
		})
		part(folder, {
			Name = "Mirror",
			Size = Vector3.new(5, 8, 0.2),
			CFrame = wallAt * CFrame.new(0, 5, 0),
			Color = C.Glass,
			Material = GLASS,
			Reflectance = 0.6,
			Transparency = 0.1,
			CanCollide = false,
		})
		part(folder, {
			Size = Vector3.new(5.6, 8.6, 0.3),
			CFrame = wallAt * CFrame.new(0, 5, 0.15),
			Color = C.Gold,
			Material = METAL,
		})
		for bulb = 0, 4 do
			ball(folder, (wallAt * CFrame.new(-2.2 + bulb * 1.1, 9.6, -0.3)).Position, 0.45, {
				Color = C.Cream,
				Material = NEON,
				CastShadow = false,
			})
		end
		part(folder, {
			Name = "Vanity",
			Size = Vector3.new(5, 0.5, 1.6),
			CFrame = wallAt * CFrame.new(0, 3, -0.9),
			Color = Color3.new(1, 1, 1),
			Material = MARBLE,
		})
		local lamp = part(folder, {
			Size = Vector3.new(0.4, 0.4, 0.4),
			CFrame = wallAt * CFrame.new(0, 10.5, -1),
			Transparency = 1,
			CanCollide = false,
		})
		make("PointLight", { Color = C.Cream, Range = 12, Brightness = 1.2, Shadows = false }, lamp)
	end

	-- Racks, mannequins and sofas down the middle.
	local palette = {
		{ C.Pink, C.Gold, C.Violet },
		{ C.Aqua, Color3.new(1, 1, 1), C.Pink },
		{ C.Gold, C.Velvet, C.Cream },
	}
	for index, z in { 88, 108, 128 } do
		rack(folder, CFrame.new(-10, 0.4, z), palette[index])
		rack(folder, CFrame.new(10, 0.4, z) * CFrame.Angles(0, math.rad(180), 0), palette[(index % 3) + 1])
	end
	mannequin(folder, CFrame.new(0, 0.4, 92), C.Velvet, C.Gold)
	mannequin(folder, CFrame.new(-4, 0.4, 118), C.Aqua, C.Pink)
	mannequin(folder, CFrame.new(4, 0.4, 118), C.Gold, C.Violet)
	bench(folder, CFrame.new(0, 0.4, 104))
	bench(folder, CFrame.new(0, 0.4, 136) * CFrame.Angles(0, math.rad(180), 0))
	for _, z in { 90, 115, 140 } do
		local lamp = ball(folder, Vector3.new(0, 21, z), 2.4, { Color = C.Cream, Material = NEON })
		make(
			"PointLight",
			{ Color = Color3.fromRGB(255, 230, 240), Range = 34, Brightness = 1.4, Shadows = false },
			lamp
		)
	end
end

local function buildSides(root: Instance, refs: Refs)
	local folder = Kit.folder("Boulevard", root)
	refs.Prompts = {}

	-- The Boutique: a glass pavilion with mannequins and the shop kiosk.
	local boutique = Layout.Kiosks.Boutique
	part(folder, {
		Size = Vector3.new(26, 0.6, 70),
		Position = Vector3.new(66, 0.3, 0),
		Color = C.Floor,
		Material = MARBLE,
	})
	part(folder, {
		Size = Vector3.new(1, 16, 70),
		Position = Vector3.new(79, 8, 0),
		Color = C.Wall,
		Material = SMOOTH,
	})
	part(folder, {
		Size = Vector3.new(26, 1, 70),
		Position = Vector3.new(66, 16.5, 0),
		Color = C.Glass,
		Material = GLASS,
		Transparency = 0.5,
	})
	for _, z in { -34.5, 34.5 } do
		part(
			folder,
			{ Size = Vector3.new(26, 16, 1), Position = Vector3.new(66, 8, z), Color = C.Wall, Material = SMOOTH }
		)
	end
	part(folder, {
		Size = Vector3.new(0.6, 0.6, 70),
		Position = Vector3.new(53.2, 16, 0),
		Color = C.Aqua,
		Material = NEON,
		CanCollide = false,
	})
	Kit.sign(
		folder,
		CFrame.new(78.4, 12, 0) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(24, 4.4, 0.4),
		"BOUTIQUE",
		{ Back = C.Wall, Text = C.Aqua, Stroke = C.Velvet }
	)
	mannequin(folder, CFrame.new(72, 0.6, -9), C.Gold, C.Pink)
	mannequin(folder, CFrame.new(72, 0.6, 9), C.Violet, C.Aqua)
	refs.Prompts.Boutique = kiosk(folder, boutique, "Boutique", "Shop", C.Aqua)
	refs.Prompts.StylePass = kiosk(folder, Layout.Kiosks.StylePass, "Style Pass", "Open", C.Gold)

	-- The leaderboard: the top Style Scores in the world.
	local board = part(folder, {
		Name = "Leaderboard",
		Size = Vector3.new(14, 16, 0.6),
		CFrame = Layout.Kiosks.Leaderboard * CFrame.new(0, 9, 0),
		Color = Color3.fromRGB(14, 10, 24),
		Material = SMOOTH,
	})
	part(folder, {
		Size = Vector3.new(14.8, 16.8, 0.4),
		CFrame = Layout.Kiosks.Leaderboard * CFrame.new(0, 9, 0.3),
		Color = C.Gold,
		Material = NEON,
		CanCollide = false,
	})
	local boardGui = make("SurfaceGui", {
		Name = "Board",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 30,
		LightInfluence = 0,
	}, board)
	make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
		Text = "TOP STYLE SCORES",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.Gold,
	}, boardGui)
	local list = make("Frame", {
		Name = "List",
		Position = UDim2.fromScale(0.05, 0.14),
		Size = UDim2.fromScale(0.9, 0.84),
		BackgroundTransparency = 1,
	}, boardGui)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.01, 0) }, list)
	for row = 1, 10 do
		make("TextLabel", {
			Name = `Row{row}`,
			LayoutOrder = row,
			Size = UDim2.fromScale(1, 0.09),
			BackgroundTransparency = 1,
			Text = `{row}.  -`,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if row == 1 then C.Gold else Color3.new(1, 1, 1),
		}, list)
	end
	refs.Leaderboard = boardGui

	-- West side: the closet and challenge kiosks, and the VIP Lounge.
	refs.Prompts.Closet = kiosk(folder, Layout.Kiosks.Closet, "My Closet", "Open", C.Pink)
	refs.Prompts.Challenges = kiosk(folder, Layout.Kiosks.Challenges, "Challenges", "Open", C.Violet)

	local lounge = Layout.Lounge
	local floorY = lounge.Floor
	part(folder, {
		Name = "LoungeDeck",
		Size = Vector3.new(30, 1, 40),
		Position = lounge.Centre - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(30, 22, 40),
		Material = MARBLE,
		Reflectance = 0.15,
	})
	part(folder, {
		Size = Vector3.new(30.6, 0.4, 40.6),
		Position = lounge.Centre - Vector3.new(0, 1.1, 0),
		Color = C.Gold,
		Material = NEON,
		CanCollide = false,
	})
	for _, offset in
		{ Vector3.new(-12, 0, -17), Vector3.new(-12, 0, 17), Vector3.new(12, 0, -17), Vector3.new(12, 0, 17) }
	do
		part(folder, {
			Size = Vector3.new(2, floorY, 2),
			Position = lounge.Centre + offset - Vector3.new(0, floorY / 2, 0),
			Color = C.Gold,
			Material = METAL,
		})
	end
	-- The gate: a glowing doorway that lifts VIPs up to the deck.
	local gate = part(folder, {
		Name = "VipGate",
		Size = Vector3.new(0.6, 8, 6),
		CFrame = lounge.Gate,
		Color = C.Gold,
		Material = NEON,
		Transparency = 0.35,
		CanCollide = false,
	})
	for _, z in { -3.4, 3.4 } do
		part(folder, {
			Size = Vector3.new(1, 9, 0.8),
			Position = lounge.Gate.Position + Vector3.new(0, 0.5, z),
			Color = C.Gold,
			Material = METAL,
		})
	end
	part(folder, {
		Size = Vector3.new(1, 0.8, 7.6),
		Position = lounge.Gate.Position + Vector3.new(0, 4.6, 0),
		Color = C.Gold,
		Material = METAL,
	})
	refs.VipGate = gate
	refs.Prompts.Vip = prompt(gate, "Enter", "VIP Lounge")
	Kit.sign(
		folder,
		CFrame.new(-49.4, 10, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(10, 2.6, 0.4),
		"VIP LOUNGE",
		{ Back = Color3.fromRGB(30, 22, 40), Text = C.Gold, Stroke = Color3.new(0, 0, 0) }
	)
	bench(folder, CFrame.new(lounge.Centre + Vector3.new(-8, 0, -10)) * CFrame.Angles(0, math.rad(90), 0))
	bench(folder, CFrame.new(lounge.Centre + Vector3.new(-8, 0, 10)) * CFrame.Angles(0, math.rad(90), 0))
	local lampTop = ball(folder, lounge.Centre + Vector3.new(0, 9, 0), 3, { Color = C.Gold, Material = NEON })
	make("PointLight", { Color = C.Gold, Range = 30, Brightness = 1.6, Shadows = false }, lampTop)
	mannequin(folder, CFrame.new(lounge.Centre + Vector3.new(10, 0, 0)), C.Gold, Color3.new(1, 1, 1))
end

-- The sky, fog and glow for an evening show.
function World.lighting(lighting: Instance)
	for _, child in lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	make("Atmosphere", {
		Density = 0.32,
		Offset = 0.1,
		Color = Color3.fromRGB(220, 160, 220),
		Decay = Color3.fromRGB(90, 60, 140),
		Glare = 0.3,
		Haze = 1.4,
	}, lighting)
	make("BloomEffect", { Intensity = 0.7, Size = 28, Threshold = 1.4 }, lighting)
	make("ColorCorrectionEffect", {
		Saturation = 0.12,
		Contrast = 0.06,
		Brightness = 0.02,
		TintColor = Color3.fromRGB(255, 244, 252),
	}, lighting)
	make("SunRaysEffect", { Intensity = 0.04, Spread = 0.6 }, lighting)
end

-- Builds the whole map under parent and returns the parts others update.
function World.build(parent: Instance): Refs
	local root = Kit.folder("CatwalkClash", parent)
	local refs = { Root = root } :: any
	buildPlaza(root, refs)
	buildRunway(root, refs)
	buildBackstage(root, refs)
	buildSides(root, refs)
	return refs :: Refs
end

return World
