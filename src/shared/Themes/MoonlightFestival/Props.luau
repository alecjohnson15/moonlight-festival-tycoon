-- A model for each upgrade, built from parts. PlotService calls the builder
-- named by the upgrade's id with origin, the CFrame on the plot floor at the
-- middle of the upgrade's layout slot (front towards +Z, the plaza), and the
-- slot's size. Everything stays inside the slot.
--
-- Stations and attractions get an invisible Anchor box the size of the slot,
-- which labels sit on. An upgrade to a building adds to it, inside that
-- building's slot or the open yard beside it (Config/Layout), and has no
-- anchor; its builder gets the yard's CFrame on the floor at its middle as a
-- third argument. Every upgrade adds something you can see: the first ones
-- each have their own model, and the rest put up flags and lights in their
-- path's colour (see the end of this file). Parts marked with Kit.paint
-- take the owner's festival colours (Config/Festival).

local Kit = require(script.Parent.Parent.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

type At = (x: number, y: number, z: number, yaw: number?) -> CFrame

local Props = {}

-- at(x, y, z) is a point in the slot, y up from the floor.
local function placer(origin: CFrame): At
	return function(x, y, z, yaw)
		return origin * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	end
end

local function station(origin: CFrame, size: Vector3): (Model, At)
	local model = Instance.new("Model")
	Kit.anchor(model, origin, size)
	return model, placer(origin)
end

local function addOn(origin: CFrame): (Model, At)
	return Instance.new("Model"), placer(origin)
end

local function point(at: At, x: number, y: number, z: number): Vector3
	return at(x, y, z).Position
end

-- The creepy treat stall: a booth with a striped awning, a counter of witch
-- apples and a shelf of glowing potions.
function Props.starter_stall(origin: CFrame, size: Vector3): Model
	local model, at = station(origin, size)
	local stripes = P.AwningStripes

	Kit.block(model, at(0, 0.15, -0.2), V(8.6, 0.3, 7.2), P.DarkWood, M.WoodPlanks)
	Kit.solid(Kit.block(model, at(0, 3.4, -3.4), V(8, 6.2, 0.4), P.Wood, M.WoodPlanks))
	for _, x in { -3.9, 3.9 } do
		for _, z in { -3.4, 2.9 } do
			Kit.solid(Kit.block(model, at(x, 3.4, z), V(0.5, 6.8, 0.5), P.DarkWood, M.Wood))
		end
	end

	-- The counter, with a fabric band along its front.
	Kit.solid(Kit.block(model, at(0, 1.5, 2.6), V(7.2, 3, 1.4), P.Wood, M.WoodPlanks))
	Kit.block(model, at(0, 3.1, 2.65), V(7.8, 0.25, 1.9), P.DarkWood, M.Wood)
	Kit.paint(Kit.block(model, at(0, 2.2, 3.33), V(7.3, 0.5, 0.06), stripes[1], M.Fabric), 1)

	-- The awning slopes down from the back wall to the front, in stripes.
	local run, drop = 7.5, 1
	local slope = math.atan2(drop, run)
	local length = math.sqrt(run * run + drop * drop)
	local count = 6
	local width = 9 / count
	for i = 1, count do
		local x = -4.5 + (i - 0.5) * width
		local stripe = (i - 1) % 2 + 1
		local color = stripes[stripe]
		Kit.paint(
			Kit.block(model, at(x, 6.5, 0.05) * CFrame.Angles(slope, 0, 0), V(width, 0.25, length), color, M.Fabric),
			stripe
		)
		Kit.paint(Kit.ball(model, at(x, 5.85, 3.65), V(width * 0.95, 0.9, 0.3), color, M.Fabric), stripe)
	end

	-- Witch apples on sticks, and a skull keeping an eye on them.
	local apple = Kit.color(Theme.Items.handmade.Color)
	for i = 0, 4 do
		local x = -3 + i * 1.25
		Kit.ball(model, at(x, 3.55, 2.5), V(0.6, 0.6, 0.6), apple)
		Kit.post(model, at(x, 4.0, 2.5), 0.5, 0.08, P.Wood, M.Wood)
	end
	local skull = at(3.1, 3.55, 2.6)
	Kit.ball(model, skull, V(0.6, 0.55, 0.6), P.Bone)
	for side = -1, 1, 2 do
		Kit.ball(model, skull * CFrame.new(side * 0.13, 0.03, 0.27), V(0.15, 0.17, 0.08), P.Eye)
	end

	-- A shelf of potions that glow in the dark.
	Kit.block(model, at(0, 4.6, -2.95), V(7, 0.2, 0.7), P.DarkWood, M.Wood)
	local potions = { W.Toxic, W.Purple, W.Red, W.Toxic, W.Teal }
	for i, color in potions do
		Kit.glow(model, at(-2.8 + (i - 1) * 1.4, 5.05, -2.95), V(0.45, 0.7, 0.45), color)
	end
	local shelfLight = Kit.block(model, at(0, 5.4, -2.6), V(0.2, 0.2, 0.2), P.DarkWood)
	shelfLight.Transparency = 1
	Kit.light(shelfLight, W.Toxic, 10, 1.2, true)

	for _, x in { -3.6, 3.6 } do
		Pieces.lantern(model, at(x, 5.0, 3.0), 0.7, P.Candle, 12)
	end
	Pieces.cobweb(model, point(at, -3.9, 6.6, 3.2), point(at, -3.9, 4.6, 3.2), point(at, -1.9, 6.35, 3.2))
	Pieces.cobweb(model, point(at, 3.9, 6.6, 3.2), point(at, 3.9, 4.8, 3.2), point(at, 2.2, 6.35, 3.2))

	Pieces.jackOLantern(model, at(-5.0, 0, 3.3), 1.2, true)
	Pieces.pumpkin(model, at(5.2, 0, 1.4), 1.1)
	Pieces.pumpkin(model, at(5.3, 0, -2.6), 1.0)
	Kit.wash(model, point(at, 5.2, 0.6, 3.35), point(at, 0, 5, -2), W.Red, 18, 3)
	return model
end

-- The cobweb counter: extra tables either side of the stall.
function Props.stall_counter(origin: CFrame): Model
	local model, at = addOn(origin)
	for side = -1, 1, 2 do
		Kit.solid(Kit.block(model, at(side * 5.1, 1.1, 1.4), V(1.7, 2.2, 2.2), P.Wood, M.WoodPlanks))
		Kit.block(model, at(side * 5.1, 2.3, 1.4), V(1.9, 0.2, 2.4), P.DarkWood, M.Wood)
		Kit.post(model, at(side * 5.6, 2.8, 0.6), 0.8, 0.3, P.Bone)
		Kit.glow(model, at(side * 5.6, 3.3, 0.6), V(0.2, 0.3, 0.2), P.Candle)
		Pieces.cobweb(
			model,
			point(at, side * 3.9, 2.4, 0.3),
			point(at, side * 3.9, 0.3, 0.3),
			point(at, side * 5.9, 2.4, 0.3)
		)
	end

	-- Left: a heap of witch apples. Right: a stack of pies.
	local apple = Kit.color(Theme.Items.handmade.Color)
	for row, count in { 3, 2, 1 } do
		for i = 1, count do
			local x = -5.1 + (i - (count + 1) / 2) * 0.55
			Kit.ball(model, at(x, 2.65 + (row - 1) * 0.45, 1.6), V(0.55, 0.55, 0.55), apple)
		end
	end
	local pie = Kit.color(Theme.Items.cooked.Color)
	for level = 0, 2 do
		Kit.post(model, at(5.1, 2.55 + level * 0.32, 1.5), 0.3, 1.2, pie)
	end
	-- Bunting in the festival's colours.
	local flags = Pieces.bunting(model, point(at, -4.1, 5.7, 3.5), point(at, 4.1, 5.7, 3.5), 0.5, P.AwningStripes)
	for index, flag in flags do
		Kit.paint(flag, (index - 1) % 2 + 1)
	end
	return model
end

-- The glowing potion shelf: big bottles lined up on a shelf over the
-- stall's back wall, where they glow over the awning.
function Props.stall_boost_2(origin: CFrame): Model
	local model, at = addOn(origin)
	for side = -1, 1, 2 do
		Kit.block(model, at(side * 3.6, 6.95, -3.4), V(0.3, 0.9, 0.3), P.DarkWood, M.Wood)
	end
	Kit.block(model, at(0, 7.5, -3.45), V(8.4, 0.2, 0.9), P.DarkWood, M.Wood)
	local colors = { W.Purple, W.Toxic, W.Teal, W.Red, W.Purple, W.Toxic }
	for i, color in colors do
		local x = -3.2 + (i - 1) * 1.28
		local height = if i % 2 == 0 then 1.5 else 1.1
		local bottle = Kit.glow(model, at(x, 7.6 + height / 2, -3.45), V(0.85, height, 0.85), color, true)
		Kit.post(model, at(x, 7.75 + height, -3.45), 0.4, 0.3, P.Wood, M.Wood)
		if i == 3 then
			Kit.light(bottle, W.Purple, 14, 1.3, true)
		end
		if i % 3 == 1 then
			Kit.new("ParticleEmitter", bottle, {
				Rate = 3,
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(0.6, 1),
				SpreadAngle = Vector2.new(8, 8),
				Size = NumberSequence.new(0.12, 0.02),
				Transparency = NumberSequence.new(0.2, 1),
				Color = ColorSequence.new(color),
				LightEmission = 1,
				EmissionDirection = Enum.NormalId.Top,
			})
		end
	end
	for side = -1, 1, 2 do
		Kit.ball(model, at(side * 4, 7.9, -3.45), V(0.6, 0.55, 0.6), P.Bone)
	end
	return model
end

-- A sign on two posts, naming an upgrade in its path's colour.
local function signPosts(
	model: Model,
	at: At,
	x: number,
	z: number,
	width: number,
	height: number,
	id: string,
	color: Color3
)
	for side = -1, 1, 2 do
		Kit.solid(Kit.post(model, at(x + side * (width / 2 - 0.3), height / 2, z), height, 0.25, P.DarkWood, M.Wood))
	end
	Pieces.sign(model, at(x, height - 0.5, z + 0.2), Vector2.new(width, 1), Theme.Upgrades[id].DisplayName, color)
end

-- The toffee apple cauldron: pink toffee bubbling over a fire beside the
-- stall, and a table of apples dipped in it.
function Props.stall_output_1(_origin: CFrame, _size: Vector3, yard: CFrame): Model
	local model, at = addOn(yard)
	local pink = Kit.color(Theme.Paths.starter_stall.output.Color)
	local spot = at(0, 0, 1.2)
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		Kit.ball(
			model,
			spot * CFrame.new(math.cos(angle) * 1.6, 0.2, math.sin(angle) * 1.6),
			V(0.7, 0.4, 0.6),
			P.DarkStone,
			M.Slate
		)
	end
	for _, yaw in { 0.5, -0.7 } do
		Kit.log(model, spot * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, yaw, 0), 2.4, 0.35, P.Trunk, M.Wood)
	end
	local fire = Kit.block(model, spot * CFrame.new(0, 0.5, 0), V(1, 0.4, 1), P.Trunk)
	fire.Transparency = 1
	Kit.new("Fire", fire, { Size = 2.5, Heat = 3, Color = W.Orange, SecondaryColor = P.Candle })
	Kit.solid(Kit.ball(model, spot * CFrame.new(0, 1.9, 0), V(3.2, 2.3, 3.2), P.Bat, M.Metal))
	local toffee =
		Kit.glow(model, spot * CFrame.new(0, 2.95, 0) * CFrame.Angles(0, 0, math.pi / 2), V(0.1, 2.7, 2.7), pink)
	toffee.Shape = Enum.PartType.Cylinder
	Kit.light(toffee, pink, 14, 1.4, true)
	Kit.new("ParticleEmitter", toffee, {
		Rate = 5,
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 1.6),
		SpreadAngle = Vector2.new(15, 15),
		Size = NumberSequence.new(0.5, 1.2),
		Transparency = NumberSequence.new(0.5, 1),
		Color = ColorSequence.new(pink:Lerp(P.Mist, 0.5)),
		EmissionDirection = Enum.NormalId.Right,
	})
	Kit.post(model, spot * CFrame.new(0.6, 3.5, 0.2) * CFrame.Angles(0, 0, -0.4), 2.4, 0.15, P.Wood, M.Wood)

	-- The table of toffee apples, each on a stick.
	Kit.solid(Kit.block(model, at(0, 1, -2.7), V(6, 0.2, 1.6), P.Wood, M.WoodPlanks))
	for side = -1, 1, 2 do
		Kit.solid(Kit.block(model, at(side * 2.7, 0.45, -2.7), V(0.3, 0.9, 1.3), P.DarkWood, M.Wood))
	end
	for i = 0, 4 do
		local x = -2.2 + i * 1.1
		Kit.ball(model, at(x, 1.42, -2.7), V(0.62, 0.62, 0.62), pink:Lerp(P.Candle, 0.35), M.Glass)
		Kit.post(model, at(x, 1.95, -2.7), 0.6, 0.07, P.Wood, M.Wood)
	end
	signPosts(model, at, 0, -3.6, 5.4, 4, "stall_output_1", pink)
	return model
