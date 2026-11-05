-- The big builds: the hearth and the lodge at the middle of town, the base's
-- stations (workbench, stockpile, cook pot), the radio tower, the railway
-- and its station, the players' cabins, and the four landmarks where the
-- radio parts are frozen. Each takes the ground spot it stands on, facing
-- the way it should face (its front is -Z).
--
-- Things the server needs to find are named: a station's prompt goes on its
-- part named "Prompt"; a landmark's frozen part sits at its attachment named
-- "PartSpot"; a cabin's decorations hang off attachments named after the
-- spots in Config/Decor.

local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)

local Landmarks = {}

local SNOW = Enum.Material.Snow
local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local ROCK = Enum.Material.Slate
local BRICK = Enum.Material.Brick
local METAL = Enum.Material.DiamondPlate
local ICE = Enum.Material.Ice

local function promptPart(model: Model, at: CFrame, size: Vector3): Part
	local part = Kit.block(model, at, size, Palette.White)
	part.Name = "Prompt"
	part.Transparency = 1
	model.PrimaryPart = part
	return part
end

local function spot(part: BasePart, name: string, at: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = part.CFrame:ToObjectSpace(at)
	attachment.Parent = part
	return attachment
end

-- The great hearth: a wide ring of stones around a log fire. The client
-- grows and shrinks its flames with the hearth's flame (parts named
-- "Flame"), and the PointLight named "Glow" with it.
function Landmarks.hearth(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Hearth")
	local ring = 10
	for index = 1, ring do
		local angle = index / ring * math.pi * 2
		local stone = Kit.solid(
			Kit.block(
				model,
				at * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.1, -4.6) * CFrame.Angles(0.1, 0, 0),
				Vector3.new(3.2, 2.2, 1.8),
				if index % 2 == 0 then Palette.Stone else Palette.StoneDark,
				ROCK
			)
		)
		stone.Name = "Stone"
		Kit.block(
			model,
			at * CFrame.Angles(0, angle, 0) * CFrame.new(0, 2.3, -4.6),
			Vector3.new(2.6, 0.3, 1.4),
			Palette.Snow,
			SNOW
		)
	end
	Kit.post(model, at * CFrame.new(0, 0.2, 0), 0.4, 8.4, Palette.Coal, Enum.Material.Basalt)
	-- A low round step of stone under it all, and four tall standing stones
	-- with embers on top, so the hearth reads as the heart of the town from
	-- across the valley.
	Kit.post(model, at * CFrame.new(0, 0.1, 0), 0.25, 16, Palette.StoneDark, ROCK)
	for index = 1, 4 do
		local angle = (index - 0.5) / 4 * math.pi * 2
		local base = at * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -8.6)
		Kit.solid(Kit.block(model, base * CFrame.new(0, 3.2, 0), Vector3.new(1.8, 6.4, 1.8), Palette.Stone, ROCK))
		Kit.block(model, base * CFrame.new(0, 6.5, 0), Vector3.new(2.4, 0.4, 2.4), Palette.StoneDark, ROCK)
		local ember = Kit.glow(model, base * CFrame.new(0, 7.2, 0), Vector3.new(1.4, 1.2, 1.4), Palette.Ember, true)
		ember.Name = "Flame"
	end
	-- Logs in a teepee.
	for index = 1, 5 do
		local angle = index / 5 * math.pi * 2
		Kit.log(
			model,
			at * CFrame.Angles(0, angle, 0) * CFrame.new(1.4, 1.6, 0) * CFrame.Angles(0, 0, 1.05),
			4.4,
			0.8,
			Palette.Log,
			WOOD
		)
	end
	local core = Kit.glow(model, at * CFrame.new(0, 2, 0), Vector3.new(3.8, 4, 3.8), Palette.Ember, true)
	core.Name = "Flame"
	core.Transparency = 0.15
	local tip = Kit.glow(model, at * CFrame.new(0, 4.2, 0), Vector3.new(2.4, 3.8, 2.4), Palette.Flame, true)
	tip.Name = "Flame"
	tip.Transparency = 0.25
	local fire = Instance.new("Fire")
	fire.Name = "Fire"
	fire.Size = 9
	fire.Heat = 12
	fire.Color = Palette.Ember
	fire.SecondaryColor = Palette.Flame
	fire.Parent = core
	local glow = Kit.light(core, Palette.Warm, 46, 2.4, true)
	glow.Name = "Glow"
	glow.Shadows = true
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Palette.Flame, Palette.Ember)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Rate = 14
	sparks.Speed = NumberRange.new(5, 10)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Parent = tip
	promptPart(model, at * CFrame.new(0, 3, 0), Vector3.new(9, 6, 9))
	return model
end

