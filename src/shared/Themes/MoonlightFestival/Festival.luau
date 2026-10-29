-- The look of each player's own festival (Config/Festival): the decorations
-- that go in the plot's decoration spots, the sign under the arch with the
-- festival's name, the board where the owner picks what goes where, and the
-- shelf that fills with their trophies. The server builds all of them.
--
-- Each decoration is built round base, the middle of its spot on the floor,
-- facing +Z (into the plot). It stays inside Layout.DecorSize square and
-- Layout.DecorHeight tall, and is light: at most 22 parts and 1 light,
-- because every plot has six of them.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.Config.Layout)
local ActivityLook = require(script.Parent.Activity)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

local Festival = {}

-- The most a decoration may have, for the tests and the part budget.
Festival.MaxDecorParts = 22
Festival.MaxDecorLights = 1

type Builder = (parent: Instance, base: CFrame, random: Kit.Random) -> ()

local decor: { [string]: Builder } = {}

-- Two hay bales stacked with a jack-o'-lantern on top, a pitchfork and a
-- pumpkin by them.
decor.hay_corner = function(parent, base, random)
	Pieces.hayBale(parent, base * CFrame.new(0.4, 0, -0.6))
	Pieces.hayBale(parent, base * CFrame.new(0.1, 1.5, -0.7) * CFrame.Angles(0, 0.25, 0))
	Pieces.jackOLantern(parent, base * CFrame.new(0.3, 3, -0.6), 1.3, false)
	local fork = base * CFrame.new(-2.3, 0, -0.2) * CFrame.Angles(0, 0, 0.15)
	Kit.post(parent, fork * CFrame.new(0, 2, 0), 4, 0.15, P.Wood, M.Wood)
	for side = -1, 1 do
		Kit.block(parent, fork * CFrame.new(side * 0.2, 4.25, 0), V(0.06, 0.6, 0.06), P.Metal, M.Metal)
	end
	Pieces.pumpkin(parent, base * CFrame.new(1.6, 0, 2) * CFrame.Angles(0, random.number(0, 3), 0), 1.4)
end

-- Two gravestones, a skeleton resting against one and a pumpkin.
decor.graveyard_corner = function(parent, base, random)
	Pieces.gravestone(parent, base * CFrame.new(0, 0, -1.5), random.number(1.3, 1.8))
	Pieces.gravestone(parent, base * CFrame.new(2.5, 0, -0.5) * CFrame.Angles(0, -0.3, 0), random.number(1, 1.4))
	Pieces.skeleton(parent, base * CFrame.new(-2.2, 0, -0.8), 1.8)
	Pieces.pumpkin(parent, base * CFrame.new(1.5, 0, 2.2) * CFrame.Angles(0, random.number(0, 3), 0), 1.3)
end

-- A heap of pumpkins with a grinning jack-o'-lantern on top.
decor.pumpkin_pile = function(parent, base, random)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3 + 0.4
		local spot = base * CFrame.new(math.cos(angle) * 1.3, 0, math.sin(angle) * 1.3)
		Pieces.pumpkin(parent, spot * CFrame.Angles(0, random.number(0, 3), 0), random.number(1.7, 2.1))
	end
	Pieces.jackOLantern(parent, base * CFrame.new(0, 1.15, 0.1), 1.9, true)
end