end

-- The ghoul grub bar: a hatch beside the stall serving bowls of glowing
-- green grub, with stools out front.
function Props.stall_vendor_1(_origin: CFrame, _size: Vector3, yard: CFrame): Model
	local model, at = addOn(yard)
	local green = Kit.color(Theme.Paths.starter_stall.vendor.Color)
	Kit.solid(Kit.block(model, at(0, 1.2, 0.6), V(6.4, 2.4, 1.6), P.Wood, M.WoodPlanks))
	Kit.block(model, at(0, 2.5, 0.6), V(6.8, 0.2, 2), P.DarkWood, M.Wood)
	Kit.glow(model, at(0, 1.7, 1.42), V(6.5, 0.3, 0.06), green)
	for i = 0, 3 do
		local x = -2.2 + i * 1.45
		Kit.ball(model, at(x, 2.78, 0.6), V(1, 0.45, 1), P.Bone)
		Kit.glow(model, at(x, 2.95, 0.6), V(0.8, 0.25, 0.8), green, true)
	end
	-- A back wall with a hatch roof, and a lantern of the same green.
	Kit.solid(Kit.block(model, at(0, 2.6, -1.4), V(6.4, 5.2, 0.3), P.DarkWood, M.WoodPlanks))
	Kit.block(model, at(0, 5.3, -0.4) * CFrame.Angles(-0.35, 0, 0), V(7, 0.25, 2.6), P.Roof, M.Wood)
	Pieces.sign(model, at(0, 4, -1.15), Vector2.new(5.4, 1.1), Theme.Upgrades.stall_vendor_1.DisplayName, green)
	Pieces.lantern(model, at(2.7, 4.5, 0.4), 0.7, green, 14)
	Kit.glow(model, at(-2.4, 3.3, -1.2), V(0.9, 0.9, 0.2), green, true)
	for i = -1, 1 do
		Kit.solid(Kit.post(model, at(i * 2, 0.6, 3), 1.2, 0.9, P.Trunk, M.Wood))
	end
	return model
