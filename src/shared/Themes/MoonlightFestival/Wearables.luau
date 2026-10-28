-- The festival's cosmetics, built from parts like the rest of the theme, so
-- players can see from across the plaza what someone has unlocked. Each entry
-- has Build, which makes the item around the origin, and says how it is worn:
--
--   Head, Back  Build() returns a Model laid out around the body attachment
--               named Attach, the way the character faces: +Y up, -Z
--               forward, +X to their right. HidesHead hides the wearer's own
--               head, face and headwear underneath.
--   Hand        Build() returns a Model held at the grip, the origin, with the
--               item standing up (+Y) and its front facing forward (-Z), which
--               is how a Roblox Tool sits in the default hold. A weapon's part
--               named Tip is where a swing lands; Swing picks the sound, the
--               colour of the puff at the tip, and the tool animation.
--   Pet         Build() returns a Model centred on the origin, facing -Z.
--   Aura        Build(attachment) adds particles and light to an attachment
--               at the middle of the character.
--   Trail       Build(top, bottom) adds a trail between two attachments at
--               the character's feet.
--
-- Everything is built anchored and can't collide or touch, like every Kit
-- part, so worn items never press a buy button. The server welds worn and
-- held items on, and each client moves the pets.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

local P = Pieces.Palette
local M = Enum.Material

local C = {
	CandyOrange = Kit.color("#F28A1E"),
	CandyCream = Kit.color("#F4E7CF"),
	Purple = Kit.color("#5B2A86"),
	Lining = Kit.color("#8E1F3A"),
	Gold = Kit.color("#F2C14E"),
	Bronze = Kit.color("#B07A3B"),
	MalletWood = Kit.color("#B5753F"),
	MalletEnd = Kit.color("#E3B582"),
	Leather = Kit.color("#4A2C1D"),
	Moonstone = Kit.color("#DCE6FF"),
	MoonGlow = Kit.color("#8FB4FF"),
	BroomWood = Kit.color("#5C3B24"),
	Straw = Kit.color("#D9B45A"),
	Fur = Kit.color("#5A4030"),
	FurDark = Kit.color("#3A281E"),
	Claw = Kit.color("#EDE6CF"),
	MoonBlade = Kit.color("#CFE3FF"),
	Spirit = Kit.color("#7FF7FF"),
	Steel = Kit.color("#8E95A6"),
	StormStone = Kit.color("#4B4F5C"),
	Lightning = Kit.color("#5FC8FF"),
	ReaperEdge = Kit.color("#B26BFF"),
	SeaBronze = Kit.color("#3E8E7E"),
	Seaweed = Kit.color("#2F6B3A"),
	SeaGlow = Kit.color("#3DF5D0"),
	FanRed = Kit.color("#B3202A"),
	FoxFire = Kit.color("#4FA8FF"),
	Lacquer = Kit.color("#2A1A1E"),
	BatWing = Kit.color("#9B4DFF"),
	Ghostfire = Kit.color("#6CFF5A"),
	Ruby = Kit.color("#E0314B"),
	Leaf = Kit.color("#4F8F3A"),
	Cheese = Kit.color("#F2C94C"),
	Crust = Kit.color("#C98A3E"),
	Pepperoni = Kit.color("#B8322A"),
	BatSkin = Kit.color("#2A1F33"),
	White = Kit.color("#FFFFFF"),
	Pupil = Kit.color("#15121C"),
	Waffle = Kit.color("#D9A35B"),
	Mint = Kit.color("#A8F0D0"),
	Blush = Kit.color("#FF9FB5"),
	Cherry = Kit.color("#D61F3C"),
	Wax = Kit.color("#F6EBD5"),
	Flame = Kit.color("#FFB347"),
	FlameCore = Kit.color("#FFF2B0"),
	Toe = Kit.color("#F28A1E"),
	Zucchini = Kit.color("#3E7A3A"),
	ZucchiniLight = Kit.color("#6FA35A"),
	ZucchiniDark = Kit.color("#2C5A2A"),
	Wisp = Kit.color("#C9B8FF"),
	WispDeep = Kit.color("#8A3DFF"),
	Ember = Kit.color("#FFB04A"),
	EmberRed = Kit.color("#FF3D1F"),
}

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function fade(from: number, to: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, from),
		NumberSequenceKeypoint.new(1, to),
	})
end

-- A flat triangle through three points, from two wedges.
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, color: Color3, material: Enum.Material?, thickness: number?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Make bc the longest edge, so a is the corner the two wedges meet under.
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local depth = thickness or 0.06
	Kit.wedge(parent, CFrame.fromMatrix((a + b) / 2, right, up, back), Vector3.new(depth, height, math.abs(ab:Dot(back))), color, material)
	Kit.wedge(parent, CFrame.fromMatrix((a + c) / 2, -right, up, -back), Vector3.new(depth, height, math.abs(ac:Dot(back))), color, material)
end

