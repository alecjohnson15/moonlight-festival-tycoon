-- The cosmetics in Config/Cosmetics, built from parts. Hats are built around
-- the top of the head (origin at the head's centre, front -Z), backs around
-- the middle of the back (origin at the torso's centre), pets standing on
-- the ground (origin at their feet). Trails are Trail instances, made by
-- Wearables.trail. Each model's PrimaryPart is its "Root".

local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)

local Wearables = {}

local FABRIC = Enum.Material.Fabric
local ICE = Enum.Material.Ice

local function model(parent: Instance?, name: string): (Model, Part)
	local container = Kit.model(parent, name)
	local root = Kit.block(container, CFrame.new(), Vector3.new(0.2, 0.2, 0.2), Palette.White)
	root.Name = "Root"
	root.Transparency = 1
	container.PrimaryPart = root
	return container, root
end

local hats = {}

function hats.BobbleHat(m: Model)
	Kit.ball(m, CFrame.new(0, 0.55, 0), Vector3.new(1.35, 1, 1.35), Color3.fromRGB(229, 72, 77), FABRIC)
	Kit.post(m, CFrame.new(0, 0.35, 0), 0.35, 1.38, Palette.White, FABRIC)
	Kit.ball(m, CFrame.new(0, 1.15, 0), Vector3.new(0.55, 0.55, 0.55), Palette.White, FABRIC)
end

function hats.Earmuffs(m: Model)
	Kit.span(m, Vector3.new(-0.7, 0.2, 0), Vector3.new(0, 0.75, 0), 0.15, 0.15, Color3.fromRGB(242, 167, 195))
	Kit.span(m, Vector3.new(0, 0.75, 0), Vector3.new(0.7, 0.2, 0), 0.15, 0.15, Color3.fromRGB(242, 167, 195))
	for side = -1, 1, 2 do
		Kit.ball(m, CFrame.new(side * 0.72, 0, 0), Vector3.new(0.45, 0.75, 0.75), Color3.fromRGB(242, 167, 195), FABRIC)
	end
end

function hats.MinerHelmet(m: Model)
	Kit.ball(m, CFrame.new(0, 0.45, 0), Vector3.new(1.4, 0.9, 1.4), Color3.fromRGB(245, 197, 66))
	Kit.post(m, CFrame.new(0, 0.2, 0), 0.12, 1.7, Color3.fromRGB(245, 197, 66))
	local lamp = Kit.glow(m, CFrame.new(0, 0.55, -0.68), Vector3.new(0.4, 0.4, 0.15), Palette.Flame, true)
	Kit.light(lamp, Palette.Flame, 10, 0.8)
end

function hats.AntlerBeanie(m: Model)
	Kit.ball(m, CFrame.new(0, 0.5, 0), Vector3.new(1.35, 0.95, 1.35), Color3.fromRGB(139, 90, 60), FABRIC)
	for side = -1, 1, 2 do
		Kit.span(m, Vector3.new(side * 0.4, 0.8, 0), Vector3.new(side * 0.8, 1.5, 0), 0.15, 0.15, Palette.Plank)
		Kit.span(m, Vector3.new(side * 0.65, 1.2, 0), Vector3.new(side * 0.45, 1.55, -0.1), 0.12, 0.12, Palette.Plank)
	end
end

function hats.PolarBearHat(m: Model)
	Kit.ball(m, CFrame.new(0, 0.5, 0), Vector3.new(1.45, 1, 1.45), Palette.White, FABRIC)
	for side = -1, 1, 2 do
		Kit.ball(m, CFrame.new(side * 0.55, 0.95, 0), Vector3.new(0.4, 0.4, 0.25), Palette.White, FABRIC)
		Kit.ball(m, CFrame.new(side * 0.25, 0.75, -0.62), Vector3.new(0.14, 0.14, 0.1), Palette.Black)
	end
	Kit.ball(m, CFrame.new(0, 0.55, -0.7), Vector3.new(0.4, 0.3, 0.25), Palette.SnowShade, FABRIC)
	Kit.ball(m, CFrame.new(0, 0.6, -0.82), Vector3.new(0.14, 0.1, 0.08), Palette.Black)
end

function hats.YetiHood(m: Model)
	Kit.ball(m, CFrame.new(0, 0.35, 0.1), Vector3.new(1.6, 1.4, 1.6), Color3.fromRGB(221, 231, 242), FABRIC)
	for side = -1, 1, 2 do
		Kit.wedge(
			m,
			CFrame.new(side * 0.55, 1.1, 0) * CFrame.Angles(0, 0, side * -0.5),
			Vector3.new(0.25, 0.6, 0.3),
			Palette.Ice,
			ICE
		)
	end
end

function hats.IcicleCrown(m: Model)
	Kit.post(m, CFrame.new(0, 0.45, 0), 0.25, 1.3, Palette.IceGlow, Enum.Material.Neon)
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		local spike = Kit.glow(
			m,
			CFrame.new(math.cos(angle) * 0.55, 0.85, math.sin(angle) * 0.55),
			Vector3.new(0.18, 0.7, 0.18),
			Palette.IceGlow
		)
		spike.Transparency = 0.15
	end
end

local backs = {}

function backs.Snowboard(m: Model)
	Kit.block(
		m,
		CFrame.new(0, 0, 0.7) * CFrame.Angles(0, 0, 0.2),
		Vector3.new(1, 3.6, 0.15),
		Color3.fromRGB(61, 123, 255)
	)
	Kit.block(m, CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, 0.2), Vector3.new(1.02, 0.4, 0.15), Palette.White)