end

-- The night market banners: tall poles beside the stall flying gold and
-- purple banners with moons on, and a crate of goods for sale.
function Props.stall_markup_1(_origin: CFrame, _size: Vector3, yard: CFrame): Model
	local model, at = addOn(yard)
	local gold = Kit.color(Theme.Paths.starter_stall.markup.Color)
	local colors = { gold, W.Purple, gold }
	local tops = {}
	for i = 1, 3 do
		local x = -3.3 + (i - 1) * 2.65
		local height = if i == 2 then 7.5 else 6.5
		Kit.solid(Kit.post(model, at(x, height / 2, -1), height, 0.3, P.DarkWood, M.Wood))
		Kit.block(model, at(x + 0.9, height - 0.3, -1), V(1.9, 0.15, 0.15), P.DarkWood, M.Wood)
		Kit.block(model, at(x + 0.9, height - 2.2, -1), V(1.5, 3.6, 0.06), colors[i], M.Fabric)
		Kit.glow(model, at(x + 0.9, height - 1.8, -0.95), V(0.7, 0.7, 0.05), P.Moonlight, true)
		Kit.glow(model, at(x, height + 0.25, -1), V(0.45, 0.45, 0.45), gold, true)
		table.insert(tops, point(at, x, height, -1))
	end
	for i = 1, #tops - 1 do
		Pieces.stringLights(model, tops[i], tops[i + 1], 0.6, { gold, P.Candle })
	end
	Kit.solid(Kit.block(model, at(-1.6, 0.6, 2.4), V(2.2, 1.2, 1.4), P.Wood, M.WoodPlanks))
	local apple = Kit.color(Theme.Items.handmade.Color)
	for i = 0, 2 do
		Kit.ball(model, at(-2.3 + i * 0.7, 1.45, 2.4), V(0.55, 0.55, 0.55), apple)
	end
	Pieces.lantern(model, at(1.6, 1.4, 2.6), 0.8, gold, 14)
	Kit.solid(Kit.post(model, at(1.6, 0.45, 2.6), 0.9, 0.5, P.DarkStone, M.Slate))
	return model
end

-- A scarecrow in rags with a pointed hat and glowing eyes, facing +Z.
local function scarecrow(model: Model, base: CFrame)
	local rag = P.Bat:Lerp(P.Roof, 0.5)
	Kit.solid(Kit.post(model, base * CFrame.new(0, 2.75, 0), 5.5, 0.3, P.DarkWood, M.Wood))
	Kit.block(model, base * CFrame.new(0, 3.9, 0), V(3.4, 0.25, 0.25), P.DarkWood, M.Wood)
	Kit.block(model, base * CFrame.new(0, 3.3, 0), V(1.4, 1.8, 0.7), rag, M.Fabric)
	for side = -1, 1, 2 do
		Kit.block(
			model,
			base * CFrame.new(side * 1.15, 3.85, 0) * CFrame.Angles(0, 0, side * 0.15),
			V(1.1, 0.5, 0.5),
			rag,
			M.Fabric
		)
		Kit.glow(model, base * CFrame.new(side * 0.2, 4.95, 0.5), V(0.18, 0.12, 0.05), W.Red)
	end
	Kit.ball(model, base * CFrame.new(0, 4.9, 0), V(1.1, 1.1, 1.1), P.Hay, M.Fabric)
	Kit.post(model, base * CFrame.new(0, 5.42, 0), 0.12, 1.7, P.Bat, M.Fabric)
	for level = 0, 2 do
		local crown = base * CFrame.new(0.06 * level, 5.65 + level * 0.32, 0) * CFrame.Angles(0, 0, -0.12 * level)
		Kit.post(model, crown, 0.34, 0.9 - level * 0.27, P.Bat, M.Fabric)
	end
end

-- The haunted pumpkin patch: rows of pumpkins in the mist, watched by a
-- scarecrow with glowing eyes.
function Props.grower(origin: CFrame, size: Vector3): Model
	local model, at = station(origin, size)
	local random = Kit.random(7)

	for _, z in { -5.4, 0, 5.4 } do
		Kit.block(model, at(0, 0.25, z), V(15.5, 0.5, 3.6), P.Soil, M.Ground)
		for _, x in { -5.5, -1.8, 1.8, 5.5 } do
			local spot = at(x + random.number(-0.4, 0.4), 0.5, z + random.number(-0.3, 0.3), random.number(0, math.pi))
			local pumpkinSize = random.number(1.5, 2.1)
			if random.number(0, 1) < 0.2 then
				Pieces.jackOLantern(model, spot, pumpkinSize, false)
			else
				Pieces.pumpkin(model, spot, pumpkinSize)
			end
			Kit.ball(model, spot * CFrame.new(1.1, 0.08, 0.4), V(1.4, 0.15, 0.9), P.Leaf, M.Grass)
		end
	end
	for _, side in { -1, 1 } do
		Kit.block(model, at(0, 0.25, side * 8.8), V(18, 0.5, 0.4), P.DarkWood, M.WoodPlanks)
		Kit.block(model, at(side * 8.8, 0.25, 0), V(0.4, 0.5, 17.2), P.DarkWood, M.WoodPlanks)
	end
	Pieces.jackOLantern(model, at(-7.6, 0.5, 7.6), 1.4, true)
	Pieces.jackOLantern(model, at(7.6, 0.5, 7.6), 1.4, true)

	-- The scarecrow, in the back corner.
	scarecrow(model, at(-7.2, 0, -7.6))

	Pieces.gravestone(model, at(6.4, 0, -7.9), 1.2)
	Pieces.gravestone(model, at(4.3, 0, -8.0), 1.0)
	Pieces.mist(model, at(0, 0.8, 0), Vector2.new(16, 16), 1.2)
	Kit.wash(model, point(at, 8.4, 0.6, 8.4), point(at, 0, 1.5, 0), W.Toxic, 22, 3)
	Kit.wash(model, point(at, -8.4, 0.6, 8.4), point(at, 0, 1.5, -2), W.Purple, 22, 2.5)
	return model