local function pointLight(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	return Kit.new("PointLight", parent, { Color = color, Range = range, Brightness = brightness, Shadows = false })
end

-- Googly eyes on a face at depth z (negative, the front), looking the way of
-- each pupil offset.
local function eyes(model: Model, spots: { { number } }, z: number)
	for _, spot in spots do
		local x, y, size, lookX, lookY = spot[1], spot[2], spot[3], spot[4] or 0, spot[5] or 0
		Kit.ball(model, CFrame.new(x, y, z), Vector3.new(size, size, size), C.White)
		Kit.ball(
			model,
			CFrame.new(x + lookX * size * 0.18, y + lookY * size * 0.18, z - size * 0.4),
			Vector3.new(size * 0.45, size * 0.45, size * 0.2),
			C.Pupil
		)
	end
end

-- A big mallet: a long shaft with a barrel head across the top.
local function mallet(name: string, head: Color3, headMaterial: Enum.Material, band: Color3, bandMaterial: Enum.Material, glow: Color3?): Model
	local model = Kit.model(nil, name)
	Kit.post(model, CFrame.new(0, 1.3, 0), 4.2, 0.3, C.MalletWood, M.Wood)
	Kit.post(model, CFrame.new(0, 0.1, 0), 1.0, 0.36, C.Leather, M.Fabric)
	Kit.ball(model, CFrame.new(0, -0.85, 0), Vector3.new(0.45, 0.45, 0.45), band, bandMaterial)
	-- The head runs front to back, so a swing lands face first.
	local across = CFrame.new(0, 3.95, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local tip = Kit.log(model, across, 2.6, 1.7, head, headMaterial)
	tip.Name = "Tip"
	for side = -1, 1, 2 do
		Kit.log(model, across * CFrame.new(side * 0.95, 0, 0), 0.22, 1.8, band, bandMaterial)
		local face = if glow then Kit.color("#FFFFFF") else C.MalletEnd
		Kit.log(model, across * CFrame.new(side * 1.31, 0, 0), 0.02, 1.35, face, if glow then M.Neon else M.Wood)
	end
	Kit.block(model, CFrame.new(0, 3.1, 0), Vector3.new(0.5, 0.12, 0.5), band, bandMaterial)
	if glow then
		-- Glowing cracks across the stone, and a little shimmer.
		for i, angle in { 0.4, 2.1, 3.9, 5.2 } do
			Kit.glow(
				model,
				across * CFrame.Angles(angle, 0, 0) * CFrame.new((i - 2.5) * 0.35, 0.86, 0),
				Vector3.new(0.5, 0.04, 0.08),
				glow
			)
		end
		pointLight(tip, glow, 12, 1.5)
		Kit.new("ParticleEmitter", tip, {
			Texture = SPARKLES,
			Color = ColorSequence.new(glow),
			LightEmission = 1,
			Size = NumberSequence.new(0.25, 0),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 8,
			Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
	return model
end

local Wearables = {}

-- Earned ---------------------------------------------------------------------

Wearables.lantern = {
	Build = function(): Model
		local model = Kit.model(nil, "Lantern")
		for i = 0, 7 do
			Kit.post(model, CFrame.new(0, -0.3 + i * 0.4, 0), 0.4, 0.2, if i % 2 == 0 then C.CandyOrange else C.CandyCream)
		end
		Kit.ball(model, CFrame.new(0, 2.75, 0), Vector3.new(0.32, 0.32, 0.32), P.Metal, M.Metal)
		Kit.block(model, CFrame.new(0, 2.7, -0.45), Vector3.new(0.12, 0.12, 0.9), P.Metal, M.Metal)
		Kit.block(model, CFrame.new(0, 2.52, -0.85), Vector3.new(0.06, 0.36, 0.06), P.Metal, M.Metal)
		local body = Pieces.lantern(model, CFrame.new(0, 1.95, -0.85), 0.75, P.Candle, 12)
		body.Name = "Tip"
		return model
	end,
}

Wearables.witch_cape = {
	Attach = "BodyBackAttachment",
	Build = function(): Model
		local model = Kit.model(nil, "WitchCape")
		-- Hangs from the shoulders, its hem swinging out behind.
		local hang = CFrame.new(0, 0.6, 0.12) * CFrame.Angles(-0.12, 0, 0)
		Kit.block(model, hang * CFrame.new(0, -1.6, 0.05), Vector3.new(2.1, 3.2, 0.08), C.Purple, M.Fabric)
		Kit.block(model, hang * CFrame.new(0, -1.55, -0.02), Vector3.new(1.95, 3.05, 0.04), C.Lining, M.Fabric)
		-- A tall collar standing up behind the neck, flaring out at the top.
		Kit.block(model, CFrame.new(0, 0.95, 0.2) * CFrame.Angles(-0.35, 0, 0), Vector3.new(1.3, 0.75, 0.08), C.Purple, M.Fabric)
		for side = -1, 1, 2 do
			Kit.block(model, CFrame.new(side * 0.72, 0.95, 0.1) * CFrame.Angles(-0.3, side * 0.6, 0), Vector3.new(0.5, 0.7, 0.08), C.Purple, M.Fabric)
			Kit.ball(model, CFrame.new(side * 0.95, 0.6, 0), Vector3.new(0.26, 0.26, 0.26), C.Gold, M.Metal)
		end
		for _, spot in { { -0.5, -0.5 }, { 0.45, -1.1 }, { -0.3, -1.9 }, { 0.55, -2.5 }, { 0.05, -1.5 }, { -0.6, -2.8 } } do
			Kit.glow(
				model,
				hang * CFrame.new(spot[1], spot[2], 0.1) * CFrame.Angles(0, 0, math.pi / 4),
				Vector3.new(0.18, 0.18, 0.03),
				C.Gold
			)
		end
		return model
	end,
}

Wearables.pumpkin_head = {
	Attach = "FaceCenterAttachment",
	HidesHead = true,
	Build = function(): Model
		local model = Kit.model(nil, "PumpkinHead")
		Pieces.jackOLantern(model, CFrame.new(0, -0.95, 0) * CFrame.Angles(0, math.pi, 0), 2.6, true)
		return model
	end,
}

Wearables.wooden_mallet = {
	Swing = { Sound = "Thump", Dust = "#C9A27A", Anim = "Slash" },
	Build = function(): Model
		return mallet("BigWoodenMallet", C.MalletWood, M.Wood, P.Metal, M.Metal)
	end,
}

Wearables.ember_trail = {
	Build = function(top: Attachment, bottom: Attachment)
		Kit.new("Trail", top, {
			Attachment0 = top,
			Attachment1 = bottom,
			Color = ColorSequence.new(C.Ember, C.EmberRed),
			Transparency = NumberSequence.new(0.15, 1),
			WidthScale = NumberSequence.new(1, 0.3),
			Lifetime = 0.7,
			MinLength = 0.05,
			LightEmission = 0.9,
		})
		Kit.new("ParticleEmitter", bottom, {
			Texture = SPARKLES,
			Color = ColorSequence.new(C.Ember, C.EmberRed),
			LightEmission = 1,
			Size = NumberSequence.new(0.2, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 12,
			Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 3, 0),
		})
	end,
}

Wearables.witch_broom = {
	Swing = { Sound = "Whoosh", Dust = "#D9B45A", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "WitchBroom")
		-- A crooked handle with the bristles at the top, so a swing brings
		-- them down like a smack.
		Kit.post(model, CFrame.new(0.03, -0.35, 0) * CFrame.Angles(0, 0, -0.05), 1.5, 0.22, C.BroomWood, M.Wood)
		Kit.post(model, CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, 0.04), 2.4, 0.22, C.BroomWood, M.Wood)
		Kit.ball(model, CFrame.new(0.05, -1.1, 0), Vector3.new(0.32, 0.32, 0.32), C.BroomWood, M.Wood)
		Kit.post(model, CFrame.new(0, 2.85, 0), 0.3, 0.42, C.Purple, M.Fabric)
		local tip = Kit.post(model, CFrame.new(0, 3.75, 0), 1.7, 0.75, C.Straw, M.Fabric)
		tip.Name = "Tip"
		for i = 0, 9 do
			local around = CFrame.new(0, 2.95, 0) * CFrame.Angles(0, i * math.pi / 5, 0)
			Kit.post(model, around * CFrame.Angles(0.3, 0, 0) * CFrame.new(0, 0.9, 0), 1.9, 0.3, C.Straw, M.Fabric)
		end
		return model
	end,
}

Wearables.pumpkling = {
	Build = function(): Model
		local model = Kit.model(nil, "Pumpkling")
		Pieces.jackOLantern(model, CFrame.new(0, -0.55, 0) * CFrame.Angles(0, math.pi, 0), 1.5, true)
		for side = -1, 1, 2 do
			triangle(model, Vector3.new(side * 0.6, 0.15, 0.1), Vector3.new(side * 1.25, 0.55, 0.25), Vector3.new(side * 1.1, -0.1, 0.25), C.Leaf, M.Grass)
		end
		return model
	end,
}

Wearables.werewolf_claws = {
	Swing = { Sound = "Whoosh", Dust = "#EDE6CF", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "WerewolfClaws")
		-- A furry glove over the fist; the wrist is towards +Z in the hold.
		Kit.block(model, CFrame.new(0, 0, 0), Vector3.new(0.75, 0.7, 0.9), C.Fur, M.Fabric)
		Kit.block(model, CFrame.new(0, 0, 0.6), Vector3.new(0.85, 0.8, 0.5), C.FurDark, M.Fabric)
		for side = -1, 1, 2 do
			Kit.wedge(model, CFrame.new(side * 0.3, 0.5, 0.65) * CFrame.Angles(0, math.pi, 0), Vector3.new(0.22, 0.3, 0.35), C.FurDark, M.Fabric)
		end
		for i = 1, 4 do
			local knuckle = CFrame.new(-0.3 + (i - 1) * 0.2, 0.12, -0.45)
			Kit.block(model, knuckle * CFrame.new(0, 0, -0.3), Vector3.new(0.09, 0.14, 0.6), C.Claw)
			local point = Kit.wedge(model, knuckle * CFrame.new(0, -0.04, -0.82) * CFrame.Angles(-0.3, 0, 0), Vector3.new(0.09, 0.14, 0.5), C.Claw)
			if i == 2 then
				point.Name = "Tip"
			end
		end
		return model
	end,
}

Wearables.phantom_aura = {
	Build = function(attachment: Attachment)
		Kit.new("ParticleEmitter", attachment, {
			Texture = SMOKE,
			Color = ColorSequence.new(C.Wisp, C.WispDeep),
			LightEmission = 1,
			Transparency = fade(0.45, 1),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 0.2),
			}),
			Lifetime = NumberRange.new(1.2, 2),
			Rate = 14,
			Speed = NumberRange.new(0.8, 1.6),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 2.5, 0),
			Drag = 1.5,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
		})
		pointLight(attachment, C.WispDeep, 10, 1)
	end,
}

