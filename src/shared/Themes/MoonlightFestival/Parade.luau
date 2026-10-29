-- The Moonlight Parade's look (Config/Parade): the floats that circle the
-- Moonlight Wheel, the ghosts marching between them, and the lanterns they
-- let go. Each client makes its own (client/Parade) while a parade is on, so
-- they are only for show: anchored, never collide or touch, cast no shadow
-- and are skipped by raycasts.
--
-- Floats and marchers are built round the origin on the ground, facing
-- forward (-Z), the way they travel. Lanterns are centred on the origin.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Pieces = require(script.Parent.Pieces)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

local Parade = {}

-- The lanterns' warm glow, and the colours of the confetti when the meter
-- fills.
Parade.LanternColor = P.Moonlight:Lerp(P.Glow, 0.4)
Parade.Confetti = { P.Moonlight, W.Orange, W.Purple, W.Toxic, W.Teal, P.Candle }

local function finish(model: Model): Model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		elseif part:IsA("Light") then
			part:Destroy()
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- A wagon with wheels and a skirt, the base every float stands on.
local function wagon(model: Model, color: Color3)
	Kit.block(model, CFrame.new(0, 1.2, 0), V(4.4, 0.6, 6), P.Roof, M.WoodPlanks)
	Kit.block(model, CFrame.new(0, 0.8, 0), V(4.5, 0.5, 6.1), color, M.Fabric)
	for _, z in { -2.2, 2.2 } do
		Kit.log(model, CFrame.new(0, 0.55, z), 4.8, 1.1, P.DarkWood, M.Wood)
	end
end

-- The floats, in parade order: a giant grinning pumpkin, a crescent moon with
-- a witch on it, and a haunted house with a ghost at the window.
local FLOATS: { (Model) -> () } = {
	function(model)
		wagon(model, W.Orange)
		Pieces.jackOLantern(model, CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.pi, 0), 3.6, false)
		for side = -1, 1, 2 do
			Pieces.pumpkin(model, CFrame.new(side * 1.5, 1.5, 2.2), 1.2)
		end
	end,
	function(model)
		wagon(model, W.Purple)
		local moon = CFrame.new(0, 5, 0.6)
		local points = {}
		for i = 0, 6 do
			local angle = math.rad(-120 + i * 40)
			table.insert(points, (moon * CFrame.new(0, math.cos(angle) * 2.6, math.sin(angle) * 2.6)).Position)
		end
		for i = 1, #points - 1 do
			Kit.span(model, points[i], points[i + 1], 0.6, 0.9 - math.abs(i - 3.5) * 0.15, P.Moonlight, M.Neon)
		end
		Kit.post(model, CFrame.new(0, 2.3, 0.6), 1.6, 0.3, P.DarkWood, M.Wood)
		-- The witch sits on the moon's lower horn.
		local seat = moon * CFrame.new(0, -1.6, -1.6)
		Kit.ball(model, seat * CFrame.new(0, 0.4, 0), V(0.9, 1.1, 0.8), P.Robes[1])
		Kit.ball(model, seat * CFrame.new(0, 1.25, 0), V(0.7, 0.7, 0.7), P.WitchSkin)
		Kit.post(model, seat * CFrame.new(0, 1.6, 0), 0.08, 1.3, P.Bat)
		Kit.post(model, seat * CFrame.new(0, 1.95, 0), 0.6, 0.55, P.Bat)
	end,
	function(model)
		wagon(model, W.Toxic)
		local boards = P.DarkStone:Lerp(P.Roof, 0.3)
		Kit.block(model, CFrame.new(0, 3.2, 0.4), V(3.6, 3.4, 3.6), boards, M.WoodPlanks)
		Pieces.roof(model, CFrame.new(0, 0, 0.4), 4, 4, 4.9, 1.8, P.Roof, 0.15)
		Kit.glow(model, CFrame.new(0, 3.4, -1.42), V(1.2, 1.4, 0.1), W.Toxic)
		Pieces.ghost(model, CFrame.new(0, 3.4, -1.8) * CFrame.Angles(0, math.pi, 0), 1)
	end,
}

Parade.FloatCount = #FLOATS

-- Float index (from 1), facing -Z.
function Parade.float(index: number): Model
	local model = Kit.model(nil, "ParadeFloat")
	FLOATS[(index - 1) % #FLOATS + 1](model)
	return finish(model)
end

-- A ghost marching between floats, carrying a lantern on a pole.
function Parade.marcher(): Model
	local model = Kit.model(nil, "ParadeGhost")
	Pieces.ghost(model, CFrame.new(0, 2, 0) * CFrame.Angles(0, math.pi, 0), 1.6)
	Kit.post(model, CFrame.new(0.9, 2.2, -0.3), 3, 0.1, P.DarkWood, M.Wood)
	Pieces.lantern(model, CFrame.new(0.9, 3.9, -0.3), 0.6, Parade.LanternColor)
	return finish(model)
end

-- A paper lantern to catch: a glowing round body with a little top and a
-- tassel, lit so it shows in the courtyard. Its body is the PrimaryPart.
function Parade.lantern(): Model
	local model = Kit.model(nil, "ParadeLantern")
	local body = Kit.glow(model, CFrame.new(), V(1.5, 1.7, 1.5), Parade.LanternColor, true)
	body.Name = "Body"
	body.Transparency = 0.1
	Kit.post(model, CFrame.new(0, 0.95, 0), 0.25, 0.7, W.Red)
	Kit.post(model, CFrame.new(0, -0.95, 0), 0.25, 0.7, W.Red)
	Kit.block(model, CFrame.new(0, -1.4, 0), V(0.12, 0.6, 0.12), W.Red, M.Fabric)
	finish(model)
	Kit.light(body, Parade.LanternColor, 10, 1.4)
	Kit.new("ParticleEmitter", body, {
		Name = "Sparkles",
		Rate = 4,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.2, 0),
		Color = ColorSequence.new(Parade.LanternColor),
		LightEmission = 1,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	})
	model.PrimaryPart = body
	return model
end

return Parade