end

-- Swamp sprinklers: pipes between the rows with green spray.
function Props.grower_boost(origin: CFrame): Model
	local model, at = addOn(origin)
	local spray = W.Toxic:Lerp(P.Water, 0.4)
	for _, z in { -2.7, 2.7 } do
		Kit.span(model, point(at, -4, 0.15, z), point(at, 4, 0.15, z), 0.2, 0.2, P.Metal, M.Metal)
		for _, x in { -4, 4 } do
			Kit.post(model, at(x, 1.4, z), 2.5, 0.25, P.Metal, M.Metal)
			local head = Kit.glow(model, at(x, 2.8, z), V(0.45, 0.45, 0.45), W.Toxic, true)
			Kit.new("ParticleEmitter", head, {
				Rate = 30,
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(6, 8),
				SpreadAngle = Vector2.new(40, 40),
				Acceleration = V(0, -20, 0),
				Size = NumberSequence.new(0.15, 0.05),
				Transparency = NumberSequence.new(0.2, 1),
				Color = ColorSequence.new(spray),
				LightEmission = 0.8,
			})
			if x < 0 then
				Kit.light(head, W.Toxic, 9, 1.2)
			end
		end
	end
	return model
end

-- Scarecrow guards: two more scarecrows standing watch beside the patch,
-- with a crow on one and a lantern between them.
function Props.grower_boost_2(_origin: CFrame, _size: Vector3, yard: CFrame): Model
	local model, at = addOn(yard)
	for _, z in { -6.2, 6.2 } do
		scarecrow(model, at(0.6, 0, z))
	end
	local crow = at(1.9, 4.35, 6.2)
	Kit.ball(model, crow, V(0.5, 0.45, 0.7), P.Bat)
	Kit.ball(model, crow * CFrame.new(0, 0.3, 0.25), V(0.35, 0.35, 0.35), P.Bat)
	Kit.wedge(model, crow * CFrame.new(0, 0.28, 0.5) * CFrame.Angles(0, math.pi, 0), V(0.1, 0.12, 0.25), P.Candle)
	Kit.glow(model, crow * CFrame.new(0.1, 0.36, 0.38), V(0.06, 0.06, 0.04), W.Red)
	Kit.solid(Kit.post(model, at(-1.8, 1.5, 0), 3, 0.25, P.DarkWood, M.Wood))
	Pieces.lantern(model, at(-1.8, 3.4, 0), 0.7, W.Red, 12)
	return model
end