-- The lodge: a long log hall behind the hearth, its open porch facing the
-- fire, windows glowing.
function Landmarks.lodge(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Lodge")
	local w, d, h = 32, 22, 13
	-- Floor and porch deck.
	Kit.solid(Kit.block(model, at * CFrame.new(0, 0.5, 0), Vector3.new(w, 1, d), Palette.PlankDark, PLANKS))
	Kit.solid(Kit.block(model, at * CFrame.new(0, 0.4, -d / 2 - 3), Vector3.new(w - 6, 0.8, 6), Palette.Plank, PLANKS))
	-- Walls: back, sides, and the front split around a wide doorway.
	Kit.solid(Kit.block(model, at * CFrame.new(0, h / 2 + 1, d / 2 - 0.75), Vector3.new(w, h, 1.5), Palette.Log, WOOD))
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(side * (w / 2 - 0.75), h / 2 + 1, 0),
				Vector3.new(1.5, h, d),
				Palette.Log,
				WOOD
			)
		)
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(side * (w / 4 + 3), h / 2 + 1, -d / 2 + 0.75),
				Vector3.new(w / 2 - 6, h, 1.5),
				Palette.Log,
				WOOD
			)
		)
		-- Corner logs.
		for end_ = -1, 1, 2 do
			Kit.post(
				model,
				at * CFrame.new(side * (w / 2 - 0.6), h / 2 + 1, end_ * (d / 2 - 0.6)),
				h + 1,
				2,
				Palette.Bark,
				WOOD
			)
		end
		-- Glowing windows on the front.
		local window =
			Kit.glow(model, at * CFrame.new(side * (w / 4 + 4), 7, -d / 2 - 0.05), Vector3.new(5, 4, 0.3), Palette.Warm)
		window.Name = "Window"
		Kit.block(
			model,
			at * CFrame.new(side * (w / 4 + 4), 7, -d / 2 - 0.25),
			Vector3.new(0.3, 4.2, 0.3),
			Palette.Bark,
			WOOD
		)
		Kit.block(
			model,
			at * CFrame.new(side * (w / 4 + 4), 4.8, -d / 2 - 0.6),
			Vector3.new(5.6, 0.4, 1),
			Palette.Bark,
			WOOD
		)
		-- Porch posts.
		Kit.solid(Kit.post(model, at * CFrame.new(side * (w / 2 - 4), 4.5, -d / 2 - 5.5), 8, 1, Palette.Bark, WOOD))
		Kit.solid(Kit.post(model, at * CFrame.new(side * 5, 4.5, -d / 2 - 5.5), 8, 1, Palette.Bark, WOOD))
	end
	-- Above the doorway.
	Kit.solid(Kit.block(model, at * CFrame.new(0, h - 1.5, -d / 2 + 0.75), Vector3.new(12, 5, 1.5), Palette.Log, WOOD))
	-- Porch roof.
	Kit.block(
		model,
		at * CFrame.new(0, 9, -d / 2 - 3) * CFrame.Angles(-0.25, 0, 0),
		Vector3.new(w - 4, 0.6, 7.5),
		Palette.RoofRed,
		Enum.Material.Slate
	)
	Kit.block(
		model,
		at * CFrame.new(0, 9.45, -d / 2 - 3) * CFrame.Angles(-0.25, 0, 0),
		Vector3.new(w - 4.4, 0.4, 7),
		Palette.Snow,
		SNOW
	)
	-- Main roof: two slopes and snow.
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(0, h + 3.6, side * (d / 4 + 0.6)) * CFrame.Angles(side * 0.55, 0, 0),
				Vector3.new(w + 3, 1, d / 2 + 4),
				Palette.RoofRed,
				Enum.Material.Slate
			)
		)
		Kit.block(
			model,
			at * CFrame.new(0, h + 4.25, side * (d / 4 + 0.6)) * CFrame.Angles(side * 0.55, 0, 0),
			Vector3.new(w + 2.6, 0.6, d / 2 + 3.4),
			Palette.Snow,
			SNOW
		)
		-- Gable ends.
		Kit.wedge(
			model,
			at * CFrame.new(side * (w / 2 - 0.75), h + 3, -d / 4),
			Vector3.new(1.5, 6, d / 2),
			Palette.Log,
			WOOD
		)
		Kit.wedge(
			model,
			at * CFrame.new(side * (w / 2 - 0.75), h + 3, d / 4) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(1.5, 6, d / 2),
			Palette.Log,
			WOOD
		)
	end
	-- Chimney with smoke.
	Kit.solid(
		Kit.block(model, at * CFrame.new(w / 2 - 7, h + 6, 4), Vector3.new(3.4, 9, 3.4), Palette.StoneDark, BRICK)
	)
	local top = Kit.block(model, at * CFrame.new(w / 2 - 7, h + 10.7, 4), Vector3.new(4, 0.5, 4), Palette.Snow, SNOW)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(200, 205, 215)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = top
	-- Inside: a long table and a rug, lit warm.
	Kit.solid(Kit.block(model, at * CFrame.new(0, 3.4, 3), Vector3.new(14, 0.6, 4), Palette.Plank, PLANKS))
	for side = -1, 1, 2 do
		Kit.block(model, at * CFrame.new(side * 6, 2, 3), Vector3.new(0.8, 2.6, 3.4), Palette.PlankDark, WOOD)
		Kit.solid(
			Kit.block(model, at * CFrame.new(0, 2, 3 + side * 3.6), Vector3.new(13, 0.6, 1.4), Palette.PlankDark, WOOD)
		)
	end
	Kit.block(model, at * CFrame.new(0, 1.05, -2), Vector3.new(16, 0.1, 8), Palette.Cloth, Enum.Material.Fabric)
	local lamp = Kit.glow(model, at * CFrame.new(0, 11, 2), Vector3.new(1.4, 1.4, 1.4), Palette.Warm, true)
	Kit.light(lamp, Palette.Warm, 24, 1.4)
	Props.sign(model, at * CFrame.new(0, h - 1, -d / 2 - 0.2) * CFrame.new(0, -5.4, -0.6), "PINEHOLLOW LODGE", 12)
	return model