end

function backs.LanternPack(m: Model)
	Kit.block(m, CFrame.new(0, -0.1, 0.75), Vector3.new(1.4, 1.6, 0.7), Color3.fromRGB(192, 122, 58), FABRIC)
	local lamp = Kit.glow(m, CFrame.new(0.75, -0.9, 0.95), Vector3.new(0.35, 0.45, 0.35), Palette.Warm, true)
	Kit.light(lamp, Palette.Warm, 8, 0.7)
end

function backs.FrostWings(m: Model)
	for side = -1, 1, 2 do
		local wing = Kit.block(
			m,
			CFrame.new(side * 1.2, 0.3, 0.75) * CFrame.Angles(0, side * 0.35, side * 0.5),
			Vector3.new(2.2, 1.2, 0.08),
			Palette.Frost,
			Enum.Material.Glass
		)
		wing.Transparency = 0.35
	end
end

function backs.AuroraCape(m: Model)
	local colors = Palette.Aurora
	for index = 1, 3 do
		local strip = Kit.glow(
			m,
			CFrame.new((index - 2) * 0.55, -0.6, 0.62 + index * 0.02) * CFrame.Angles(-0.12, 0, 0),
			Vector3.new(0.6, 2.6, 0.06),
			colors[index]
		)
		strip.Transparency = 0.25
	end
end

local pets = {}

function pets.HuskyPup(m: Model)
	Kit.ball(m, CFrame.new(0, 1, 0.3), Vector3.new(1.4, 1.2, 2), Color3.fromRGB(154, 166, 184), FABRIC)
	Kit.ball(m, CFrame.new(0, 1.7, -0.7), Vector3.new(1.2, 1.1, 1.1), Color3.fromRGB(154, 166, 184), FABRIC)
	Kit.ball(m, CFrame.new(0, 1.55, -1.2), Vector3.new(0.6, 0.5, 0.6), Palette.White, FABRIC)
	for side = -1, 1, 2 do
		Kit.wedge(m, CFrame.new(side * 0.35, 2.35, -0.6), Vector3.new(0.25, 0.5, 0.35), Color3.fromRGB(154, 166, 184))
		Kit.ball(m, CFrame.new(side * 0.25, 1.85, -1.2), Vector3.new(0.18, 0.18, 0.1), Color3.fromRGB(100, 170, 255))
		Kit.post(m, CFrame.new(side * 0.35, 0.3, 0.3), 0.6, 0.35, Palette.White)
	end
	Kit.ball(m, CFrame.new(0, 1.65, -1.5), Vector3.new(0.2, 0.15, 0.1), Palette.Black)
	Kit.ball(m, CFrame.new(0, 1.4, 1.3), Vector3.new(0.35, 0.35, 0.8), Palette.White, FABRIC)
end

function pets.SnowOwl(m: Model)
	Kit.ball(m, CFrame.new(0, 3.2, 0), Vector3.new(1.2, 1.4, 1.1), Palette.White, FABRIC)
	for side = -1, 1, 2 do
		Kit.ball(m, CFrame.new(side * 0.25, 3.5, -0.5), Vector3.new(0.35, 0.35, 0.1), Color3.fromRGB(242, 201, 76))
		Kit.ball(m, CFrame.new(side * 0.25, 3.5, -0.56), Vector3.new(0.15, 0.15, 0.06), Palette.Black)
		Kit.ball(m, CFrame.new(side * 0.6, 3.1, 0.1), Vector3.new(0.3, 0.9, 0.7), Palette.SnowShade, FABRIC)
	end
	Kit.wedge(m, CFrame.new(0, 3.3, -0.58) * CFrame.Angles(math.pi, 0, 0), Vector3.new(0.15, 0.2, 0.1), Palette.Black)