-- Glowing compost: a slatted bin of compost glowing green beside the patch,
-- a pitchfork in it, and a giant pumpkin grown on it.
function Props.grower_output_1(_origin: CFrame, _size: Vector3, yard: CFrame): Model
	local model, at = addOn(yard)
	local orange = Kit.color(Theme.Paths.grower.output.Color)
	for slat = 0, 2 do
		local y = 0.35 + slat * 0.7
		Kit.solid(Kit.block(model, at(0, y, -1.6), V(4.4, 0.5, 0.2), P.Wood, M.WoodPlanks))
		for side = -1, 1, 2 do
			Kit.solid(Kit.block(model, at(side * 2.1, y, 0), V(0.2, 0.5, 3.4), P.Wood, M.WoodPlanks))
		end
	end
	Kit.ball(model, at(0, 0.8, 0), V(3.6, 1.6, 3), P.Soil, M.Ground)
	local heap = Kit.glow(model, at(0, 1.35, 0), V(2.6, 0.9, 2.2), W.Toxic, true)
	Kit.light(heap, W.Toxic, 12, 1.2, true)
	Kit.new("ParticleEmitter", heap, {
		Rate = 4,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.4, 0.8),
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(0.3, 0.05),
		Transparency = NumberSequence.new(0.3, 1),
		Color = ColorSequence.new(W.Toxic),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	Kit.post(model, at(0.8, 2.3, 0.3) * CFrame.Angles(0.2, 0, -0.25), 3, 0.12, P.Wood, M.Wood)
	Pieces.pumpkin(model, at(0, 0, 3.8, 0.4), 2.6)
	signPosts(model, at, 0, -2.6, 4.6, 3.6, "grower_output_1", orange)
	return model
end

-- The pick-your-own patch: a stand of baskets beside the patch, a sign, and
-- a wheelbarrow full of pumpkins.
function Props.grower_vendor_1(_origin: CFrame, _size: Vector3, yard: CFrame): Model
	local model, at = addOn(yard)
	local green = Kit.color(Theme.Paths.grower.vendor.Color)
	Kit.solid(Kit.block(model, at(0, 1.1, -0.6), V(4.2, 0.2, 1.8), P.Wood, M.WoodPlanks))
	for _, x in { -1.9, 1.9 } do
		Kit.block(model, at(x, 0.5, -0.6), V(0.25, 1, 1.5), P.DarkWood, M.Wood)
	end
	for i = -1, 1 do
		Kit.post(model, at(i * 1.35, 1.55, -0.6), 0.7, 1.1, P.Hay, M.Fabric)
		Kit.ball(model, at(i * 1.35, 2.1, -0.6), V(0.8, 0.6, 0.8), P.Pumpkin)
	end
	signPosts(model, at, 0, -2, 4.6, 3.8, "grower_vendor_1", green)
	Pieces.lantern(model, at(2.6, 2.2, -1.9), 0.7, green, 12)
	Kit.solid(Kit.post(model, at(2.6, 0.75, -1.9), 1.5, 0.25, P.DarkWood, M.Wood))

	-- The wheelbarrow, its handles towards the front.
	local barrow = at(0, 0, 3.4)
	Kit.solid(Kit.block(model, barrow * CFrame.new(0, 1.1, 0), V(2, 0.9, 2.4), P.Wood, M.WoodPlanks))
	Kit.log(model, barrow * CFrame.new(0, 0.5, -1.2), 0.3, 1, P.Metal, M.Metal)
	for side = -1, 1, 2 do
		Kit.block(model, barrow * CFrame.new(side * 0.8, 0.9, 1.9), V(0.15, 0.15, 1.6), P.DarkWood, M.Wood)
		Kit.block(model, barrow * CFrame.new(side * 0.8, 0.35, 0.8), V(0.15, 0.7, 0.15), P.DarkWood, M.Wood)
	end
	for i = 0, 2 do
		Pieces.pumpkin(model, barrow * CFrame.new(-0.5 + i * 0.5, 1.5, (i % 2) * 0.6 - 0.3), 0.8)
	end
	return model
end

-- The witch's pie kitchen: a crooked cottage with green windows and a smoking
-- chimney, leaving room on its right for the cauldron.
function Props.kitchen(origin: CFrame, size: Vector3): Model
	local model, at = station(origin, size)
	local cx, width, depth, wall = -1.6, 10, 10, 5.5
	local floor = 0.6
	local plaster = P.Plaster:Lerp(P.Moss, 0.3)
	local function house(x: number, y: number, z: number): CFrame
		return at(cx + x, y, z)
	end

	Kit.solid(Kit.block(model, house(0, 0.3, 0), V(width + 0.6, 0.6, depth + 0.6), P.DarkStone, M.Slate))
	Kit.solid(Kit.block(model, house(0, floor + wall / 2, -depth / 2 + 0.25), V(width, wall, 0.5), plaster, M.Plaster))
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				model,
				house(side * (width / 2 - 0.25), floor + wall / 2, 0),
				V(0.5, wall, depth),
				plaster,
				M.Plaster
			)
		)
		-- The front wall either side of the door.
		Kit.solid(
			Kit.block(model, house(side * 3, floor + wall / 2, depth / 2 - 0.25), V(4, wall, 0.5), plaster, M.Plaster)
		)
	end
	Kit.solid(
		Kit.block(
			model,
			house(0, floor + 3.6 + (wall - 3.6) / 2, depth / 2 - 0.25),
			V(2, wall - 3.6, 0.5),
			plaster,
			M.Plaster
		)
	)
	Kit.block(model, house(0, floor + 1.8, depth / 2 - 0.35), V(2, 3.6, 0.25), P.DarkWood, M.WoodPlanks)
	Kit.ball(model, house(0.7, floor + 1.7, depth / 2 - 0.2), V(0.2, 0.2, 0.2), P.Metal, M.Metal)

	-- Dark timber on the corners and along the top of the walls.
	for _, x in { -width / 2, width / 2 } do
		for _, z in { -depth / 2, depth / 2 } do
			Kit.block(model, house(x, floor + wall / 2, z), V(0.6, wall, 0.6), P.DarkWood, M.Wood)
		end
	end
	Kit.block(model, house(0, floor + wall, depth / 2), V(width + 0.6, 0.5, 0.6), P.DarkWood, M.Wood)

	-- Windows glowing green, with crossbars and one crooked shutter each.
	for side = -1, 1, 2 do
		local window = house(side * 3, floor + 2.9, depth / 2)
		Kit.glow(model, window * CFrame.new(0, 0, 0.02), V(1.6, 1.4, 0.1), W.Toxic)
		Kit.block(model, window * CFrame.new(0, 0, 0.1), V(0.12, 1.5, 0.08), P.DarkWood, M.Wood)
		Kit.block(model, window * CFrame.new(0, 0, 0.1), V(1.7, 0.12, 0.08), P.DarkWood, M.Wood)
		Kit.block(
			model,
			window * CFrame.new(side * 1.2, -0.1, 0.12) * CFrame.Angles(0, 0, side * 0.2),
			V(0.6, 1.5, 0.08),
			P.DarkWood,
			M.WoodPlanks
		)
	end
	Pieces.roof(model, house(0, 0, 0), width, depth, floor + wall, 3, P.Roof, 0.4)

	-- A brick chimney breathing green-grey smoke.
	Kit.solid(Kit.block(model, house(2.8, floor + wall + 2.6, -2.2), V(1.4, 4, 1.4), P.Brick, M.Brick))
	local flue = Kit.block(model, house(2.8, floor + wall + 4.7, -2.2), V(0.5, 0.5, 0.5), P.Bat)
	flue.Transparency = 1
	Kit.new("Smoke", flue, {
		Color = W.Toxic:Lerp(P.Mist, 0.7),
		Opacity = 0.15,
		RiseVelocity = 3.5,
		Size = 2,
	})

	-- A porch over the door, with steps.
	Kit.block(model, house(0, 0.15, depth / 2 + 0.4), V(2.6, 0.3, 0.8), P.DarkStone, M.Slate)
	for side = -1, 1, 2 do
		Kit.post(model, house(side * 1.5, floor + 2, depth / 2 + 0.6), 4, 0.25, P.DarkWood, M.Wood)
	end
	Kit.block(
		model,
		house(0, floor + 4.1, depth / 2 + 0.3) * CFrame.Angles(0.3, 0, 0),
		V(3.6, 0.2, 1.1),
		P.Roof,
		M.Slate
	)
	Pieces.sign(model, house(0, floor + 4.95, depth / 2 + 0.15), Vector2.new(2.6, 0.75), Theme.Items.cooked.DisplayName)

	-- Vines creeping up the front, and a cobweb in the corner.
	for _, x in { -4.4, -1.6, 4.2 } do
		Kit.block(model, house(x, floor + 1.6, depth / 2 + 0.03), V(0.35, 3.2, 0.06), P.Leaf, M.Grass)
	end
	Pieces.cobweb(
		model,
		house(-4.7, floor + wall - 0.2, depth / 2 + 0.35).Position,
		house(-4.7, floor + 2.6, depth / 2 + 0.35).Position,
		house(-2.4, floor + wall - 0.4, depth / 2 + 0.35).Position
	)

	local inside = Kit.block(model, house(0, 3, 0), V(0.2, 0.2, 0.2), P.Bat)
	inside.Transparency = 1
	Kit.light(inside, W.Toxic, 16, 1.4, true)
	Kit.wash(model, point(at, 3.6, 0.6, 5.6), house(0, 5, 0).Position, W.Red, 20, 3)
	return model
end

-- The cauldron oven: a bubbling cauldron over a fire, beside the kitchen.
function Props.kitchen_boost(origin: CFrame): Model
	local model, at = addOn(origin)
	local spot = at(5.5, 0, 0)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		Kit.ball(
			model,
			spot * CFrame.new(math.cos(angle) * 1.25, 0.2, math.sin(angle) * 1.25),
			V(0.6, 0.4, 0.5),
			P.DarkStone,
			M.Slate
		)
	end
	for _, yaw in { 0.6, -0.6 } do
		Kit.log(model, spot * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, yaw, 0), 2.2, 0.35, P.Trunk, M.Wood)
	end
	local fire = Kit.block(model, spot * CFrame.new(0, 0.5, 0), V(1, 0.4, 1), P.Trunk)
	fire.Transparency = 1
	Kit.new("Fire", fire, {
		Size = 2.5,
		Heat = 4,
		Color = W.Orange,
		SecondaryColor = P.Candle,
	})
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		Kit.block(
			model,
			spot * CFrame.new(math.cos(angle) * 0.9, 0.6, math.sin(angle) * 0.9),
			V(0.25, 1.2, 0.25),
			P.Bat,
			M.Metal
		)
	end
	Kit.solid(Kit.ball(model, spot * CFrame.new(0, 1.9, 0), V(2.6, 2, 2.6), P.Bat, M.Metal))
	Kit.post(model, spot * CFrame.new(0, 2.75, 0), 0.25, 2.4, P.Bat, M.Metal)
	local brew =
		Kit.glow(model, spot * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.pi / 2), V(0.1, 2.1, 2.1), W.Toxic)
	brew.Shape = Enum.PartType.Cylinder
	Kit.light(brew, W.Toxic, 14, 1.6, true)
	Kit.new("ParticleEmitter", brew, {
		Rate = 6,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(10, 10),
		Size = NumberSequence.new(0.4, 0.1),
		Color = ColorSequence.new(W.Toxic),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Right,
	})

	-- A broom leaning on the cottage.
	local broom = at(4.3, 0, 3.4) * CFrame.Angles(0, 0, -0.25)
	Kit.post(model, broom * CFrame.new(0, 2.2, 0), 3.4, 0.15, P.Wood, M.Wood)
	Kit.block(model, broom * CFrame.new(0, 0.6, 0), V(0.7, 0.9, 0.4), P.Hay, M.Fabric)
	return model