end

-- The workbench: a sturdy table with tools, a vice and a lamp.
function Landmarks.workbench(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Workbench")
	Kit.solid(Kit.block(model, at * CFrame.new(0, 3, 0), Vector3.new(8, 0.6, 4), Palette.Plank, PLANKS))
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			Kit.block(
				model,
				at * CFrame.new(x * 3.5, 1.4, z * 1.5),
				Vector3.new(0.6, 2.8, 0.6),
				Palette.PlankDark,
				WOOD
			)
		end
	end
	Kit.block(model, at * CFrame.new(0, 3.4, 1.8), Vector3.new(8, 0.2, 0.4), Palette.Snow, SNOW)
	-- A saw, a hammer and a vice.
	Kit.block(
		model,
		at * CFrame.new(-2.2, 3.4, -0.3) * CFrame.Angles(0, 0.3, 0),
		Vector3.new(3, 0.1, 1),
		Palette.Metal,
		METAL
	)
	Kit.block(
		model,
		at * CFrame.new(1, 3.45, 0.4) * CFrame.Angles(0, -0.5, 0),
		Vector3.new(2.2, 0.3, 0.3),
		Palette.Log,
		WOOD
	)
	Kit.block(
		model,
		at * CFrame.new(1.9, 3.55, 0.9) * CFrame.Angles(0, -0.5, 0),
		Vector3.new(0.5, 0.5, 1),
		Palette.MetalDark,
		METAL
	)
	Kit.block(model, at * CFrame.new(3.2, 3.8, -1), Vector3.new(1.2, 1, 1.2), Palette.MetalDark, METAL)
	-- A pegboard behind.
	Kit.solid(Kit.block(model, at * CFrame.new(0, 5.5, 2.2), Vector3.new(8, 5, 0.4), Palette.PlankDark, PLANKS))
	local lamp = Kit.glow(model, at * CFrame.new(0, 8.4, 1.6), Vector3.new(1.2, 0.8, 1.2), Palette.Warm, true)
	Kit.light(lamp, Palette.Warm, 14, 1)
	Props.sign(model, at * CFrame.new(0, 5.3, 2.5) * CFrame.new(0, -3.4, -0.5) * CFrame.new(0, 0, 0), "WORKBENCH", 6)
	promptPart(model, at * CFrame.new(0, 3, -1), Vector3.new(8, 4, 4))
	return model
end

-- The stockpile: crates, a log pile and a barrel where the team's
-- gatherings go.
function Landmarks.stockpile(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Stockpile")
	Kit.solid(Kit.block(model, at * CFrame.new(-1.5, 1.6, 0.5), Vector3.new(3.4, 3.2, 3.4), Palette.Plank, PLANKS))
	Kit.solid(Kit.block(model, at * CFrame.new(1.8, 1.4, 1), Vector3.new(3, 2.8, 3), Palette.PlankDark, PLANKS))
	Kit.block(
		model,
		at * CFrame.new(-1.2, 4.3, 0.6) * CFrame.Angles(0, 0.4, 0),
		Vector3.new(2.6, 2.2, 2.6),
		Palette.Plank,
		PLANKS
	)
	for index = 0, 2 do
		Kit.log(model, at * CFrame.new(0.5, 0.6 + index * 0.9, -2.6 + (index % 2) * 0.2), 6, 1, Palette.Log, WOOD)
	end
	Kit.solid(Kit.post(model, at * CFrame.new(4.4, 1.6, -1.2), 3.2, 2.4, Palette.Rust, Enum.Material.CorrodedMetal))
	Kit.block(model, at * CFrame.new(-1.5, 3.3, 0.5), Vector3.new(3.5, 0.3, 3.5), Palette.Snow, SNOW)
	Props.sign(model, at * CFrame.new(0, 0, 3.6) * CFrame.Angles(0, math.pi, 0), "STOCKPILE", 7)
	promptPart(model, at * CFrame.new(0, 2.5, 0), Vector3.new(8, 5, 6))
	return model
end

-- The cook pot: a black cauldron on a tripod over a small fire.
function Landmarks.cookPot(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "CookPot")
	for index = 1, 3 do
		local angle = index / 3 * math.pi * 2
		Kit.span(
			model,
			at * Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3),
			at * Vector3.new(0, 7, 0),
			0.4,
			0.4,
			Palette.Bark,
			WOOD
		)
	end
	local pot = Kit.solid(Kit.ball(model, at * CFrame.new(0, 3, 0), Vector3.new(4, 3.4, 4), Palette.Coal, METAL))
	Kit.post(model, at * CFrame.new(0, 4.4, 0), 0.4, 3.4, Palette.Coal, METAL)
	local stew = Kit.post(model, at * CFrame.new(0, 4.5, 0), 0.2, 3, Palette.Ember, Enum.Material.Neon)
	stew.Name = "Stew"
	Kit.span(model, at * Vector3.new(0, 7, 0), at * Vector3.new(0, 4.6, 0), 0.1, 0.1, Palette.MetalDark)
	local embers = Kit.glow(model, at * CFrame.new(0, 0.5, 0), Vector3.new(2.6, 0.6, 2.6), Palette.Ember, true)
	Kit.light(embers, Palette.Ember, 12, 1, true)
	local steam = Instance.new("Smoke")
	steam.Color = Color3.fromRGB(240, 240, 245)
	steam.Opacity = 0.12
	steam.RiseVelocity = 3
	steam.Size = 1.5
	steam.Parent = stew
	Props.sign(model, at * CFrame.new(0, 0, 5) * CFrame.Angles(0, math.pi, 0), "COOK POT", 6)
	pot.Name = "Pot"
	promptPart(model, at * CFrame.new(0, 3, 0), Vector3.new(6, 6, 6))
	return model
end

-- The radio tower: a steel lattice on a little hill with a shack at its
-- foot. Its four sockets (attachments "Socket1" to "Socket4") show each
-- radio part once it is fitted, and the beacon on top lights when the
-- radio calls the train.
function Landmarks.radioTower(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "RadioTower")
	Kit.solid(Kit.ball(model, at * CFrame.new(0, -2, 0), Vector3.new(34, 8, 34), Palette.Snow, SNOW))
	local base = at * CFrame.new(0, 2, 4)
	local h = 46
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			Kit.solid(
				Kit.span(
					model,
					(base * CFrame.new(x * 4, 0, z * 4)).Position,
					(base * CFrame.new(x * 0.8, h, z * 0.8)).Position,
					0.6,
					0.6,
					Palette.RoofRed,
					METAL
				)
			)
		end
	end
	for level = 1, 5 do
		local y = level * 8
		local spread = 4 - 3.2 * y / h
		for side = 0, 3 do
			local a = CFrame.Angles(0, side * math.pi / 2, 0)
			local from = (base * a * CFrame.new(-spread, y, -spread)).Position
			local to = (base * a * CFrame.new(spread, y, -spread)).Position
			Kit.span(model, from, to, 0.3, 0.3, if level % 2 == 0 then Palette.White else Palette.RoofRed, METAL)
		end
	end
	Kit.post(model, base * CFrame.new(0, h + 4, 0), 8, 0.4, Palette.MetalDark, METAL)
	local beacon =
		Kit.glow(model, base * CFrame.new(0, h + 8.6, 0), Vector3.new(1.6, 1.6, 1.6), Palette.MetalDark, true)
	beacon.Name = "Beacon"
	beacon.Material = Enum.Material.SmoothPlastic
	-- The shack.
	local shack = at * CFrame.new(0, 0, -6)
	Kit.solid(Kit.block(model, shack * CFrame.new(0, 3.5, 0), Vector3.new(10, 7, 7), Palette.PlankDark, PLANKS))
	Kit.block(
		model,
		shack * CFrame.new(0, 7.3, 0) * CFrame.Angles(-0.15, 0, 0),
		Vector3.new(11, 0.6, 8.4),
		Palette.RoofTeal,
		Enum.Material.Slate
	)
	Kit.block(
		model,
		shack * CFrame.new(0, 7.7, 0) * CFrame.Angles(-0.15, 0, 0),
		Vector3.new(10.6, 0.4, 8),
		Palette.Snow,
		SNOW
	)
	local panel = Kit.block(model, shack * CFrame.new(0, 4, -3.6), Vector3.new(8, 3.2, 0.4), Palette.MetalDark, METAL)
	panel.Name = "Panel"
	for index = 1, 4 do
		local socket = shack * CFrame.new(-3 + (index - 1) * 2, 4, -4.4)
		local frame = Kit.block(model, socket, Vector3.new(1.6, 1.6, 0.6), Palette.Metal, METAL)
		frame.Name = `SocketFrame{index}`
		spot(panel, `Socket{index}`, socket * CFrame.new(0, 0, -0.8))
	end
	Props.sign(model, shack * CFrame.new(0, 0, -6.5), "RADIO", 5)
	promptPart(model, shack * CFrame.new(0, 3.5, -4), Vector3.new(10, 7, 4))
	return model
end

-- The railway line and the station where the rescue train stops. Rails
-- run along X through the whole valley; sleepers stop where the blizzard
-- would hide them anyway.
function Landmarks.railway(parent: Instance, trackZ: number, stationX: number): Model
	local model = Kit.model(parent, "Railway")
	local length = 680
	for side = -1, 1, 2 do
		Kit.block(model, CFrame.new(0, 0.55, trackZ + side * 2.5), Vector3.new(length, 0.5, 0.4), Palette.Metal, METAL)
	end
	Kit.block(model, CFrame.new(0, 0.12, trackZ), Vector3.new(length, 0.25, 8), Palette.Packed, Enum.Material.Pebble)
	for x = -300, 300, 10 do
		Kit.block(model, CFrame.new(x, 0.3, trackZ), Vector3.new(1.2, 0.3, 7), Palette.PlankDark, WOOD)
	end
	-- The platform, its roof and a bench, on the north side of the line.
	local at = CFrame.new(stationX, 0, trackZ - 10)
	Kit.solid(Kit.block(model, at * CFrame.new(0, 1, 0), Vector3.new(44, 2, 10), Palette.Stone, Enum.Material.Concrete))
	Kit.block(model, at * CFrame.new(0, 2.05, 4.6), Vector3.new(44, 0.1, 0.6), Palette.Gold)
	for x = -18, 18, 12 do
		Kit.solid(Kit.post(model, at * CFrame.new(x, 6, -2), 8, 0.8, Palette.MetalDark, METAL))
	end
	Kit.block(
		model,
		at * CFrame.new(0, 10.3, -0.5) * CFrame.Angles(0.12, 0, 0),
		Vector3.new(46, 0.6, 9),
		Palette.RoofTeal,
		Enum.Material.Slate
	)
	Kit.block(
		model,
		at * CFrame.new(0, 10.75, -0.5) * CFrame.Angles(0.12, 0, 0),
		Vector3.new(45.6, 0.4, 8.6),
		Palette.Snow,
		SNOW
	)
	Kit.solid(Kit.block(model, at * CFrame.new(8, 3, -3), Vector3.new(6, 0.5, 1.6), Palette.Plank, PLANKS))
	local lamp = Kit.glow(model, at * CFrame.new(0, 9.4, -1), Vector3.new(1.2, 1.2, 1.2), Palette.Warm, true)
	Kit.light(lamp, Palette.Warm, 20, 1)
	Props.sign(model, at * CFrame.new(-10, 2, -3.6), "PINEHOLLOW STATION", 12)
	local stop = Kit.block(model, CFrame.new(stationX, 4, trackZ), Vector3.new(2, 2, 2), Palette.White)
	stop.Name = "TrainStop"
	stop.Transparency = 1
	return model
end

-- A cabin by the hearth that one player owns for the run. It shows its
-- owner's name on the sign and wears their decorations (shared/World/Decor
-- builds them at the spots).
function Landmarks.cabin(parent: Instance, at: CFrame, index: number): Model
	local model = Kit.model(parent, `Cabin{index}`)
	local w, d, h = 12, 10, 7.5
	local body =
		Kit.solid(Kit.block(model, at * CFrame.new(0, h / 2 + 0.6, 0), Vector3.new(w, h, d), Palette.Log, WOOD))
	body.Name = "Body"
	Kit.solid(Kit.block(model, at * CFrame.new(0, 0.3, -1), Vector3.new(w + 1, 0.6, d + 4), Palette.PlankDark, PLANKS))
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			Kit.post(
				model,
				at * CFrame.new(x * (w / 2 - 0.3), h / 2 + 0.6, z * (d / 2 - 0.3)),
				h + 0.6,
				1.1,
				Palette.Bark,
				WOOD
			)
		end
	end
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(0, h + 2.6, side * (d / 4 + 0.5)) * CFrame.Angles(side * 0.6, 0, 0),
				Vector3.new(w + 2, 0.7, d / 2 + 2.8),
				Palette.RoofBlue,
				Enum.Material.Slate
			)
		)
		Kit.block(
			model,
			at * CFrame.new(0, h + 3.05, side * (d / 4 + 0.5)) * CFrame.Angles(side * 0.6, 0, 0),
			Vector3.new(w + 1.6, 0.4, d / 2 + 2.3),
			Palette.Snow,
			SNOW
		)
		Kit.wedge(
			model,
			at * CFrame.new(side * (w / 2 - 0.3), h + 2.1, -d / 4),
			Vector3.new(0.6, 3, d / 2),
			Palette.Log,
			WOOD
		)
		Kit.wedge(
			model,
			at * CFrame.new(side * (w / 2 - 0.3), h + 2.1, d / 4) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(0.6, 3, d / 2),
			Palette.Log,
			WOOD
		)
	end
	local door =
		Kit.block(model, at * CFrame.new(0, 3.4, -d / 2 - 0.1), Vector3.new(3, 5.4, 0.3), Palette.PlankDark, WOOD)
	door.Name = "Door"
	for side = -1, 1, 2 do
		local window =
			Kit.glow(model, at * CFrame.new(side * 3.8, 4.6, -d / 2 - 0.08), Vector3.new(2.4, 2.2, 0.2), Palette.Warm)
		window.Name = "Window"
	end
	-- The owner's name.
	local plate =
		Kit.block(model, at * CFrame.new(0, 7.1, -d / 2 - 0.2), Vector3.new(6, 1.2, 0.2), Palette.Plank, PLANKS)
	plate.Name = "NamePlate"
	local gui = Kit.new(
		"SurfaceGui",
		plate,
		{ Name = "Name", Face = Enum.NormalId.Front, PixelsPerStud = 40, LightInfluence = 0.3 }
	)
	Kit.new("TextLabel", gui, {
		Name = "Owner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "Free cabin",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(58, 36, 22),
	})
	-- Spots for decorations, all hanging off the body.
	spot(body, "Roof", at * CFrame.new(0, h + 4.9, 0))
	spot(body, "Door", at * CFrame.new(0, 4.4, -d / 2 - 0.4))
	spot(body, "Porch", at * CFrame.new(-4.4, 0.6, -d / 2 - 2))
	spot(body, "Yard", at * CFrame.new(4.4, 0, -d / 2 - 6.5))
	spot(body, "Flag", at * CFrame.new(w / 2 + 1.5, 0, -d / 2 - 1))
	model.PrimaryPart = body
	return model