Wearables.moon_saber = {
	Swing = { Sound = "Whoosh", Dust = "#CFE3FF", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "CrescentMoonBlade")
		Kit.post(model, CFrame.new(0, 0.05, 0), 1.0, 0.24, C.Purple, M.Fabric)
		Kit.ball(model, CFrame.new(0, -0.55, 0), Vector3.new(0.34, 0.34, 0.34), C.Gold, M.Metal)
		-- A crescent guard curling up either side of the blade.
		for side = -1, 1, 2 do
			Kit.block(model, CFrame.new(0, 0.62, side * 0.32) * CFrame.Angles(side * 0.5, 0, 0), Vector3.new(0.14, 0.14, 0.5), C.Gold, M.Metal)
			Kit.block(model, CFrame.new(0, 0.85, side * 0.55) * CFrame.Angles(side * 1.1, 0, 0), Vector3.new(0.12, 0.12, 0.34), C.Gold, M.Metal)
		end
		-- The blade curves forward like a crescent moon, narrowing to a point.
		local base = Vector3.new(0, 0.6, 0)
		local tip: BasePart? = nil
		for k = 0, 5 do
			local tilt = k * 0.13
			local length = 0.62
			local direction = Vector3.new(0, math.cos(tilt), -math.sin(tilt))
			local breadth = 0.5 - k * 0.06
			tip = Kit.glow(
				model,
				CFrame.new(base + direction * length / 2) * CFrame.Angles(-tilt, 0, 0),
				Vector3.new(0.1, length + 0.04, breadth),
				C.MoonBlade
			)
			base += direction * length
		end
		local point = tip :: BasePart
		point.Name = "Tip"
		pointLight(point, C.MoonGlow, 10, 1.4)
		return model
	end,
}