-- A witch's cauldron bubbling green over a fire, with a broom leaning on it.
decor.witch_cauldron = function(parent, base)
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		Kit.ball(
			parent,
			base * CFrame.new(math.cos(angle) * 1.9, 0.2, math.sin(angle) * 1.9),
			V(0.8, 0.45, 0.7),
			P.DarkStone,
			M.Slate
		)
	end
	for _, yaw in { 0.6, -0.8 } do
		Kit.log(parent, base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, yaw, 0), 2.6, 0.35, P.Trunk, M.Wood)
	end
	local fire = Kit.block(parent, base * CFrame.new(0, 0.5, 0), V(1, 0.4, 1), P.Trunk)
	fire.Transparency = 1
	Kit.new("Fire", fire, { Size = 2.5, Heat = 3, Color = W.Orange, SecondaryColor = P.Candle })
	Kit.solid(Kit.ball(parent, base * CFrame.new(0, 2, 0), V(3.4, 2.6, 3.4), P.Bat, M.Metal))
	local brew =
		Kit.glow(parent, base * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.pi / 2), V(0.1, 2.9, 2.9), W.Toxic)
	brew.Shape = Enum.PartType.Cylinder
	Kit.light(brew, W.Toxic, 14, 1.5, true)
	Kit.new("ParticleEmitter", brew, {
		Rate = 4,
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 1.8),
		SpreadAngle = Vector2.new(15, 15),
		Size = NumberSequence.new(0.4, 1),
		Transparency = NumberSequence.new(0.4, 1),
		Color = ColorSequence.new(W.Toxic),
		LightEmission = 0.6,
		EmissionDirection = Enum.NormalId.Right,
	})
	Kit.span(
		parent,
		(base * CFrame.new(2.2, 0, 1.2)).Position,
		(base * CFrame.new(1.4, 4.2, 0.4)).Position,
		0.18,
		0.18,
		P.DarkWood,
		M.Wood
	)
	Kit.ball(parent, base * CFrame.new(2.3, 0.5, 1.3), V(0.6, 1, 0.6), P.Hay, M.Fabric)
end

-- An arch of dark wood hung with three lanterns.
decor.lantern_arch = function(parent, base)
	local halfWidth, height = 2.8, 6.5
	for side = -1, 1, 2 do
		Kit.solid(Kit.post(parent, base * CFrame.new(side * halfWidth, height / 2, 0), height, 0.5, P.DarkWood, M.Wood))
	end
	local arc = {}
	for i = 0, 4 do
		local angle = math.pi * (1 - i / 4)
		table.insert(arc, (base * CFrame.new(math.cos(angle) * halfWidth, height + math.sin(angle) * 1.6, 0)).Position)
	end
	for i = 1, #arc - 1 do
		Kit.span(parent, arc[i], arc[i + 1], 0.5, 0.5, P.DarkWood, M.Wood)
	end
	for i, x in { -1.6, 0, 1.6 } do
		local drop = if i == 2 then 1.4 else 1
		local top = height + (if i == 2 then 1.6 else 1.1)
		Kit.block(parent, base * CFrame.new(x, top - drop / 2, 0), V(0.08, drop, 0.08), P.Metal, M.Metal)
		Pieces.lantern(parent, base * CFrame.new(x, top - drop - 0.45, 0), 0.8, P.Candle, if i == 2 then 16 else nil)
	end
end

-- A round stone basin of glowing water under a crescent moon.
decor.moon_fountain = function(parent, base)
	Kit.solid(Kit.post(parent, base * CFrame.new(0, 0.6, 0), 1.2, 5.6, P.Stone, M.Slate))
	local water = Kit.post(parent, base * CFrame.new(0, 1.22, 0), 0.1, 4.8, P.Water, M.Neon)
	water.Transparency = 0.2
	Kit.solid(Kit.post(parent, base * CFrame.new(0, 2.3, 0), 2.2, 0.9, P.Stone, M.Slate))
	Kit.post(parent, base * CFrame.new(0, 3.5, 0), 0.25, 1.6, P.DarkStone, M.Slate)
	-- The crescent: an arc of glowing pieces standing on the pillar.
	local moon = base * CFrame.new(0, 5.2, 0)
	local points = {}
	for i = 0, 6 do
		local angle = math.rad(-110 + i * (220 / 6))
		table.insert(points, (moon * CFrame.new(math.sin(angle) * 1.6, math.cos(angle) * 1.6, 0)).Position)
	end
	for i = 1, #points - 1 do
		local thick = 0.55 - math.abs(i - 3.5) * 0.1
		Kit.span(parent, points[i], points[i + 1], 0.3, thick, P.Moonlight, M.Neon)
	end
	local glow = Kit.glow(parent, moon * CFrame.new(0, 0, -0.1), V(0.3, 0.3, 0.3), P.Moonlight, true)
	glow.Transparency = 1
	Kit.light(glow, P.Moonlight, 16, 1.4)
	Kit.new("ParticleEmitter", water, {
		Rate = 6,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(2, 3),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = V(0, -6, 0),
		Size = NumberSequence.new(0.2, 0.05),
		Transparency = NumberSequence.new(0.2, 1),
		Color = ColorSequence.new(P.Water),
		LightEmission = 0.8,
		EmissionDirection = Enum.NormalId.Right,
	})