end

-- The Old Sawmill: an open shed with a giant round saw and stacked logs.
function Landmarks.sawmill(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Sawmill")
	local w, d = 30, 18
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			Kit.solid(
				Kit.post(model, at * CFrame.new(x * (w / 2 - 1), 6, z * (d / 2 - 1)), 12, 1.4, Palette.Bark, WOOD)
			)
		end
	end
	Kit.solid(Kit.block(model, at * CFrame.new(0, 0.5, 0), Vector3.new(w, 1, d), Palette.PlankDark, PLANKS))
	Kit.solid(Kit.block(model, at * CFrame.new(0, 7, d / 2 - 0.5), Vector3.new(w, 12, 1), Palette.Plank, PLANKS))
	for side = -1, 1, 2 do
		Kit.block(
			model,
			at * CFrame.new(0, 14, side * (d / 4 + 0.4)) * CFrame.Angles(side * 0.45, 0, 0),
			Vector3.new(w + 3, 0.8, d / 2 + 3),
			Palette.RoofTeal,
			Enum.Material.CorrodedMetal
		)
		Kit.block(
			model,
			at * CFrame.new(0, 14.5, side * (d / 4 + 0.4)) * CFrame.Angles(side * 0.45, 0, 0),
			Vector3.new(w + 2.6, 0.5, d / 2 + 2.4),
			Palette.Snow,
			SNOW
		)
	end
	-- The saw table and blade.
	Kit.solid(Kit.block(model, at * CFrame.new(-4, 3, 0), Vector3.new(16, 1, 4), Palette.Plank, PLANKS))
	local blade = Kit.new("Part", model, {
		Anchored = true,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 8, 8),
		CFrame = at * CFrame.new(-4, 4.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Palette.Metal,
		Material = METAL,
	})
	blade.Name = "Blade"
	Kit.log(model, at * CFrame.new(-4, 4.2, 0) * CFrame.Angles(0, 0, 0), 12, 2, Palette.Log, WOOD)
	-- Log piles outside.
	for row = 0, 2 do
		for index = 0, 3 - row do
			Kit.solid(
				Kit.log(
					model,
					at
						* CFrame.new(w / 2 + 3 + index * 2.3 + row * 1.15, 1.2 + row * 2, 0)
						* CFrame.Angles(0, math.pi / 2, 0),
					12,
					2.2,
					Palette.Log,
					WOOD
				)
			)
		end
	end
	local part = Kit.block(model, at * CFrame.new(6, 1, -3), Vector3.new(1, 1, 1), Palette.White)
	part.Name = "Marker"
	part.Transparency = 1
	spot(part, "PartSpot", at * CFrame.new(6, 1, -3))
	Props.sign(model, at * CFrame.new(0, 0, -d / 2 - 6), "OLD SAWMILL", 9)
	model.PrimaryPart = part
	return model
end

-- The Ice Cave: an arch of blue ice and rock, glittering crystals inside.
function Landmarks.iceCave(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "IceCave")
	-- Rock walls either side and a roof slab.
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(side * 12, 8, 6) * CFrame.Angles(0, side * 0.1, side * 0.08),
				Vector3.new(10, 16, 26),
				Palette.StoneDark,
				ROCK
			)
		)
		Kit.block(model, at * CFrame.new(side * 12, 16.4, 6), Vector3.new(10.4, 1.6, 26.4), Palette.Snow, SNOW)
	end
	Kit.solid(
		Kit.block(
			model,
			at * CFrame.new(0, 17, 8) * CFrame.Angles(0.05, 0, 0),
			Vector3.new(30, 4, 24),
			Palette.Stone,
			ROCK
		)
	)
	Kit.block(model, at * CFrame.new(0, 19.4, 8), Vector3.new(30.6, 1.4, 24.6), Palette.Snow, SNOW)
	Kit.solid(Kit.block(model, at * CFrame.new(0, 8, 19), Vector3.new(16, 16, 2), Palette.IceDeep, ICE))
	-- Icicles along the mouth.
	for index = -5, 5 do
		local icicle = Kit.wedge(
			model,
			at * CFrame.new(index * 1.8, 13.4, -4) * CFrame.Angles(math.pi, 0, 0),
			Vector3.new(0.8, 3 + (index % 3), 0.8),
			Palette.Ice,
			ICE
		)
		icicle.Transparency = 0.2
	end
	-- Crystals.
	for index, offset in { Vector3.new(-6, 0, 10), Vector3.new(5, 0, 14), Vector3.new(-2, 0, 16), Vector3.new(7, 0, 4) } do
		local crystal = Kit.glow(
			model,
			at * CFrame.new(offset) * CFrame.new(0, 2.5 + index * 0.3, 0) * CFrame.Angles(0.2 * index, index, 0.25),
			Vector3.new(1.6, 5 + index, 1.6),
			Palette.IceGlow
		)
		crystal.Transparency = 0.2
	end
	local inside = Kit.glow(model, at * CFrame.new(0, 12, 12), Vector3.new(1, 1, 1), Palette.IceGlow, true)
	Kit.light(inside, Palette.IceGlow, 30, 1.6)
	local part = Kit.block(model, at * CFrame.new(0, 1, 8), Vector3.new(1, 1, 1), Palette.White)
	part.Name = "Marker"
	part.Transparency = 1
	spot(part, "PartSpot", at * CFrame.new(0, 1, 8))
	Props.sign(model, at * CFrame.new(0, 0, -12), "ICE CAVE", 7)
	model.PrimaryPart = part
	return model