-- Deluxe -----------------------------------------------------------------------

Wearables.moonstone_mallet = {
	Swing = { Sound = "Thump", Dust = "#8FB4FF", Anim = "Slash" },
	Build = function(): Model
		return mallet("MoonstoneMallet", C.Moonstone, M.Marble, C.MoonGlow, M.Neon, C.MoonGlow)
	end,
}

Wearables.bat_wings = {
	Attach = "BodyBackAttachment",
	Build = function(): Model
		local model = Kit.model(nil, "NeonBatWings")
		for side = -1, 1, 2 do
			local root = Vector3.new(side * 0.25, 0.5, 0.25)
			local elbow = Vector3.new(side * 1.6, 1.5, 0.55)
			local tip = Vector3.new(side * 2.6, 1.0, 0.7)
			local lowA = Vector3.new(side * 1.1, -0.6, 0.5)
			local lowB = Vector3.new(side * 2.0, -0.3, 0.65)
			Kit.span(model, root, elbow, 0.14, 0.14, P.Bat)
			Kit.span(model, elbow, tip, 0.12, 0.12, P.Bat)
			Kit.ball(model, CFrame.new(elbow), Vector3.new(0.24, 0.24, 0.24), P.Bat)
			for _, piece in { { root, elbow, lowA }, { elbow, lowB, lowA }, { elbow, tip, lowB } } do
				triangle(model, piece[1], piece[2], piece[3], C.BatWing, M.Neon, 0.05)
			end
		end
		local glow = Kit.block(model, CFrame.new(0, 0.4, 0.3), Vector3.new(0.3, 0.3, 0.2), P.Bat)
		pointLight(glow, C.BatWing, 10, 1.2)
		return model
	end,
}

Wearables.ghostfire_crown = {
	Attach = "HatAttachment",
	Build = function(): Model
		local model = Kit.model(nil, "GhostfireCrown")
		local radius = 0.62
		for k = 0, 9 do
			local angle = k * math.pi / 5
			local around = CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.02, radius)
			Kit.block(model, around, Vector3.new(0.42, 0.3, 0.1), C.Gold, M.Metal)
			if k % 2 == 0 then
				Kit.block(model, around * CFrame.new(0, 0.33, 0), Vector3.new(0.12, 0.4, 0.08), C.Gold, M.Metal)
				Kit.glow(model, around * CFrame.new(0, 0.7, 0), Vector3.new(0.2, 0.32, 0.2), C.Ghostfire, true)
			else
				Kit.ball(model, around * CFrame.new(0, 0, 0.05), Vector3.new(0.14, 0.14, 0.14), C.Ruby, M.Glass)
			end
		end
		local flame = Kit.glow(model, CFrame.new(0, 0.45, 0), Vector3.new(0.3, 0.45, 0.3), C.Ghostfire, true)
		pointLight(flame, C.Ghostfire, 9, 1.3)
		Kit.new("ParticleEmitter", flame, {
			Texture = FIRE,
			Color = ColorSequence.new(C.Ghostfire),
			LightEmission = 1,
			Size = NumberSequence.new(0.35, 0),
			Lifetime = NumberRange.new(0.4, 0.7),
			Rate = 18,
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(15, 15),
		})
		return model
	end,
}