end

-- Enchanted rolling pins: three pins circling over the cauldron oven by
-- themselves, trailing sparkles.
function Props.kitchen_boost_2(origin: CFrame): Model
	local model, at = addOn(origin)
	local pins = Kit.model(model, "RollingPins")
	local pivot = at(5.2, 4.8, 0)
	local sparkle = W.Purple:Lerp(P.Glow, 0.4)
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		local pin = pivot * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.8) * CFrame.Angles(0, 0, 0.3)
		local roller = Kit.log(pins, pin, 1.1, 0.4, P.Wood, M.Wood)
		for side = -1, 1, 2 do
			Kit.log(pins, pin * CFrame.new(side * 0.7, 0, 0), 0.3, 0.15, P.DarkWood, M.Wood)
		end
		if i == 0 then
			Kit.new("ParticleEmitter", roller, {
				Rate = 8,
				Lifetime = NumberRange.new(0.6, 1),
				Speed = NumberRange.new(0.2, 0.5),
				Size = NumberSequence.new(0.15, 0),
				Color = ColorSequence.new(sparkle),
				LightEmission = 1,
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
			})
		end
	end
	Kit.float(pins, pivot, 0.4, 3, 6)
	return model
end

-- The lost lantern maze: hedges in the mist, lanterns on top, gravestones
-- inside, and a hooded figure waiting in the middle.
function Props.attraction_1(origin: CFrame, size: Vector3): Model
	local model, at = station(origin, size)
	local scale = 8.4 / 9
	local height, thickness = 4.2, 1.2
	local walls = {
		{ -9, 9, -1.9, 9 },
		{ 1.9, 9, 9, 9 },
		{ -9, -9, 9, -9 },
		{ -9, -9, -9, 9 },
		{ 9, -9, 9, 9 },
		{ -6, 6, 3, 6 },
		{ 6, 9, 6, 3 },
		{ 0, 3, 6, 3 },
		{ -3, 3, -3, -6 },
		{ 3, 0, 3, -6 },
		{ 0, -3, 0, -9 },
		{ 6, -3, 9, -3 },
		{ -6, 0, -6, -6 },
	}
	for _, wall in walls do
		local a = point(at, wall[1] * scale, height / 2, wall[2] * scale)
		local b = point(at, wall[3] * scale, height / 2, wall[4] * scale)
		-- Run each hedge on past its ends so corners close up.
		local along = (b - a).Unit * thickness / 2
		Kit.solid(Kit.span(model, a - along, b + along, thickness, height, P.Hedge, M.Grass))
	end

	-- Lanterns on posts along the hedge tops; the back ones burn green.
	local posts = {
		{ -8.4, 8.4, P.Candle, false },
		{ 8.4, 8.4, P.Candle, false },
		{ -1.8, 8.4, P.Candle, true },
		{ 1.8, 8.4, P.Candle, true },
		{ -8.4, -8.4, W.Toxic, true },
		{ 8.4, -8.4, W.Toxic, true },
	}
	for _, spec in posts do
		local x, z = spec[1], spec[2]
		Kit.post(model, at(x, height + 0.6, z), 1.2, 0.2, P.DarkWood, M.Wood)
		Pieces.lantern(model, at(x, height + 1.6, z), 0.8, spec[3], if spec[4] then 12 else nil)
	end

	-- The entrance arch, with a skull on top and cobwebs in its corners.
	for _, x in { -2.4, 2.4 } do
		Kit.solid(Kit.post(model, at(x, 3, 8.4), 6, 0.5, P.DarkWood, M.Wood))
	end
	Kit.block(model, at(0, 6.1, 8.4), V(5.4, 0.5, 0.5), P.DarkWood, M.Wood)
	local skull = at(0, 6.7, 8.4)
	Kit.ball(model, skull, V(0.8, 0.75, 0.8), P.Bone)
	for side = -1, 1, 2 do
		Kit.ball(model, skull * CFrame.new(side * 0.17, 0.04, 0.36), V(0.2, 0.22, 0.08), P.Eye)
		Pieces.cobweb(
			model,
			point(at, side * 2.2, 5.85, 8.7),
			point(at, side * 2.2, 4.4, 8.7),
			point(at, side * 0.8, 5.85, 8.7)
		)
	end
	Pieces.jackOLantern(model, at(-1.0, 0, 7.0), 1.1, false)

	Pieces.gravestone(model, at(-7.0, 0, 7.0), 1.1)
	Pieces.gravestone(model, at(7.2, 0, -7.2), 1.0)
	Pieces.gravestone(model, at(4.6, 0, -1.0), 1.0)
	Pieces.skeleton(model, at(-1.6, 0, -7.3), 2)
	Pieces.reaper(model, at(0, 0, 0), 5.5)
	Pieces.mist(model, at(0, 0.8, 0), Vector2.new(16, 16), 1.5)
	Kit.wash(model, point(at, -8.4, height + 0.4, 8.4), point(at, 0, 0, 0), W.Red, 22, 3)
	Kit.wash(model, point(at, 8.4, height + 0.4, -8.4), point(at, 0, 0, 0), W.Purple, 22, 3)
	return model
end

