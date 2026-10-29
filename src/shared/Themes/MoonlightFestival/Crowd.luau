-- The crowd on a plot: visitors in Halloween costume who walk between the
-- stall and the attractions, and the goods carried along the production
-- chain. Each client draws its own (see client/PlotActivity), so they are only
-- for show and kept light: anchored, never collide or touch, cast no shadow
-- and are skipped by raycasts.
--
-- Each one is built round the origin, which becomes its pivot, and faces
-- forward (-Z) the way CFrame.lookAt points things. Visitors stand with their
-- feet at the origin, and their Gait attribute tells the client how they move:
-- "Hop" for walkers, "Float" for ghosts. Goods are centred on the origin.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

local CLOTHES = Kit.palette({ List = Theme.VisitorColors }).List

local Crowd = {}

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- A sheet ghost with a wavy hem and an "ooh" mouth, floating along.
local function ghost(model: Model)
	local sheet = P.Ghost
	local parts = {
		Kit.ball(model, at(0, 1.6, 0), V(1.9, 2.4, 1.9), sheet),
		Kit.ball(model, at(0, 2.75, 0), V(1.6, 1.5, 1.6), sheet),
	}
	for i = 0, 5 do
		local angle = i * math.pi / 3
		table.insert(
			parts,
			Kit.ball(model, at(math.cos(angle) * 0.62, 0.5, math.sin(angle) * 0.62), V(0.7, 0.6, 0.7), sheet)
		)
	end
	for side = -1, 1, 2 do
		Kit.ball(model, at(side * 0.3, 2.85, -0.71), V(0.26, 0.4, 0.14), P.Eye)
		local arm =
			Kit.ball(model, at(side * 0.95, 1.9, -0.15) * CFrame.Angles(0, 0, side * 0.6), V(0.55, 0.35, 0.35), sheet)
		table.insert(parts, arm)
	end
	Kit.ball(model, at(0, 2.35, -0.79), V(0.3, 0.38, 0.12), P.Eye)
	for _, part in parts do
		part.Transparency = 0.15
	end
	return "Float"
end

-- A child dressed as a jack-o'-lantern, with a glowing face on the costume, a
-- stalk for a hat and a bucket of sweets.
local function pumpkinKid(model: Model, random: Kit.Random)
	local skin = random.pick(P.Skins)
	local trousers = random.pick(CLOTHES)
	for side = -1, 1, 2 do
		Kit.block(model, at(side * 0.3, 0.5, 0), V(0.45, 0.9, 0.45), trousers)
		Kit.block(model, at(side * 0.3, 0.12, -0.08), V(0.5, 0.24, 0.62), P.Bat)
	end
	local body = at(0, 1.55, 0)
	Kit.ball(model, body, V(1.9, 1.5, 1.7), P.Pumpkin)
	Kit.ball(model, body, V(1.1, 1.54, 1.74), P.PumpkinDark)
	for side = -1, 1, 2 do
		Kit.glow(
			model,
			body * CFrame.new(side * 0.32, 0.22, -0.77) * CFrame.Angles(0, 0, math.pi / 4),
			V(0.22, 0.22, 0.1),
			P.Candle
		)
		Kit.ball(model, body * CFrame.new(side * 0.95, 0.05, -0.1), V(0.5, 0.5, 0.5), P.Pumpkin)
		Kit.ball(model, body * CFrame.new(side * 1.05, -0.3, -0.25), V(0.32, 0.32, 0.32), skin)
	end
	Kit.glow(model, body * CFrame.new(0, -0.22, -0.8), V(0.55, 0.14, 0.1), P.Candle)

	local head = at(0, 2.75, 0)
	Kit.ball(model, head, V(1.05, 1.05, 1.05), skin)
	for side = -1, 1, 2 do
		Kit.ball(model, head * CFrame.new(side * 0.2, 0.06, -0.47), V(0.14, 0.18, 0.08), P.Eye)
	end
	Kit.post(model, head * CFrame.new(0, 0.62, 0) * CFrame.Angles(0.2, 0, 0.1), 0.45, 0.25, P.Stem, M.Wood)
	Kit.ball(model, head * CFrame.new(0.22, 0.6, 0) * CFrame.Angles(0, 0, -0.5), V(0.4, 0.1, 0.25), P.Leaf)

	local bucket = body * CFrame.new(1.1, -0.65, -0.3)
	Kit.post(model, bucket, 0.5, 0.55, P.Pumpkin)
	Kit.ball(model, bucket * CFrame.new(0, 0.27, 0), V(0.42, 0.16, 0.42), random.pick(P.StringLights))
	return "Hop"