Wearables.toxic_aura = {
	Build = function(attachment: Attachment)
		Kit.new("ParticleEmitter", attachment, {
			Texture = FIRE,
			Color = ColorSequence.new(C.Ghostfire, P.EerieGlow),
			LightEmission = 1,
			Transparency = fade(0.2, 1),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 28,
			Speed = NumberRange.new(1.5, 2.5),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 4, 0),
			Drag = 2,
		})
		Kit.new("ParticleEmitter", attachment, {
			Texture = SPARKLES,
			Color = ColorSequence.new(P.EerieGlow),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Lifetime = NumberRange.new(0.8, 1.2),
			Rate = 10,
			Speed = NumberRange.new(2, 3),
			SpreadAngle = Vector2.new(180, 180),
		})
		pointLight(attachment, C.Ghostfire, 12, 1.4)
	end,
}

Wearables.rainbow_trail = {
	Build = function(top: Attachment, bottom: Attachment)
		Kit.new("Trail", top, {
			Attachment0 = top,
			Attachment1 = bottom,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, P.Washes.Purple),
				ColorSequenceKeypoint.new(0.25, P.Washes.Red),
				ColorSequenceKeypoint.new(0.5, P.Washes.Orange),
				ColorSequenceKeypoint.new(0.75, P.Washes.Toxic),
				ColorSequenceKeypoint.new(1, P.Washes.Teal),
			}),
			Transparency = NumberSequence.new(0.05, 1),
			WidthScale = NumberSequence.new(1, 0.6),
			Lifetime = 1.1,
			MinLength = 0.05,
			LightEmission = 1,
		})
	end,
}

-- Brainrot Buddies -----------------------------------------------------------

Wearables.pizza_bat = {
	Build = function(): Model
		local model = Kit.model(nil, "PipistrelloPizzetta")
		triangle(model, Vector3.new(-0.85, 0.6, 0), Vector3.new(0.85, 0.6, 0), Vector3.new(0, -1.0, 0), C.Cheese, M.SmoothPlastic, 0.18)
		Kit.log(model, CFrame.new(0, 0.68, 0), 1.9, 0.32, C.Crust)
		for _, spot in { { -0.35, -0.1 }, { 0.3, -0.15 }, { 0, -0.55 } } do
			Kit.log(model, CFrame.new(spot[1], spot[2], -0.1) * CFrame.Angles(0, math.pi / 2, 0), 0.04, 0.28, C.Pepperoni)
		end
		eyes(model, { { -0.25, 0.32, 0.3, 0.6, 0 }, { 0.25, 0.32, 0.3, -0.6, 0 } }, -0.13)
		Kit.block(model, CFrame.new(0, 0.06, -0.1), Vector3.new(0.3, 0.06, 0.04), C.Pupil)
		for side = -1, 1, 2 do
			local x = side * 0.09
			triangle(model, Vector3.new(x - 0.05, 0.03, -0.12), Vector3.new(x + 0.05, 0.03, -0.12), Vector3.new(x, -0.1, -0.12), C.White, M.SmoothPlastic, 0.03)
			-- Bat wings and ears.
			triangle(model, Vector3.new(side * 0.7, 0.55, 0.05), Vector3.new(side * 1.8, 0.95, 0.15), Vector3.new(side * 1.5, 0.1, 0.15), C.BatSkin)
			triangle(model, Vector3.new(side * 0.7, 0.55, 0.05), Vector3.new(side * 1.5, 0.1, 0.15), Vector3.new(side * 0.75, 0.0, 0.1), C.BatSkin)
			triangle(model, Vector3.new(side * 0.3, 0.8, 0), Vector3.new(side * 0.6, 0.8, 0), Vector3.new(side * 0.45, 1.15, 0), C.BatSkin, M.SmoothPlastic, 0.08)
		end
		return model
	end,
}