-- The grinning giant pumpkin: it hovers over a ring of candles and skulls,
-- with bats circling it.
function Props.attraction_2(origin: CFrame, size: Vector3): Model
	local model, at = station(origin, size)

	Kit.solid(Kit.post(model, at(0, 0.6, 0), 1.2, 11, P.DarkStone, M.Slate))
	Kit.post(model, at(0, 1.35, 0), 0.3, 11.6, P.Stone, M.Slate)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local x, z = math.cos(angle) * 5.1, math.sin(angle) * 5.1
		Kit.post(model, at(x, 1.8, z), 0.6, 0.3, P.Bone)
		Kit.glow(model, at(x, 2.25, z), V(0.25, 0.25, 0.25), P.Candle, true)
	end
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local skull = at(math.cos(angle) * 6.2, 0.4, math.sin(angle) * 6.2, -angle + math.pi / 2)
		Kit.ball(model, skull, V(0.9, 0.8, 0.9), P.Bone)
		for side = -1, 1, 2 do
			Kit.ball(model, skull * CFrame.new(side * 0.2, 0.05, 0.4), V(0.2, 0.24, 0.08), P.Eye)
		end
	end

	-- The pumpkin floats as one model, ribs and face together.
	local pumpkin = Kit.model(model, "Pumpkin")
	local middle = at(0, 6.5, 0)
	local ribSize = V(10.5, 8.4, 5.5)
	local ribs = {}
	for rib = 0, 5 do
		local cframe = middle * CFrame.Angles(0, rib * math.pi / 6, 0)
		Kit.ball(pumpkin, cframe, ribSize, if rib % 2 == 0 then P.Pumpkin else P.PumpkinDark)
		table.insert(ribs, cframe)
	end
	-- How far forward the pumpkin's skin is at (x, y) on its face.
	local function skin(x: number, y: number): number
		for z = 6, 0, -0.05 do
			local spot = (middle * CFrame.new(x, y, z)).Position
			for _, cframe in ribs do
				local inside = cframe:PointToObjectSpace(spot)
				local a, b, c = inside.X / (ribSize.X / 2), inside.Y / (ribSize.Y / 2), inside.Z / (ribSize.Z / 2)
				if a * a + b * b + c * c <= 1 then
					return z
				end
			end
		end
		return 0
	end
	local fire = P.Candle:Lerp(P.Glow, 0.4)
	local function carve(x: number, y: number, partSize: Vector3, roll: number, color: Color3?)
		local cframe = middle * CFrame.new(x, y, skin(x, y) - 0.15) * CFrame.Angles(0, 0, roll)
		if color then
			return Kit.block(pumpkin, cframe * CFrame.new(0, 0, 0.1), partSize, color)
		end
		return Kit.glow(pumpkin, cframe, partSize, fire)
	end
	for side = -1, 1, 2 do
		carve(side * 2, 1.5, V(2, 0.9, 0.5), side * 0.4)
	end
	carve(0, 0.3, V(0.8, 0.8, 0.5), math.pi / 4)
	local mouth = carve(0, -1.6, V(5, 1.1, 0.5), 0)
	for _, x in { -1.5, 0, 1.5 } do
		carve(x, -1.2, V(0.5, 0.5, 0.5), math.pi / 4, P.PumpkinDark)
	end
	for _, x in { -0.75, 0.75 } do
		carve(x, -2.05, V(0.5, 0.5, 0.5), math.pi / 4, P.PumpkinDark)
	end
	Kit.light(mouth, P.Glow, 40, 3, true)
	Kit.post(pumpkin, middle * CFrame.new(0, 4.9, 0) * CFrame.Angles(0.2, 0, 0.1), 2.2, 1.2, P.Stem, M.Wood)
	Kit.ball(pumpkin, middle * CFrame.new(1, 4.4, 0.4), V(2.2, 0.2, 1.4), P.Leaf, M.Grass)
	Kit.float(pumpkin, middle, 0.5, 6)

	-- Bats circle the pumpkin as a ring that turns.
	local bats = Kit.model(model, "Bats")
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local spot = point(at, math.cos(angle) * 6, 9 + i % 2 * 2, -math.sin(angle) * 6)
		local heading = Vector3.new(math.sin(angle), 0, math.cos(angle))
		Pieces.bat(bats, CFrame.lookAt(spot, spot + heading), 1.2)
	end
	Kit.float(bats, middle, 0.6, 3, 8)

	local under = Kit.block(model, at(0, 1.6, 0), V(0.2, 0.2, 0.2), P.Bat)
	under.Transparency = 1
	Kit.light(under, W.Red, 26, 2)
	Pieces.mist(model, at(0, 0.7, 0), Vector2.new(14, 14), 1)
	Kit.wash(model, point(at, 5.8, 0.6, 6.4), point(at, 0, 7, 0), W.Red, 24, 3)
	Kit.wash(model, point(at, -5.8, 0.6, 6.4), point(at, 0, 7, 0), W.Purple, 24, 3)
	return model
end

-- One ghost-train car at cframe (its floor, facing its -Z). The lead car has a
-- skull on its nose; the others carry a ghost.
local function trainCar(parent: Instance, cframe: CFrame, index: number)
	local car = Kit.model(parent, `Car{index}`)
	car:SetAttribute("Order", index)
	Kit.block(car, cframe * CFrame.new(0, 0.35, 0), V(1.9, 0.4, 2.6), P.Metal, M.Metal)
	Kit.block(car, cframe * CFrame.new(0, 1.05, 0), V(1.8, 1, 2.3), P.Roof)
	Kit.block(car, cframe * CFrame.new(0, 1.9, 1), V(1.8, 0.9, 0.3), P.Roof)
	-- Two axles, a wheel showing at each end.
	for _, z in { -0.8, 0.8 } do
		Kit.log(car, cframe * CFrame.new(0, 0.3, z), 2.15, 0.6, P.Bat, M.Metal)
	end
	if index == 1 then
		local skull = cframe * CFrame.new(0, 1.3, -1.3)
		Kit.ball(car, skull, V(1.2, 1.1, 1), P.Bone)
		for side = -1, 1, 2 do
			Kit.glow(car, skull * CFrame.new(side * 0.25, 0.1, -0.45), V(0.25, 0.25, 0.1), W.Red, true)
		end
	else
		Kit.ball(car, cframe * CFrame.new(0, 1.05, -1.2), V(1.8, 0.9, 0.6), P.Roof)
		Pieces.ghost(car, cframe * CFrame.new(0, 2.1, 0.1) * CFrame.Angles(0, math.pi, 0), 1.1)
	end
	car.WorldPivot = cframe
end