end

-- A cheerful little skeleton in an orange bow tie.
local function skeleton(model: Model)
	local bone = P.Bone
	for side = -1, 1, 2 do
		Kit.post(model, at(side * 0.25, 0.6, 0), 1.1, 0.22, bone)
		Kit.block(model, at(side * 0.25, 0.08, -0.12), V(0.3, 0.16, 0.5), bone)
	end
	Kit.block(model, at(0, 1.22, 0), V(0.8, 0.26, 0.4), bone)
	Kit.post(model, at(0, 1.75, 0.08), 1, 0.18, bone)
	for i, width in { 0.75, 0.88, 0.92 } do
		Kit.block(model, at(0, 1.5 + i * 0.2, -0.02), V(width, 0.11, 0.5), bone)
	end
	Kit.block(model, at(0, 2.3, 0), V(1.1, 0.16, 0.3), bone)
	for side = -1, 1, 2 do
		Kit.post(model, at(side * 0.62, 1.8, -0.05) * CFrame.Angles(0, 0, side * 0.15), 1, 0.18, bone)
		Kit.block(model, at(side * 0.14, 2.28, -0.2) * CFrame.Angles(0, 0, side * 0.35), V(0.24, 0.18, 0.08), W.Orange)
	end
	local skull = at(0, 2.85, 0)
	Kit.ball(model, skull, V(0.95, 0.9, 0.95), bone)
	Kit.block(model, skull * CFrame.new(0, -0.4, -0.08), V(0.55, 0.22, 0.6), bone)
	for side = -1, 1, 2 do
		Kit.ball(model, skull * CFrame.new(side * 0.2, 0.04, -0.43), V(0.24, 0.28, 0.1), P.Eye)
	end
	return "Hop"
end

-- A witch with a pointed hat and a broom.
local function witch(model: Model, random: Kit.Random)
	local robe = random.pick(P.Robes)
	local skin = if random.number(0, 1) < 0.5 then P.WitchSkin else random.pick(P.Skins)
	local hair = random.pick({ P.Bat, W.Orange, W.Purple, P.Corn })
	Kit.post(model, at(0, 0.55, 0), 1.1, 1.6, robe)
	Kit.ball(model, at(0, 1.7, 0), V(1.3, 1.6, 1.2), robe)
	for side = -1, 1, 2 do
		Kit.ball(model, at(side * 0.3, 0.1, -0.72), V(0.35, 0.2, 0.5), P.Bat)
		Kit.ball(model, at(side * 0.72, 1.85, -0.1) * CFrame.Angles(0, 0, side * 0.4), V(0.4, 0.9, 0.4), robe)
	end

	local head = at(0, 2.95, 0)
	Kit.ball(model, head, V(1, 1, 1), skin)
	Kit.ball(model, head * CFrame.new(0, -0.05, 0.15), V(1.15, 1.1, 1), hair)
	Kit.block(model, head * CFrame.new(0, -0.35, 0.35), V(1.1, 0.9, 0.4), hair)
	for side = -1, 1, 2 do
		Kit.ball(model, head * CFrame.new(side * 0.18, 0.05, -0.47), V(0.12, 0.16, 0.06), P.Eye)
	end
	Kit.ball(model, head * CFrame.new(0, -0.07, -0.55), V(0.14, 0.14, 0.22), skin)

	Kit.post(model, at(0, 3.4, 0), 0.1, 1.9, P.Bat)
	Kit.post(model, at(0, 3.52, 0), 0.14, 1, random.pick({ W.Purple, W.Toxic, W.Orange }))
	Kit.post(model, at(0, 3.64, 0), 0.36, 0.92, P.Bat)
	Kit.post(model, at(0, 3.96, 0), 0.32, 0.62, P.Bat)
	Kit.post(model, at(0.06, 4.2, 0.04) * CFrame.Angles(0.25, 0, -0.3), 0.3, 0.32, P.Bat)

	Kit.span(model, V(0.95, 0.35, 0.25), V(0.95, 2.4, -0.35), 0.12, 0.12, P.DarkWood, M.Wood)
	Kit.ball(model, at(0.95, 0.35, 0.3), V(0.45, 0.7, 0.45), P.Hay)
	return "Hop"