Wearables.gelato_ghost = {
	Build = function(): Model
		local model = Kit.model(nil, "FantasminoGelatino")
		for i, ring in { { -0.3, 0.95 }, { -0.6, 0.75 }, { -0.9, 0.52 }, { -1.15, 0.3 } } do
			Kit.post(model, CFrame.new(0, ring[1], 0), if i == 4 then 0.25 else 0.3, ring[2], C.Waffle)
		end
		local scoop = Kit.ball(model, CFrame.new(0, 0.35, 0), Vector3.new(1.25, 1.3, 1.25), C.Mint)
		for k = 0, 7 do
			local angle = k * math.pi / 4
			Kit.ball(model, CFrame.new(math.sin(angle) * 0.55, -0.12, math.cos(angle) * 0.55), Vector3.new(0.34, 0.34, 0.34), C.Mint)
		end
		for side = -1, 1, 2 do
			Kit.ball(model, CFrame.new(side * 0.22, 0.5, -0.58), Vector3.new(0.16, 0.26, 0.08), C.Pupil)
			Kit.ball(model, CFrame.new(side * 0.38, 0.3, -0.5), Vector3.new(0.16, 0.1, 0.06), C.Blush)
			Kit.ball(model, CFrame.new(side * 0.68, 0.25, -0.05), Vector3.new(0.3, 0.22, 0.22), C.Mint)
		end
		Kit.ball(model, CFrame.new(0, 0.22, -0.6), Vector3.new(0.14, 0.14, 0.08), C.Pupil)
		Kit.ball(model, CFrame.new(0, 1.08, 0), Vector3.new(0.3, 0.3, 0.3), C.Cherry, M.Glass)
		Kit.post(model, CFrame.new(0.05, 1.33, 0) * CFrame.Angles(0, 0, -0.3), 0.3, 0.04, P.Stem)
		pointLight(scoop, C.Mint, 7, 0.8)
		return model
	end,
}

Wearables.candle_buddy = {
	Build = function(): Model
		local model = Kit.model(nil, "CandelinoWobblino")
		Kit.post(model, CFrame.new(0, -0.15, 0), 1.5, 0.8, C.Wax)
		for k = 0, 5 do
			local angle = k * math.pi / 3 + 0.3
			Kit.ball(model, CFrame.new(math.sin(angle) * 0.34, 0.58, math.cos(angle) * 0.34), Vector3.new(0.24, 0.2, 0.24), C.Wax)
			if k % 2 == 0 then
				Kit.block(
					model,
					CFrame.new(math.sin(angle) * 0.4, 0.3 - k * 0.04, math.cos(angle) * 0.4) * CFrame.Angles(0, angle, 0),
					Vector3.new(0.12, 0.5, 0.06),
					C.Wax
				)
			end
		end
		Kit.post(model, CFrame.new(0, 0.72, 0), 0.25, 0.06, C.Pupil)
		local flame = Kit.glow(model, CFrame.new(0, 1.02, 0), Vector3.new(0.32, 0.52, 0.32), C.Flame, true)
		Kit.glow(model, CFrame.new(0, 0.97, 0), Vector3.new(0.16, 0.28, 0.16), C.FlameCore, true)
		Kit.light(flame, C.Flame, 8, 1.3, true)
		-- One eye looks up, the other down.
		eyes(model, { { -0.18, 0.2, 0.34, 0.5, 0.7 }, { 0.18, 0.2, 0.34, -0.3, -0.7 } }, -0.38)
		Kit.ball(model, CFrame.new(0, -0.15, -0.4), Vector3.new(0.2, 0.1, 0.06), C.Pupil)
		for side = -1, 1, 2 do
			Kit.ball(model, CFrame.new(side * 0.2, -0.95, -0.08), Vector3.new(0.3, 0.18, 0.4), C.Toe)
			Kit.log(model, CFrame.new(side * 0.52, -0.1, 0) * CFrame.Angles(0, 0, side * 0.5), 0.36, 0.08, C.Wax)
		end
		return model
	end,
}

Wearables.zombie_zucchini = {
	Build = function(): Model
		local model = Kit.model(nil, "ZucchinoZombino")
		Kit.ball(model, CFrame.new(0, -0.1, 0), Vector3.new(0.85, 2.0, 0.85), C.Zucchini)
		for _, patch in { { -0.3, -0.5, -0.3 }, { 0.32, -0.2, 0.15 }, { 0.1, -0.75, 0.33 } } do
			Kit.ball(model, CFrame.new(patch[1], patch[2], patch[3]), Vector3.new(0.3, 0.38, 0.3), C.ZucchiniDark)
		end
		Kit.post(model, CFrame.new(0, 0.95, 0), 0.25, 0.3, P.Stem)
		triangle(model, Vector3.new(0.05, 1.05, 0), Vector3.new(0.5, 1.25, 0.1), Vector3.new(0.35, 0.95, 0.1), C.Leaf, M.Grass)
		eyes(model, { { -0.16, 0.38, 0.36, 0.4, 0.2 }, { 0.2, 0.42, 0.22, -0.2, -0.3 } }, -0.33)
		Kit.block(model, CFrame.new(0, 0.05, -0.41), Vector3.new(0.4, 0.05, 0.04), C.Pupil)
		for i = -1, 1 do
			Kit.block(model, CFrame.new(i * 0.13, 0.05, -0.42), Vector3.new(0.03, 0.14, 0.03), C.Pupil)
		end
		-- Arms out in front, the way zombies walk.
		for side = -1, 1, 2 do
			Kit.log(model, CFrame.new(side * 0.42, 0, -0.45) * CFrame.Angles(0, math.pi / 2, 0), 0.8, 0.16, C.ZucchiniLight)
			Kit.ball(model, CFrame.new(side * 0.42, 0, -0.88), Vector3.new(0.24, 0.24, 0.24), C.ZucchiniLight)
		end
		local glow = Kit.block(model, CFrame.new(0, -0.1, 0), Vector3.new(0.2, 0.2, 0.2), C.Zucchini)
		pointLight(glow, P.EerieGlow, 6, 0.8)
		return model
	end,
}