end

-- A hedge clipped into a bat with its wings spread and glowing eyes, in a
-- wooden planter.
decor.bat_topiary = function(parent, base)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 0.6, 0), V(3, 1.2, 3), P.DarkWood, M.WoodPlanks))
	Kit.block(parent, base * CFrame.new(0, 1.25, 0), V(2.6, 0.1, 2.6), P.Soil, M.Ground)
	Kit.solid(Kit.post(parent, base * CFrame.new(0, 2.2, 0), 2, 0.5, P.Trunk, M.Wood))
	local body = base * CFrame.new(0, 4.6, 0)
	Kit.ball(parent, body, V(2, 2.6, 1.8), P.Hedge, M.Grass)
	Kit.ball(parent, body * CFrame.new(0, 1.7, 0), V(1.5, 1.3, 1.4), P.Hedge, M.Grass)
	for side = -1, 1, 2 do
		Kit.wedge(
			parent,
			body * CFrame.new(side * 1.9, 0.3, 0) * CFrame.Angles(0, side * math.pi / 2, 0),
			V(0.4, 1.8, 2.6),
			P.Hedge,
			M.Grass
		)
		Kit.wedge(
			parent,
			body * CFrame.new(side * 1.9, -0.6, 0) * CFrame.Angles(math.pi, side * math.pi / 2, 0),
			V(0.4, 0.8, 2.6),
			P.Hedge,
			M.Grass
		)
		Kit.wedge(
			parent,
			body * CFrame.new(side * 0.45, 2.55, 0) * CFrame.Angles(0, math.pi / 2, 0),
			V(0.3, 0.7, 0.5),
			P.Hedge,
			M.Grass
		)
		Kit.glow(parent, body * CFrame.new(side * 0.3, 1.8, 0.7), V(0.22, 0.22, 0.1), W.Red, true)
	end
end

-- A stone ghost on a plinth, with a real one floating over it.
decor.ghost_statue = function(parent, base)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 0.5, 0), V(3, 1, 3), P.DarkStone, M.Slate))
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 1.6, 0), V(2.2, 1.2, 2.2), P.Stone, M.Slate))
	local statue = base * CFrame.new(0, 3.4, 0)
	Kit.ball(parent, statue, V(1.8, 2.4, 1.6), P.Stone, M.Slate)
	Kit.ball(parent, statue * CFrame.new(0, 1.3, 0), V(1.5, 1.4, 1.4), P.Stone, M.Slate)
	for side = -1, 1, 2 do
		Kit.ball(parent, statue * CFrame.new(side * 0.3, 1.4, 0.66), V(0.25, 0.4, 0.12), P.Eye)
		Kit.ball(
			parent,
			statue * CFrame.new(side * 1, 0.4, 0.2) * CFrame.Angles(0, 0, side * 0.6),
			V(0.7, 0.35, 0.35),
			P.Stone,
			M.Slate
		)
	end
	local ghost = Pieces.ghost(parent, base * CFrame.new(0, 7.2, 0), 1.3)
	Kit.float(ghost, base * CFrame.new(0, 7.2, 0), 0.8, 3.2, 9)
end

-- A little parade cart carrying a giant jack-o'-lantern, with bunting.
decor.parade_float = function(parent, base)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 1.1, 0), V(5.2, 0.6, 3.6), P.Roof, M.WoodPlanks))
	Kit.block(parent, base * CFrame.new(0, 0.85, 1.85), V(5.2, 0.5, 0.1), W.Orange, M.Fabric)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			Kit.log(parent, base * CFrame.new(x * 1.9, 0.7, z * 1.95), 0.3, 1.4, P.DarkWood, M.Wood)
		end
	end
	Pieces.jackOLantern(parent, base * CFrame.new(0, 1.4, -0.2), 3, true)
	local left, right = base * CFrame.new(-2.4, 1.4, 1.6), base * CFrame.new(2.4, 1.4, 1.6)
	for _, corner in { left, right } do
		Kit.post(parent, corner * CFrame.new(0, 1.5, 0), 3, 0.15, P.DarkWood, M.Wood)
	end
	Pieces.bunting(
		parent,
		(left * CFrame.new(0, 3, 0)).Position,
		(right * CFrame.new(0, 3, 0)).Position,
		0.4,
		P.Bunting
	)