end

-- The Lake Lighthouse: a striped tower on a rocky islet in the frozen lake.
function Landmarks.lighthouse(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Lighthouse")
	Kit.solid(Kit.ball(model, at * CFrame.new(0, -1, 0), Vector3.new(26, 6, 26), Palette.StoneDark, ROCK))
	Kit.ball(model, at * CFrame.new(0, 1.2, 0), Vector3.new(22, 2, 22), Palette.Snow, SNOW)
	for band = 0, 5 do
		Kit.solid(
			Kit.post(
				model,
				at * CFrame.new(0, 3 + band * 4, 0),
				4,
				9 - band * 0.6,
				if band % 2 == 0 then Palette.White else Palette.RoofRed,
				Enum.Material.Concrete
			)
		)
	end
	Kit.post(model, at * CFrame.new(0, 27, 0), 1, 7.6, Palette.MetalDark, METAL)
	local lamp = Kit.glow(model, at * CFrame.new(0, 29.6, 0), Vector3.new(4.4, 4, 4.4), Palette.Flame, true)
	lamp.Name = "Lamp"
	lamp.Transparency = 0.2
	Kit.light(lamp, Palette.Flame, 40, 1.4)
	Kit.post(model, at * CFrame.new(0, 32.4, 0), 1.6, 6.8, Palette.RoofRed, Enum.Material.Slate)
	Kit.ball(model, at * CFrame.new(0, 33.6, 0), Vector3.new(1.4, 1.4, 1.4), Palette.MetalDark, METAL)
	Kit.block(model, at * CFrame.new(0, 3.2, -4.2), Vector3.new(3, 5, 0.4), Palette.PlankDark, WOOD)
	local part = Kit.block(model, at * CFrame.new(-7, 2.5, -4), Vector3.new(1, 1, 1), Palette.White)
	part.Name = "Marker"
	part.Transparency = 1
	spot(part, "PartSpot", at * CFrame.new(-7, 2.5, -4))
	Props.sign(model, at * CFrame.new(10, 2, -10) * CFrame.Angles(0, -0.6, 0), "LAKE LIGHTHOUSE", 10)
	model.PrimaryPart = part
	return model
end

-- The Engine Depot: a brick shed over a siding, an old engine asleep
-- inside.
function Landmarks.depot(parent: Instance, at: CFrame): Model
	local model = Kit.model(parent, "Depot")
	local w, d, h = 22, 34, 14
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				at * CFrame.new(side * (w / 2 - 1), h / 2, 0),
				Vector3.new(2, h, d),
				Palette.RoofRed,
				BRICK
			)
		)
	end
	Kit.solid(Kit.block(model, at * CFrame.new(0, h / 2, d / 2 - 1), Vector3.new(w, h, 2), Palette.RoofRed, BRICK))
	Kit.solid(
		Kit.block(
			model,
			at * CFrame.new(0, h + 2, 0),
			Vector3.new(w + 2, 4, d + 2),
			Palette.StoneDark,
			Enum.Material.CorrodedMetal
		)
	)
	Kit.block(model, at * CFrame.new(0, h + 4.3, 0), Vector3.new(w + 2.4, 0.8, d + 2.4), Palette.Snow, SNOW)
	Kit.block(model, at * CFrame.new(0, h - 1.2, -d / 2 + 1), Vector3.new(w, 2.4, 2), Palette.RoofRed, BRICK)
	-- Rails inside and the sleeping engine.
	for side = -1, 1, 2 do
		Kit.block(model, at * CFrame.new(side * 2.5, 0.5, -6), Vector3.new(0.4, 0.4, d + 12), Palette.Metal, METAL)
	end
	local engine = at * CFrame.new(0, 0, 2)
	Kit.solid(Kit.block(model, engine * CFrame.new(0, 2.4, 0), Vector3.new(7, 2, 18), Palette.Black, METAL))
	Kit.solid(
		Kit.log(
			model,
			engine * CFrame.new(0, 5.4, -2) * CFrame.Angles(0, math.pi / 2, 0),
			12,
			5,
			Palette.MetalDark,
			METAL
		)
	)
	Kit.solid(Kit.block(model, engine * CFrame.new(0, 6, 5.5), Vector3.new(7, 7, 6), Palette.RoofTeal, METAL))
	Kit.post(model, engine * CFrame.new(0, 9.4, -6), 3, 1.6, Palette.Black, METAL)
	for side = -1, 1, 2 do
		for index = -1, 1 do
			Kit.log(model, engine * CFrame.new(side * 3.6, 1.6, index * 5), 0.6, 3, Palette.RoofRed, METAL)
		end
	end
	local part = Kit.block(model, at * CFrame.new(6, 1, -8), Vector3.new(1, 1, 1), Palette.White)
	part.Name = "Marker"
	part.Transparency = 1
	spot(part, "PartSpot", at * CFrame.new(6, 1, -8))
	Props.sign(model, at * CFrame.new(0, 0, -d / 2 - 6), "ENGINE DEPOT", 9)
	model.PrimaryPart = part
	return model