-- Legendary --------------------------------------------------------------------

Wearables.thunder_hammer = {
	Swing = { Sound = "Thump", Dust = "#5FC8FF", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "StormStoneHammer")
		Kit.post(model, CFrame.new(0, 1.0, 0), 4.0, 0.32, P.DarkWood, M.Wood)
		for _, y in { -0.6, 0.6, 2.4 } do
			Kit.post(model, CFrame.new(0, y, 0), 0.16, 0.42, C.Bronze, M.Metal)
		end
		Kit.post(model, CFrame.new(0, 0, 0), 0.9, 0.38, C.Leather, M.Fabric)
		Kit.ball(model, CFrame.new(0, -1.05, 0), Vector3.new(0.5, 0.5, 0.5), C.Bronze, M.Metal)
		-- An eight-sided stone head, running front to back, with bronze caps
		-- and glowing runes.
		local head = CFrame.new(0, 3.6, 0)
		local tip = Kit.block(model, head, Vector3.new(1.4, 1.4, 2.4), C.StormStone, M.Slate)
		tip.Name = "Tip"
		Kit.block(model, head * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.4, 1.4, 2.4), C.StormStone, M.Slate)
		for side = -1, 1, 2 do
			Kit.log(model, head * CFrame.new(0, 0, side * 1.25) * CFrame.Angles(0, math.pi / 2, 0), 0.2, 1.6, C.Bronze, M.Metal)
			Kit.glow(model, head * CFrame.new(side * 0.72, 0, 0), Vector3.new(0.04, 0.9, 0.12), C.Lightning)
			Kit.glow(model, head * CFrame.new(side * 0.72, 0.15, 0.5) * CFrame.Angles(0.6, 0, 0), Vector3.new(0.04, 0.6, 0.1), C.Lightning)
			Kit.glow(model, head * CFrame.new(side * 0.72, -0.1, -0.5) * CFrame.Angles(-0.7, 0, 0), Vector3.new(0.04, 0.6, 0.1), C.Lightning)
		end
		pointLight(tip, C.Lightning, 14, 1.8)
		Kit.new("ParticleEmitter", tip, {
			Texture = SPARKLES,
			Color = ColorSequence.new(C.Lightning, C.White),
			LightEmission = 1,
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(0.15, 0.35),
			Rate = 25,
			Speed = NumberRange.new(4, 7),
			SpreadAngle = Vector2.new(180, 180),
		})
		return model
	end,
}

Wearables.ghost_blade = {
	Swing = { Sound = "Whoosh", Dust = "#7FF7FF", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "GhostlightBlade")
		Kit.post(model, CFrame.new(0, 0, 0), 1.0, 0.22, C.Lacquer, M.Fabric)
		Pieces.jackOLantern(model, CFrame.new(0, -0.85, 0) * CFrame.Angles(0, math.pi, 0), 0.5)
		-- A guard shaped like bat wings, then a see-through spectral blade.
		Kit.block(model, CFrame.new(0, 0.58, 0), Vector3.new(0.2, 0.16, 0.5), P.Metal, M.Metal)
		for side = -1, 1, 2 do
			triangle(model, Vector3.new(0, 0.66, side * 0.2), Vector3.new(0, 0.95, side * 0.95), Vector3.new(0, 0.5, side * 0.75), P.Bat, M.Metal, 0.1)
		end
		local core = Kit.glow(model, CFrame.new(0, 2.4, 0), Vector3.new(0.06, 3.5, 0.18), C.Spirit)
		local blade = Kit.block(model, CFrame.new(0, 2.45, 0), Vector3.new(0.14, 3.6, 0.5), C.Spirit, M.ForceField)
		blade.Name = "Tip"
		triangle(model, Vector3.new(0, 4.25, -0.25), Vector3.new(0, 4.25, 0.25), Vector3.new(0, 4.9, 0), C.Spirit, M.Neon, 0.1)
		pointLight(core, C.Spirit, 12, 1.5)
		Kit.new("ParticleEmitter", blade, {
			Texture = SMOKE,
			Color = ColorSequence.new(C.Spirit),
			LightEmission = 1,
			Transparency = fade(0.6, 1),
			Size = NumberSequence.new(0.4, 0.9),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 10,
			Speed = NumberRange.new(0.2, 0.5),
			SpreadAngle = Vector2.new(180, 180),
		})
		return model
	end,
}