end

-- A skeleton drummer behind a big drum, sticks up, with a cymbal.
decor.skeleton_band = function(parent, base)
	local drum = base * CFrame.new(0, 0, 0.9)
	local skin = Kit.solid(
		Kit.log(parent, drum * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.pi / 2, 0), 1.2, 2.4, W.Red, M.Fabric)
	)
	skin.Name = "Drum"
	Kit.log(parent, drum * CFrame.new(0, 1.3, 0.62) * CFrame.Angles(0, math.pi / 2, 0), 0.06, 2.2, P.Plaster, M.Fabric)
	for side = -1, 1, 2 do
		Kit.block(parent, drum * CFrame.new(side * 0.8, 0.3, 0), V(0.15, 0.6, 0.15), P.Metal, M.Metal)
	end
	Pieces.skeleton(parent, base * CFrame.new(0, 0, -0.9), 2)
	for side = -1, 1, 2 do
		Kit.block(
			parent,
			base * CFrame.new(side * 0.55, 1.75, -0.2) * CFrame.Angles(0.6, 0, side * 0.3),
			V(0.1, 1.1, 0.1),
			P.Wood,
			M.Wood
		)
	end
	Kit.post(parent, base * CFrame.new(1.8, 1.2, -0.3), 2.4, 0.12, P.Metal, M.Metal)
	Kit.post(parent, base * CFrame.new(1.8, 2.45, -0.3) * CFrame.Angles(0.2, 0, 0), 0.08, 1.4, P.Corn, M.Metal)
end

Festival.Decor = decor

-- Builds decoration id at base, as a model named id. seed picks its small
-- random differences, such as which way its pumpkins turn.
function Festival.decor(id: string, base: CFrame, seed: number): Model
	local model = Kit.model(nil, id)
	local build = decor[id]
	if build then
		build(model, base, Kit.random(seed))
	end
	model.WorldPivot = base
	return model
end

-- The sign under the plot's arch, on the gate side, naming the festival.
-- floor is the middle of the plot's floor, front (+Z) towards the plaza.
function Festival.nameSign(parent: Instance, floor: CFrame, text: string): BasePart
	local gate = Layout.Gate
	local width = gate.Size[1] + 1
	local height = gate.Size[2] + 1.2
	local sign =
		Pieces.sign(parent, floor * CFrame.new(gate.X, height, gate.Z + 0.6), Vector2.new(width, 1.6), text, P.Candle)
	sign.Name = "NameSign"
	return sign
end