end

-- The rescue train: a bright engine and two carriages. Built when the train
-- is on its way and slid along the rails by each client (client/Sky).
function Landmarks.train(parent: Instance): Model
	local model = Kit.model(parent, "RescueTrain")
	local root = Kit.block(model, CFrame.new(0, 3, 0), Vector3.new(2, 2, 2), Palette.White)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root
	-- The engine faces -X (the way it drives in).
	local engine = CFrame.new(-14, 0, 0)
	Kit.block(model, engine * CFrame.new(0, 2.2, 0), Vector3.new(20, 1.6, 6.6), Palette.Black, METAL)
	Kit.log(model, engine * CFrame.new(-2, 5.2, 0), 13, 5.2, Palette.RoofRed, METAL)
	Kit.block(model, engine * CFrame.new(6.5, 6, 0), Vector3.new(7, 7.4, 6.6), Palette.RoofRed, METAL)
	Kit.block(model, engine * CFrame.new(6.5, 10, 0), Vector3.new(8, 0.6, 7.4), Palette.Black, METAL)
	Kit.post(model, engine * CFrame.new(-6, 9.4, 0), 3.4, 1.8, Palette.Black, METAL)
	Kit.block(model, engine * CFrame.new(-9.6, 1.6, 0), Vector3.new(1.6, 2, 6.6), Palette.Gold, METAL)
	local headlamp = Kit.glow(model, engine * CFrame.new(-8.7, 5.2, 0), Vector3.new(0.4, 2, 2), Palette.Flame, true)
	Kit.light(headlamp, Palette.Flame, 40, 2)
	local steam = Instance.new("Smoke")
	steam.Color = Color3.fromRGB(245, 245, 250)
	steam.Opacity = 0.4
	steam.RiseVelocity = 10
	steam.Size = 4
	steam.Parent = Kit.block(model, engine * CFrame.new(-6, 11.2, 0), Vector3.new(1, 0.2, 1), Palette.Black)
	for index = -1, 1 do
		for side = -1, 1, 2 do
			Kit.log(
				model,
				engine * CFrame.new(index * 5, 1.4, side * 3.4) * CFrame.Angles(0, math.pi / 2, 0),
				0.6,
				2.8,
				Palette.Gold,
				METAL
			)
		end
	end
	for car = 1, 2 do
		local at = CFrame.new(-14 + car * 21, 0, 0)
		Kit.block(model, at * CFrame.new(0, 2, 0), Vector3.new(19, 1.2, 6.4), Palette.Black, METAL)
		Kit.block(
			model,
			at * CFrame.new(0, 5.6, 0),
			Vector3.new(18, 6, 6.6),
			if car == 1 then Palette.RoofTeal else Palette.RoofBlue,
			METAL
		)
		Kit.block(model, at * CFrame.new(0, 9, 0), Vector3.new(18.6, 0.8, 7.2), Palette.White, METAL)
		for index = -2, 2 do
			Kit.glow(model, at * CFrame.new(index * 3.4, 6.4, -3.35), Vector3.new(2.2, 2, 0.1), Palette.Warm)
			Kit.glow(model, at * CFrame.new(index * 3.4, 6.4, 3.35), Vector3.new(2.2, 2, 0.1), Palette.Warm)
		end
	end
	return model
end

return Landmarks