-- The phantom ghost train: a little train looping through a haunted house,
-- with a platform at the front.
function Props.attraction_3(origin: CFrame, size: Vector3): Model
	local model, at = station(origin, size)

	-- The track is an oval around this centre; the train runs round it.
	local trackCentre = at(0, 0, -1)
	local radiusX, radiusZ, segments = 7.8, 5, 16
	local function onTrack(angle: number, lift: number): Vector3
		return (trackCentre * CFrame.new(math.cos(angle) * radiusX, lift, math.sin(angle) * radiusZ)).Position
	end
	for i = 0, segments - 1 do
		local a = onTrack(i / segments * math.pi * 2, 0.15)
		local b = onTrack((i + 1) / segments * math.pi * 2, 0.15)
		local along = (b - a).Unit
		local across = Vector3.new(-along.Z, 0, along.X)
		Kit.span(model, a - along * 0.1, b + along * 0.1, 2.2, 0.3, P.DarkWood, M.WoodPlanks)
		for _, side in { -0.75, 0.75 } do
			local lift = Vector3.new(0, 0.25, 0)
			Kit.span(model, a + across * side + lift, b + across * side + lift, 0.2, 0.2, P.Rail, M.Metal)
		end
	end

	-- The haunted house the back of the track runs through.
	local houseZ, houseWidth, houseDepth, wall = -5.25, 10.4, 4.5, 6
	local boards = P.DarkStone:Lerp(P.Roof, 0.3)
	Kit.solid(Kit.block(model, at(0, wall / 2, -7.3), V(houseWidth, wall, 0.4), boards, M.WoodPlanks))
	Kit.solid(Kit.block(model, at(0, wall / 2, -3.2), V(houseWidth, wall, 0.4), boards, M.WoodPlanks))
	for side = -1, 1, 2 do
		local x = side * (houseWidth / 2 - 0.2)
		Kit.solid(Kit.block(model, at(x, wall / 2, -6.65), V(0.4, wall, 0.9), boards, M.WoodPlanks))
		Kit.block(model, at(x, 4.7, -4.8), V(0.4, 2.6, 2.8), boards, M.WoodPlanks)
	end
	Pieces.roof(model, at(0, 0, houseZ), houseWidth, houseDepth, wall, 3, P.Roof, 0.15)
	for side = -1, 1, 2 do
		local window = at(side * 2.8, 3.6, -2.95)
		Kit.glow(model, window, V(1.3, 1.6, 0.1), W.Toxic)
		Kit.block(model, window * CFrame.new(0, 0, 0.08), V(0.12, 1.7, 0.06), P.DarkWood, M.Wood)
		Kit.block(model, window * CFrame.new(0, 0, 0.08), V(1.4, 0.12, 0.06), P.DarkWood, M.Wood)
	end
	Kit.block(model, at(0, 1.5, -2.95), V(2.2, 3, 0.1), P.Eye)
	Pieces.sign(model, at(0, 5.3, -2.85), Vector2.new(6, 0.9), Theme.Upgrades.attraction_3.DisplayName, W.Red)
	Kit.solid(Kit.block(model, at(0, wall + 3.5, houseZ), V(1.4, 1.4, 1.4), boards, M.WoodPlanks))
	Kit.glow(model, at(0, wall + 3.5, houseZ + 0.72), V(0.5, 0.7, 0.05), W.Red)
	Kit.post(model, at(0, wall + 5, houseZ), 1.6, 0.15, P.Metal, M.Metal)
	for side = -1, 1, 2 do
		Pieces.cobweb(
			model,
			point(at, side * 5, wall - 0.1, -2.9),
			point(at, side * 5, wall - 2.1, -2.9),
			point(at, side * 3.2, wall - 0.1, -2.9)
		)
	end
	local inside = Kit.block(model, at(0, 3, houseZ), V(0.2, 0.2, 0.2), P.Bat)
	inside.Transparency = 1
	Kit.light(inside, W.Toxic, 14, 1.5, true)

	-- The platform, where a skeleton is still waiting for its ride.
	Kit.solid(Kit.block(model, at(0, 0.3, 6.7), V(7.4, 0.6, 2.2), P.DarkWood, M.WoodPlanks))
	for _, x in { -3.4, 3.4 } do
		Kit.solid(Kit.post(model, at(x, 2.4, 7.4), 3.6, 0.3, P.DarkWood, M.Wood))
	end
	Kit.block(model, at(0, 4.3, 6.7), V(7.6, 0.25, 2.4), P.Roof, M.Slate)
	Pieces.lantern(model, at(0, 3.6, 6.7), 0.8, W.Red, 12)
	Pieces.skeleton(model, at(-2.4, 0.6, 6.2), 1.8)
	Pieces.gravestone(model, at(-8.4, 0, 6.6), 1.1)
	Pieces.reaper(model, at(8.2, 0, 6.6, -0.4), 5)

	-- The train: three cars the client drives round the track.
	local train = Kit.model(model, "Train")
	local centre = trackCentre * CFrame.new(0, 0.55, 0)
	local gap = 0.5
	for index = 1, 3 do
		local angle = -(index - 1) * gap
		local spot = (centre * CFrame.new(math.cos(angle) * radiusX, 0, math.sin(angle) * radiusZ)).Position
		local heading = centre:VectorToWorldSpace(Vector3.new(-math.sin(angle) * radiusX, 0, math.cos(angle) * radiusZ))
		trainCar(train, CFrame.lookAt(spot, spot + heading), index)
	end
	train.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	train:SetAttribute("TrackCentre", centre)
	train:SetAttribute("RadiusX", radiusX)
	train:SetAttribute("RadiusZ", radiusZ)
	train:SetAttribute("LapSeconds", 16)
	train:SetAttribute("Gap", gap)
	train:AddTag("Train")

	-- Ghosts haunting the place.
	for _, spec in { { 0, 4, 0.2, 1.8, 4 }, { 6.6, 8.6, -5.5, 1.5, 5 }, { -6.8, 6.4, 5.4, 1.4, 3.5 } } do
		local spot = at(spec[1], spec[2], spec[3])
		Kit.float(Pieces.ghost(model, spot, spec[4]), spot, 0.8, spec[5])
	end

	Pieces.mist(model, at(0, 0.7, 0), Vector2.new(18, 14), 1.2)
	Kit.wash(model, point(at, 9.2, 0.6, 7.6), point(at, 0, 4, -5), W.Red, 24, 3)
	Kit.wash(model, point(at, -9.2, 0.6, 7.6), point(at, 0, 4, -5), W.Toxic, 24, 3)
	return model
end

-- Everything else a building gets: the shared upgrades with no model of
-- their own string lanterns in their colour across its front (the first)
-- or back (the second), and each tier of a path puts up a pennant in the
-- path's colour at one of its corners, so a path's progress shows as flags
-- going up round the building.
local Balance = require(script.Parent.Parent.Parent.Config.Balance)
local CORNERS = { { -1, 1 }, { 1, 1 }, { 1, -1 }, { -1, -1 } }

local function pathFlag(color: Color3, tier: number)
	return function(origin: CFrame, size: Vector3): Model
		local model, at = addOn(origin)
		local corner = CORNERS[(tier - 1) % #CORNERS + 1]
		local x, z = corner[1] * (size.X / 2 - 0.3), corner[2] * (size.Z / 2 - 0.3)
		local height = size.Y + 3
		Kit.post(model, at(x, height / 2, z), height, 0.25, P.DarkWood, M.Wood)
		Kit.glow(model, at(x, height + 0.25, z), V(0.5, 0.5, 0.5), color, true)
		-- Flying in over the building, not out over the paths.
		local yaw = if corner[1] < 0 then -math.pi / 2 else math.pi / 2
		Pieces.pennant(model, at(x, height - 1, z, yaw), 2.4, 1.4, color)
		return model
	end
end

local function sharedLights(color: Color3, index: number)
	return function(origin: CFrame, size: Vector3): Model
		local model, at = addOn(origin)
		local z = (if index == 1 then 1 else -1) * (size.Z / 2 - 0.4)
		local height = size.Y + 1.5
		local tops = {}
		for side = -1, 1, 2 do
			local x = side * (size.X / 2 - 1.2)
			Kit.post(model, at(x, height / 2, z), height, 0.25, P.DarkWood, M.Wood)
			Kit.glow(model, at(x, height + 0.3, z), V(0.6, 0.6, 0.6), color, true)
			table.insert(tops, point(at, x, height, z))
		end
		Pieces.stringLights(model, tops[1], tops[2], 1, { color, P.Candle })
		return model
	end
end

local sharedSoFar: { [string]: number } = {}
for _, upgrade in Balance.Upgrades do
	local building = upgrade.Building
	if building and not upgrade.Path then
		sharedSoFar[building] = (sharedSoFar[building] or 0) + 1
	end
	if building and not (Props :: any)[upgrade.Id] then
		if upgrade.Path then
			local tier = tonumber(string.match(upgrade.Id, "_(%d+)$")) or 1
			local color = Kit.color(Theme.Paths[building][upgrade.Path].Color);
			(Props :: any)[upgrade.Id] = pathFlag(color, tier)
		else
			local color = Kit.color(Theme.Upgrades[upgrade.Id].Color);
			(Props :: any)[upgrade.Id] = sharedLights(color, sharedSoFar[building])
		end
	end
end

return Props