end

function pets.Penguin(m: Model)
	Kit.ball(m, CFrame.new(0, 1.1, 0), Vector3.new(1.3, 1.9, 1.2), Color3.fromRGB(43, 47, 58))
	Kit.ball(m, CFrame.new(0, 1, -0.3), Vector3.new(0.95, 1.5, 0.7), Palette.White)
	Kit.ball(m, CFrame.new(0, 2.25, -0.05), Vector3.new(0.95, 0.85, 0.9), Color3.fromRGB(43, 47, 58))
	Kit.wedge(
		m,
		CFrame.new(0, 2.15, -0.55) * CFrame.Angles(-math.pi / 2, 0, 0),
		Vector3.new(0.25, 0.4, 0.2),
		Color3.fromRGB(255, 159, 67)
	)
	for side = -1, 1, 2 do
		Kit.ball(m, CFrame.new(side * 0.22, 2.4, -0.42), Vector3.new(0.14, 0.16, 0.06), Palette.White)
		Kit.ball(m, CFrame.new(side * 0.3, 0.08, -0.25), Vector3.new(0.4, 0.15, 0.55), Color3.fromRGB(255, 159, 67))
		Kit.ball(m, CFrame.new(side * 0.68, 1.2, 0), Vector3.new(0.2, 0.9, 0.5), Color3.fromRGB(43, 47, 58))
	end
	-- A tiny scarf.
	Kit.post(m, CFrame.new(0, 1.85, 0), 0.25, 1.15, Palette.Cloth, FABRIC)
end

function pets.ArcticFox(m: Model)
	Kit.ball(m, CFrame.new(0, 0.9, 0.2), Vector3.new(1.1, 1, 1.8), Palette.White, FABRIC)
	Kit.ball(m, CFrame.new(0, 1.5, -0.8), Vector3.new(0.95, 0.85, 0.9), Palette.White, FABRIC)
	Kit.wedge(
		m,
		CFrame.new(0, 1.4, -1.35) * CFrame.Angles(-math.pi / 2, 0, 0),
		Vector3.new(0.4, 0.5, 0.35),
		Palette.White,
		FABRIC
	)
	Kit.ball(m, CFrame.new(0, 1.42, -1.62), Vector3.new(0.14, 0.12, 0.08), Palette.Black)
	for side = -1, 1, 2 do
		Kit.wedge(m, CFrame.new(side * 0.3, 2.05, -0.75), Vector3.new(0.25, 0.5, 0.25), Palette.White)
		Kit.ball(m, CFrame.new(side * 0.22, 1.65, -1.2), Vector3.new(0.14, 0.16, 0.06), Palette.Black)
		Kit.post(m, CFrame.new(side * 0.3, 0.25, 0.2), 0.5, 0.3, Palette.White)
	end
	Kit.ball(m, CFrame.new(0, 1.2, 1.4) * CFrame.Angles(0.6, 0, 0), Vector3.new(0.8, 0.8, 1.8), Palette.White, FABRIC)
end

-- Builds a hat, back or pet by its id. Returns nil for trails and unknown
-- ids.
function Wearables.build(parent: Instance?, id: string, slot: string): Model?
	local builder = if slot == "Hat"
		then hats[id]
		elseif slot == "Back" then backs[id]
		elseif slot == "Pet" then pets[id]
		else nil
	if not builder then
		return nil
	end
	local m = model(parent, id)
	builder(m)
	return m
end

-- The colours of each trail, top to bottom of the ribbon.
local TRAILS = {
	SnowflakeTrail = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(191, 239, 255) },
	EmberTrail = { Color3.fromRGB(255, 209, 102), Color3.fromRGB(255, 122, 46) },
	SparkleTrail = { Color3.fromRGB(255, 229, 138), Color3.fromRGB(143, 216, 255) },
	AuroraTrail = { Color3.fromRGB(92, 242, 176), Color3.fromRGB(124, 92, 255) },
}

-- A trail between two attachments, glowing in the trail's colours.
function Wearables.trail(id: string, a: Attachment, b: Attachment): Trail?
	local colors = TRAILS[id]
	if not colors then
		return nil
	end
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Color = ColorSequence.new(colors[1], colors[2])
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.7
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	return trail
end

Wearables.Trails = TRAILS

return Wearables