end

-- A shuffling mummy with its arms out and glowing eyes.
local function mummy(model: Model, random: Kit.Random)
	local wrap, shade = P.Bandage, P.BandageShade
	for side = -1, 1, 2 do
		Kit.block(model, at(side * 0.28, 0.5, 0), V(0.5, 1, 0.5), wrap)
		Kit.block(model, at(side * 0.55, 2.15, -0.55), V(0.38, 0.38, 1.1), wrap)
	end
	Kit.block(model, at(0, 1.7, 0), V(1.3, 1.4, 0.8), wrap)
	for i, y in { 1.25, 1.65, 2.05 } do
		Kit.block(
			model,
			at(0, y, 0) * CFrame.Angles(0, 0, if i % 2 == 0 then 0.12 else -0.12),
			V(1.36, 0.14, 0.86),
			shade
		)
	end
	local head = at(0, 2.95, 0)
	Kit.ball(model, head, V(1, 1.05, 1), wrap)
	Kit.ball(model, head * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, 0.15), V(1.04, 0.14, 1.04), shade)
	for side = -1, 1, 2 do
		Kit.glow(model, head * CFrame.new(side * 0.2, -0.04, -0.49), V(0.16, 0.12, 0.06), P.EerieGlow, true)
	end
	-- A loose end trailing behind.
	local trail = random.number(-0.3, 0.3)
	Kit.block(model, at(0.4, 1, 0.45) * CFrame.Angles(0.3, 0, trail), V(0.15, 0.9, 0.06), wrap)
	return "Hop"
end

local KINDS: { (Model, Kit.Random) -> string } = { ghost, pumpkinKid, skeleton, witch, mummy }

-- How many kinds of visitor there are.
Crowd.KindCount = #KINDS

-- The colour of eyes and other dark features on faces.
Crowd.FaceColor = P.Eye

-- A visitor in costume. kind picks which (1 to KindCount), or random does.
function Crowd.visitor(random: Kit.Random, kind: number?): Model
	local model = Kit.model(nil, "Visitor")
	local gait = KINDS[kind or random.integer(1, #KINDS)](model, random)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	model.WorldPivot = CFrame.new()
	model:SetAttribute("Gait", gait)
	return model
end

-- The goods, by item id. Anything else is a plain ball in its item colour.
local GOODS: { [string]: (Model) -> () } = {
	-- A witch's toffee apple on a stick.
	handmade = function(model)
		Kit.ball(model, at(0, -0.05, 0), V(0.95, 0.9, 0.95), Kit.color(Theme.Items.handmade.Color))
		Kit.ball(model, at(0, -0.36, 0), V(0.9, 0.3, 0.9), P.Glow)
		Kit.post(model, at(0, 0.6, 0), 0.6, 0.1, P.Plaster, M.Wood)
	end,
	raw = function(model)
		Pieces.pumpkin(model, at(0, -0.43, 0), 1.2)
	end,
	-- A pumpkin pie with a dollop of cream.
	cooked = function(model)
		Kit.post(model, at(0, -0.1, 0), 0.35, 1.3, Kit.color(Theme.Items.cooked.Color))
		Kit.post(model, at(0, 0.06, 0), 0.06, 1.1, P.PumpkinDark)
		Kit.ball(model, at(0, 0.13, 0), V(0.32, 0.16, 0.32), P.Plaster)
	end,
}

function Crowd.good(item: string): Model
	local model = Kit.model(nil, "Good")
	local build = GOODS[item]
	if build then
		build(model)
	else
		local themed = Theme.Items[item]
		Kit.ball(model, CFrame.new(), V(1.2, 1.2, 1.2), if themed then Kit.color(themed.Color) else Color3.new(1, 1, 1))
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return Crowd