-- The festival board: a notice board on two posts, for the owner to change
-- their festival's name, colours and decorations. origin is the middle of
-- its place on the floor, facing +Z; the server puts its prompt on the
-- returned model's PrimaryPart.
function Festival.board(origin: CFrame, size: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Board"
	Kit.anchor(model, origin, size)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	for side = -1, 1, 2 do
		Kit.solid(Kit.post(model, at(side * 1.6, 2.8, 0), 5.6, 0.3, P.DarkWood, M.Wood))
	end
	Kit.solid(Kit.block(model, at(0, 3.2, -0.1), V(3.4, 2.6, 0.2), P.Wood, M.WoodPlanks))
	Pieces.sign(model, at(0, 5.1, 0.05), Vector2.new(3.6, 0.8), Theme.Strings.FestivalBoard, P.Candle)
	-- Pinned-up notes and a little pumpkin.
	local notes = { P.Plaster, P.Moonlight, P.Plaster }
	for i, color in notes do
		local x = -1 + (i - 1) * 1
		Kit.block(model, at(x, 3.3 + (i % 2) * 0.4, 0.02) * CFrame.Angles(0, 0, (i - 2) * 0.15), V(0.8, 1, 0.05), color)
	end
	Pieces.pumpkin(model, at(1.2, 0, 0.35), 1)
	Pieces.lantern(model, at(-1.6, 5.9, 0.1), 0.6, P.Candle)
	return model
end

-- What the trophy shelf shows: a cup in each finished path's colour, and a
-- plaque for each count that isn't zero.
export type Trophies = {
	Paths: { Color3 },
	Best: number,
	KOs: number,
	Parades: number,
}

local MAX_CUPS = 6

-- The trophy shelf: two shelves on a frame, cups on the top one and plaques
-- with the player's best Ghost Catcher round, arena knockouts and Moonlight
-- Parades on the bottom. origin is the middle of its place on the floor,
-- facing +Z.
function Festival.shelf(origin: CFrame, size: Vector3, trophies: Trophies): Model
	local model = Instance.new("Model")
	model.Name = "Shelf"
	Kit.anchor(model, origin, size)
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local width = size.X - 0.4
	for side = -1, 1, 2 do
		Kit.solid(Kit.block(model, at(side * width / 2, 2.6, 0), V(0.3, 5.2, size.Z - 0.4), P.DarkWood, M.Wood))
	end
	Kit.solid(Kit.block(model, at(0, 2.6, -size.Z / 2 + 0.35), V(width, 5.2, 0.2), P.Wood, M.WoodPlanks))
	for _, y in { 1.2, 3.4 } do
		Kit.block(model, at(0, y, 0), V(width, 0.2, size.Z - 0.4), P.DarkWood, M.Wood)
	end
	Kit.block(model, at(0, 5.3, 0), V(width + 0.4, 0.25, size.Z - 0.2), P.DarkWood, M.Wood)

	-- Cups for finished paths, along the top shelf.
	local cups = math.min(#trophies.Paths, MAX_CUPS)
	for i = 1, cups do
		local color = trophies.Paths[i]
		local x = (i - (MAX_CUPS + 1) / 2) * (width - 0.6) / MAX_CUPS
		Kit.block(model, at(x, 3.6, 0.1), V(0.5, 0.2, 0.5), P.DarkStone, M.Slate)
		Kit.post(model, at(x, 3.85, 0.1), 0.3, 0.15, P.Corn, M.Metal)
		local bowl = Kit.ball(model, at(x, 4.25, 0.1), V(0.6, 0.55, 0.6), color, M.Metal)
		bowl.Reflectance = 0.2
	end

	-- Plaques on the bottom shelf, each with a little prize on top.
	local plaques = {}
	if trophies.Best > 0 then
		table.insert(plaques, { Theme.Strings.TrophyBest:format(trophies.Best), ActivityLook.Color, "Jar" })
	end
	if trophies.KOs > 0 then
		table.insert(plaques, { Theme.Strings.TrophyKOs:format(trophies.KOs), W.Orange, "Mallet" })
	end
	if trophies.Parades > 0 then
		table.insert(plaques, { Theme.Strings.TrophyParades:format(trophies.Parades), P.Moonlight, "Lantern" })
	end
	for i, plaque in plaques do
		local x = (i - 2) * (width / 3)
		Pieces.sign(model, at(x, 1.65, 0.6), Vector2.new(width / 3 - 0.3, 0.6), plaque[1], plaque[2])
		if plaque[3] == "Jar" then
			local jar = Kit.glow(model, at(x, 2.2, 0.1), V(0.6, 0.8, 0.6), plaque[2], true)
			jar.Transparency = 0.2
		elseif plaque[3] == "Mallet" then
			Kit.block(model, at(x, 1.75, 0.1) * CFrame.Angles(0, 0, math.pi / 2), V(0.15, 1.2, 0.15), P.Wood, M.Wood)
			Kit.block(model, at(x + 0.6, 1.75, 0.1), V(0.5, 0.5, 0.7), P.Wood, M.Wood)
		else
			Pieces.lantern(model, at(x, 1.9, 0.1), 0.6, plaque[2])
		end
	end
	return model
end

return Festival