Wearables.reaper_scythe = {
	Swing = { Sound = "Whoosh", Dust = "#B26BFF", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "ReapersScythe")
		Kit.post(model, CFrame.new(0.02, -1.0, 0) * CFrame.Angles(0, 0, -0.04), 2.2, 0.24, P.DarkWood, M.Wood)
		Kit.post(model, CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, 0.03), 2.4, 0.24, P.DarkWood, M.Wood)
		Kit.post(model, CFrame.new(0.02, 3.3, 0) * CFrame.Angles(0, 0, -0.03), 2.0, 0.24, P.DarkWood, M.Wood)
		Kit.post(model, CFrame.new(0, 0, 0), 0.8, 0.3, C.Leather, M.Fabric)
		Kit.ball(model, CFrame.new(0, 4.4, 0), Vector3.new(0.36, 0.36, 0.36), C.ReaperEdge, M.Glass)
		Kit.block(model, CFrame.new(0, 4.05, -0.15), Vector3.new(0.3, 0.3, 0.5), P.Metal, M.Metal)
		-- The blade sweeps forward from the top and curls down.
		local base = Vector3.new(0, 4.05, -0.35)
		local tip: BasePart? = nil
		for k = 0, 4 do
			local drop = k * 0.2
			local length = 0.6
			local direction = Vector3.new(0, -math.sin(drop), -math.cos(drop))
			local breadth = 0.75 - k * 0.12
			local frame = CFrame.new(base + direction * length / 2) * CFrame.Angles(-drop, 0, 0)
			tip = Kit.block(model, frame, Vector3.new(0.08, breadth, length + 0.04), C.Steel, M.Metal)
			Kit.glow(model, frame * CFrame.new(0, -breadth / 2, 0), Vector3.new(0.1, 0.06, length + 0.04), C.ReaperEdge)
			base += direction * length
		end
		local point = tip :: BasePart
		point.Name = "Tip"
		pointLight(point, C.ReaperEdge, 10, 1.4)
		return model
	end,
}

Wearables.drowned_trident = {
	Swing = { Sound = "Whoosh", Dust = "#3DF5D0", Anim = "Lunge" },
	Build = function(): Model
		local model = Kit.model(nil, "DrownedTrident")
		Kit.post(model, CFrame.new(0, 1.05, 0), 5.1, 0.24, C.SeaBronze, M.Metal)
		for _, y in { -0.9, 1.4, 2.6 } do
			Kit.post(model, CFrame.new(0, y, 0) * CFrame.Angles(0.15, 0, 0.1), 0.3, 0.32, C.Seaweed, M.Grass)
		end
		Kit.block(model, CFrame.new(0, 3.7, 0), Vector3.new(1.45, 0.2, 0.22), C.SeaBronze, M.Metal)
		local tip: BasePart? = nil
		for _, x in { -0.62, 0, 0.62 } do
			local height = if x == 0 then 1.4 else 1.0
			local prong = Kit.post(model, CFrame.new(x, 3.7 + height / 2, 0), height, 0.16, C.SeaBronze, M.Metal)
			local top = 3.7 + height
			triangle(model, Vector3.new(x - 0.16, top, 0), Vector3.new(x + 0.16, top, 0), Vector3.new(x, top + 0.45, 0), C.SeaBronze, M.Metal, 0.12)
			Kit.glow(model, CFrame.new(x, 3.85, -0.12), Vector3.new(0.14, 0.14, 0.14), C.SeaGlow, true)
			if x == 0 then
				tip = prong
			end
		end
		local point = tip :: BasePart
		point.Name = "Tip"
		pointLight(point, C.SeaGlow, 12, 1.4)
		Kit.new("ParticleEmitter", point, {
			Texture = SPARKLES,
			Color = ColorSequence.new(C.SeaGlow),
			LightEmission = 0.6,
			Size = NumberSequence.new(0.15, 0.3),
			Transparency = fade(0.3, 1),
			Lifetime = NumberRange.new(0.8, 1.4),
			Rate = 8,
			Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -2, 0),
		})
		return model
	end,
}

Wearables.foxfire_fan = {
	Swing = { Sound = "Whoosh", Dust = "#4FA8FF", Anim = "Slash" },
	Build = function(): Model
		local model = Kit.model(nil, "FoxfireFan")
		local ribs = 7
		local reach = 2.2
		local spread = 1.2
		local ends = {}
		for i = 0, ribs - 1 do
			local angle = -spread + i * (2 * spread / (ribs - 1))
			local rib = CFrame.Angles(0, 0, -angle)
			local outer = i == 0 or i == ribs - 1
			Kit.block(model, rib * CFrame.new(0, reach / 2, 0), Vector3.new(if outer then 0.14 else 0.08, reach, 0.08), C.Lacquer, M.Wood)
			ends[i + 1] = (rib * CFrame.new(0, reach - 0.05, 0)).Position
			local flame = Kit.glow(model, rib * CFrame.new(0, reach + 0.12, 0), Vector3.new(0.16, 0.26, 0.16), C.FoxFire, true)
			if i == 3 then
				flame.Name = "Tip"
				pointLight(flame, C.FoxFire, 12, 1.5)
			end
		end
		local hub = Vector3.new(0, 0.5, -0.02)
		for i = 1, ribs - 1 do
			triangle(model, hub, ends[i] - Vector3.new(0, 0, 0.02), ends[i + 1] - Vector3.new(0, 0, 0.02), if i % 2 == 0 then C.CandyCream else C.FanRed, M.Fabric, 0.03)
		end
		Kit.ball(model, CFrame.new(0, 0, 0), Vector3.new(0.3, 0.3, 0.3), C.Gold, M.Metal)
		return model
	end,
}

return Wearables
