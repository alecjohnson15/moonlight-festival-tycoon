-- What each building's paths add to it, tier by tier (Config/Balance), in
-- the building's slot or the yard beside it (Config/Layout). A path's look
-- grows with it: each tier's model is the whole path so far, built again
-- with that tier's piece added, and it replaces the tier before (its
-- Replaces attribute names that tier), so a plot only ever holds one model
-- per path and the part budget counts the last tier alone.
--
-- Paths change how the plot plays as well as how it looks. They mark
-- VisitorStops (Kit.stop), places visitors walk to and what they do there:
-- sit at the grub bar, pick pumpkins, eat at the café, jump at a scare. Some
-- set GoodsGlow, the colour the building's goods glow as they leave. Others
-- move, through client/Motion: candy floss spins, scares pop up, ghosts
-- march and the Midnight Express pulls more cars.
--
-- Returns a builder for every path tier, by upgrade id, which Props adds to
-- its own. Each takes the slot's CFrame on the floor at its middle, the
-- slot's size and the yard's CFrame, like every add-on builder.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Balance = require(script.Parent.Parent.Parent.Config.Balance)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

type At = (x: number, y: number, z: number, yaw: number?) -> CFrame
-- Adds a path's pieces up to tier to model; at places things in the
-- building's slot and yard in its yard, both from the floor.
type Look = (model: Model, tier: number, at: At, yard: At) -> ()

local function placer(origin: CFrame): At
	return function(x, y, z, yaw)
		return origin * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	end
end

local function point(at: At, x: number, y: number, z: number): Vector3
	return at(x, y, z).Position
end

local function pathColor(building: string, path: string): Color3
	return Kit.color(Theme.Paths[building][path].Color)
end

-- A visitor stop at (x, y, z), facing (faceX, faceZ) at the same height.
local function stop(
	part: BasePart,
	at: At,
	x: number,
	y: number,
	z: number,
	faceX: number,
	faceZ: number,
	pause: number,
	options: { [string]: any }?
)
	return Kit.stop(part, CFrame.lookAt(point(at, x, y, z), point(at, faceX, y, faceZ)), pause, options)
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

-- A small ghost, centred on centre and facing +Z: cheaper than
-- Pieces.ghost, for ones that come in numbers. Returns its body.
local function ghostlet(parent: Instance, centre: CFrame, size: number): BasePart
	local body = Kit.ball(parent, centre, V(size, size * 1.25, size), P.Ghost)
	body.Transparency = 0.1
	for side = -1, 1, 2 do
		Kit.ball(
			parent,
			centre * CFrame.new(side * size * 0.18, size * 0.15, size * 0.44),
			V(size * 0.14, size * 0.24, size * 0.1),
			P.Eye
		)
	end
	return body
end

-- A plain pumpkin with a stem, standing on base: cheaper than
-- Pieces.pumpkin, for big ones.
local function bigPumpkin(parent: Instance, base: CFrame, size: number, color: Color3?): BasePart
	local height = size * 0.75
	local body = Kit.ball(parent, base * CFrame.new(0, height / 2, 0), V(size, height, size * 0.85), color or P.Pumpkin)
	Kit.post(
		parent,
		base * CFrame.new(0, height + size * 0.08, 0) * CFrame.Angles(0.2, 0, 0.1),
		size * 0.22,
		size * 0.12,
		P.Stem,
		M.Wood
	)
	return body
end

-- A round table on one leg, with a stool either side (along X) and a candle,
-- and a stop on each stool where visitors sit and eat. Returns the top.
local function cafeTable(model: Model, at: At, x: number, z: number, carry: string, umbrella: Color3?): BasePart
	local top = Kit.solid(Kit.post(model, at(x, 1.3, z), 0.15, 2, P.Wood, M.WoodPlanks))
	local leg = if umbrella then 4.2 else 1.3
	Kit.post(model, at(x, leg / 2, z), leg, 0.2, P.DarkWood, M.Wood)
	if umbrella then
		Kit.ball(model, at(x, 4.3, z), V(3.4, 0.7, 3.4), umbrella, M.Fabric)
	end
	Kit.glow(model, at(x + 0.3, 1.5, z), V(0.2, 0.3, 0.2), P.Candle)
	for side = -1, 1, 2 do
		Kit.solid(Kit.post(model, at(x + side * 1.4, 0.4, z), 0.8, 0.7, P.Trunk, M.Wood))
		stop(top, at, x + side * 1.4, 0.8, z, x, z, 4, { Pose = "Sit", Carry = carry, Chance = 0.7 })
	end
	return top
end

-- A scare that pops up out of a crate at (x, z) every few seconds, with a
-- stop beside it where visitors jump.
local function crateScare(model: Model, at: At, x: number, z: number, seconds: number)
	local crate = Kit.solid(Kit.block(model, at(x, 0.7, z), V(1.6, 1.4, 1.6), P.DarkWood, M.WoodPlanks))
	local scare = Kit.model(model, "Scare")
	local head = at(x, 0.7, z)
	Kit.ball(scare, head, V(1, 1, 1), P.Bone)
	for side = -1, 1, 2 do
		Kit.glow(scare, head * CFrame.new(side * 0.2, 0.1, 0.42), V(0.2, 0.2, 0.1), W.Red, true)
	end
	Kit.pop(scare, head, 1.6, seconds)
	stop(crate, at, x, 0, z + 2, x, z, 1.5, { Pose = "Jump", Chance = 0.8 })
end

local looks: { [string]: Look } = {}

-- Sweet Shop: the toffee apple cauldron and its table, then a candy floss
-- machine that visitors leave with candy floss from, giant lollipops, and a
-- spinning swirl over the sign.
function looks.stall_output(model, tier, _slot, at)
	local pink = pathColor("starter_stall", "output")
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
	local apples = Kit.solid(Kit.block(model, at(0, 1, -2.7), V(6, 0.2, 1.6), P.Wood, M.WoodPlanks))
	for side = -1, 1, 2 do
		Kit.solid(Kit.block(model, at(side * 2.7, 0.45, -2.7), V(0.3, 0.9, 1.3), P.DarkWood, M.Wood))
	end
	for i = 0, 4 do
		local x = -2.2 + i * 1.1
		Kit.ball(model, at(x, 1.42, -2.7), V(0.62, 0.62, 0.62), pink:Lerp(P.Candle, 0.35), M.Glass)
		Kit.post(model, at(x, 1.95, -2.7), 0.6, 0.07, P.Wood, M.Wood)
	end
	signPosts(model, at, 0, -3.6, 5.4, 4, "stall_output_1", pink)
	stop(apples, at, 3.3, 0, -1.2, 2, -2.7, 1.5, { Carry = "toffee_apple", Chance = 0.4 })

	if tier >= 2 then
		-- The candy floss machine: a tub with a pink cloud spinning in it.
		local tub = Kit.solid(Kit.post(model, at(-3, 0.6, 3), 1.2, 1.3, P.Metal, M.Metal))
		local floss = Kit.model(model, "Floss")
		Kit.ball(floss, at(-3, 1.75, 3), V(1.6, 1.2, 1.6), pink:Lerp(P.Ghost, 0.3), M.SmoothPlastic)
		Kit.float(floss, at(-3, 1.75, 3), 0.15, 1.5, 1.2)
		stop(tub, at, -1.6, 0, 3.6, -3, 3, 2, { Carry = "candy_floss", Chance = 0.8 })
	end
	if tier >= 3 then
		-- Giant lollipops either side of the front.
		for _, spec in { { 3.1, 3.3, pink }, { 3.1, -0.4, W.Teal } } do
			Kit.post(model, at(spec[1], 1.6, spec[2]), 3.2, 0.2, P.Ghost)
			Kit.glow(model, at(spec[1], 3.8, spec[2]), V(1.6, 1.6, 0.3), spec[3])
		end
	end
	if tier >= 4 then
		-- A great swirl spinning over the sign, lighting the yard pink.
		Kit.post(model, at(0, 5.5, -3.6), 3, 0.3, P.Ghost)
		local swirl = Kit.model(model, "Swirl")
		local disk = Kit.glow(swirl, at(0, 8, -3.6), V(2.8, 2.8, 0.35), pink)
		Kit.ball(swirl, at(0, 8, -3.4), V(1.4, 1.4, 0.2), P.Ghost, M.Neon)
		Kit.float(swirl, at(0, 8, -3.6), 0.2, 3, 4, Vector3.zAxis)
		Kit.light(disk, pink, 16, 1.4)
	end
end

-- Ghoul Grub Bar: a hatch beside the stall serving bowls of glowing green
-- grub, with stools where visitors sit and eat; then a queue rope, a
-- bubbling pot of grub, and a big skull with glowing eyes on the roof.
function looks.stall_vendor(model, tier, _slot, at)
	local green = pathColor("starter_stall", "vendor")
	local counter = Kit.solid(Kit.block(model, at(0, 1.2, 0.6), V(6.4, 2.4, 1.6), P.Wood, M.WoodPlanks))
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
		stop(counter, at, i * 2, 1.2, 3, i * 2, 0.6, 4, { Pose = "Sit", Carry = "grub", Chance = 0.7 })
	end

	if tier >= 2 then
		-- A rope where the queue waits its turn.
		local ropeA = Kit.solid(Kit.post(model, at(3.6, 0.55, 1.6), 1.1, 0.2, P.Metal, M.Metal))
		Kit.solid(Kit.post(model, at(3.6, 0.55, 3.8), 1.1, 0.2, P.Metal, M.Metal))
		Kit.block(model, at(3.6, 0.95, 2.7), V(0.12, 0.12, 2.2), W.Red, M.Fabric)
		for _, z in { 2, 3.4 } do
			stop(ropeA, at, 2.9, 0, z, 2.9, z - 1, 2.5, { Chance = 0.5 })
		end
	end
	if tier >= 3 then
		-- A pot of grub bubbling over at the end of the bar.
		local pot = Kit.solid(Kit.ball(model, at(-3.2, 0.6, 2.6), V(1.3, 1.1, 1.3), P.Bat, M.Metal))
		local grub = Kit.glow(model, at(-3.2, 1.1, 2.6), V(1, 0.2, 1), green, true)
		Kit.new("ParticleEmitter", grub, {
			Rate = 3,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(0.6, 1.2),
			Size = NumberSequence.new(0.35, 0.1),
			Transparency = NumberSequence.new(0.2, 1),
			Color = ColorSequence.new(green),
			LightEmission = 0.8,
			EmissionDirection = Enum.NormalId.Top,
		})
		stop(pot, at, -3.2, 0, 3.9, -3.2, 2.6, 1.5, { Carry = "grub", Chance = 0.6 })
	end
	if tier >= 4 then
		-- A big skull on the roof with eyes that light the bar green.
		local skull = at(0, 6.7, -0.9)
		Kit.ball(model, skull, V(1.6, 1.5, 1.4), P.Bone)
		local eye = Kit.glow(model, skull * CFrame.new(-0.35, 0.1, 0.62), V(0.35, 0.35, 0.15), green, true)
		Kit.glow(model, skull * CFrame.new(0.35, 0.1, 0.62), V(0.35, 0.35, 0.15), green, true)
		Kit.light(eye, green, 16, 1.6, true)
	end
end

-- Night Market: tall poles flying gold and purple banners and a crate of
-- goods; then a second market table, glowing price tags, and a string of
-- lights out to a lantern by the path.
function looks.stall_markup(model, tier, _slot, at)
	local gold = pathColor("starter_stall", "markup")
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
	local crate = Kit.solid(Kit.block(model, at(-1.6, 0.6, 2.4), V(2.2, 1.2, 1.4), P.Wood, M.WoodPlanks))
	local apple = Kit.color(Theme.Items.handmade.Color)
	for i = 0, 2 do
		Kit.ball(model, at(-2.3 + i * 0.7, 1.45, 2.4), V(0.55, 0.55, 0.55), apple)
	end
	Pieces.lantern(model, at(1.6, 1.4, 2.6), 0.8, gold, 14)
	Kit.solid(Kit.post(model, at(1.6, 0.45, 2.6), 0.9, 0.5, P.DarkStone, M.Slate))
	stop(crate, at, -1.6, 0, 3.9, -1.6, 2.4, 2, { Carry = "goodies", Chance = 0.5 })

	if tier >= 2 then
		-- A second table of goods: jars of glowing sweets.
		local stand = Kit.solid(Kit.block(model, at(3.1, 1, 1.4), V(1.6, 0.2, 2.4), P.Wood, M.WoodPlanks))
		Kit.block(model, at(3.1, 0.45, 1.4), V(1.3, 0.9, 2), P.DarkWood, M.Wood)
		for _, z in { 0.7, 2.1 } do
			Kit.glow(model, at(3.1, 1.45, z), V(0.6, 0.7, 0.6), if z < 1 then W.Purple else W.Toxic)
		end
		stop(stand, at, 3.1, 0, 3.5, 3.1, 1.4, 2, { Carry = "goodies", Chance = 0.6 })
	end
	if tier >= 3 then
		-- Price tags that glow, on the crate and the table.
		for _, spot in { at(-2.2, 0.8, 3.12), at(-1, 0.8, 3.12), at(2.28, 1, 1.4, math.pi / 2) } do
			Kit.glow(model, spot, V(0.55, 0.35, 0.05), gold)
		end
	end
	if tier >= 4 then
		-- A string of lights out to a moon lantern by the path.
		local height = 5
		Kit.solid(Kit.post(model, at(3.6, height / 2, 3.6), height, 0.3, P.DarkWood, M.Wood))
		local moon = Kit.glow(model, at(3.6, height + 0.4, 3.6), V(0.8, 0.8, 0.8), P.Moonlight, true)
		Kit.light(moon, gold, 14, 1.4)
		Pieces.stringLights(model, tops[2], point(at, 3.6, height, 3.6), 0.8, { gold, W.Purple, P.Candle }, 2.4)
	end
end

-- Bumper Crop: a bin of glowing compost with a giant pumpkin beside it that
-- grows every tier, and bigger pumpkins filling the gaps in the patch.
function looks.grower_output(model, tier, at, yard)
	local orange = pathColor("grower", "output")
	for slat = 0, 2 do
		local y = 0.35 + slat * 0.7
		Kit.solid(Kit.block(model, yard(0, y, -1.6), V(4.4, 0.5, 0.2), P.Wood, M.WoodPlanks))
		for side = -1, 1, 2 do
			Kit.solid(Kit.block(model, yard(side * 2.1, y, 0), V(0.2, 0.5, 3.4), P.Wood, M.WoodPlanks))
		end
	end
	Kit.ball(model, yard(0, 0.8, 0), V(3.6, 1.6, 3), P.Soil, M.Ground)
	local heap = Kit.glow(model, yard(0, 1.35, 0), V(2.6, 0.9, 2.2), W.Toxic, true)
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
	Kit.post(model, yard(0.8, 2.3, 0.3) * CFrame.Angles(0.2, 0, -0.25), 3, 0.12, P.Wood, M.Wood)
	-- The giant pumpkin, a little bigger every tier.
	local giant = ({ 2.6, 3, 3.4, 3.9 })[tier]
	Pieces.pumpkin(model, yard(0, 0, 3.8, 0.4), giant)
	signPosts(model, yard, 0, -2.6, 4.6, 3.6, "grower_output_1", orange)

	-- Big pumpkins in the gaps between the patch's rows, two more a tier.
	local spots = { { -6.6, 2.7 }, { 6.6, -2.7 }, { 6.6, 2.7 }, { -6.6, -2.7 }, { 0, 7.2 }, { 0, -7.2 } }
	for i = 1, (tier - 1) * 2 do
		local spot = spots[i]
		bigPumpkin(model, at(spot[1], 0.5, spot[2], i), 1.9 + tier * 0.2)
	end
	if tier >= 4 then
		-- A prize rosette on the giant.
		local rosette = Kit.glow(model, yard(0, giant * 0.5, 3.8 + giant * 0.31), V(0.9, 0.9, 0.15), W.Teal, true)
		Kit.light(rosette, orange, 10, 1)
	end
end

-- Pick-Your-Own: a stand of baskets, a sign and a wheelbarrow of pumpkins
-- beside the patch, and stops in the patch where visitors pick pumpkins
-- and leave with a basket; then more baskets, a "pick here" arrow, and
-- lanterns over the rows.
function looks.grower_vendor(model, tier, at, yard)
	local green = pathColor("grower", "vendor")
	local stand = Kit.solid(Kit.block(model, yard(0, 1.1, -0.6), V(4.2, 0.2, 1.8), P.Wood, M.WoodPlanks))
	for _, x in { -1.9, 1.9 } do
		Kit.block(model, yard(x, 0.5, -0.6), V(0.25, 1, 1.5), P.DarkWood, M.Wood)
	end
	for i = -1, 1 do
		Kit.post(model, yard(i * 1.35, 1.55, -0.6), 0.7, 1.1, P.Hay, M.Fabric)
		Kit.ball(model, yard(i * 1.35, 2.1, -0.6), V(0.8, 0.6, 0.8), P.Pumpkin)
	end
	signPosts(model, yard, 0, -2, 4.6, 3.8, "grower_vendor_1", green)
	Pieces.lantern(model, yard(2.6, 2.2, -1.9), 0.7, green, 12)
	Kit.solid(Kit.post(model, yard(2.6, 0.75, -1.9), 1.5, 0.25, P.DarkWood, M.Wood))

	-- The wheelbarrow, its handles towards the front.
	local barrow = yard(0, 0, 3.4)
	Kit.solid(Kit.block(model, barrow * CFrame.new(0, 1.1, 0), V(2, 0.9, 2.4), P.Wood, M.WoodPlanks))
	Kit.log(model, barrow * CFrame.new(0, 0.5, -1.2), 0.3, 1, P.Metal, M.Metal)
	for side = -1, 1, 2 do
		Kit.block(model, barrow * CFrame.new(side * 0.8, 0.9, 1.9), V(0.15, 0.15, 1.6), P.DarkWood, M.Wood)
		Kit.block(model, barrow * CFrame.new(side * 0.8, 0.35, 0.8), V(0.15, 0.7, 0.15), P.DarkWood, M.Wood)
	end
	for i = 0, 2 do
		Pieces.pumpkin(model, barrow * CFrame.new(-0.5 + i * 0.5, 1.5, (i % 2) * 0.6 - 0.3), 0.8)
	end

	-- Where visitors pick, in the gaps between the rows: two at first,
	-- then one more a tier.
	local picks = { { -3.6, 2.7, -3.6, 5.4 }, { 3.6, -2.7, 3.6, 0 }, { 0, 2.7, -1.8, 0 }, { -3.6, -2.7, -5.5, -5.4 } }
	for i = 1, math.min(#picks, tier + 1) do
		local pick = picks[i]
		stop(stand, at, pick[1], 0.5, pick[2], pick[3], pick[4], 2.5, { Carry = "basket", Chance = 0.6 })
	end
	if tier >= 2 then
		-- A stack of spare baskets.
		Kit.post(model, yard(-2.9, 0.4, 1.2), 0.8, 1.1, P.Hay, M.Fabric)
		Kit.post(model, yard(-2.9, 1.05, 1.2), 0.5, 1, P.Hay, M.Fabric)
	end
	if tier >= 3 then
		-- An arrow on a post pointing into the patch.
		Kit.solid(Kit.post(model, yard(2.9, 1.3, 1.2), 2.6, 0.2, P.DarkWood, M.Wood))
		Kit.glow(model, yard(2.9, 2.4, 1.2) * CFrame.Angles(0, 0, 0.1), V(1.6, 0.5, 0.12), green)
	end
	if tier >= 4 then
		-- Lanterns over the rows, so picking goes on all night.
		for i, spot in { { -8.2, 2.7 }, { 8.2, -2.7 } } do
			Kit.solid(Kit.post(model, at(spot[1], 2.25, spot[2]), 3.5, 0.25, P.DarkWood, M.Wood))
			local glow = Kit.glow(model, at(spot[1], 4.3, spot[2]), V(0.7, 0.7, 0.7), P.Candle, true)
			if i == 1 then
				Kit.light(glow, P.Candle, 18, 1.2, true)
			end
		end
	end
end

-- Enchanted Pies: an enchanting table where pies are charmed, after which
-- the kitchen's pies glow purple as they leave; then a rune circle, a
-- floating spellbook and a tall crystal.
function looks.kitchen_value(model, tier, _at, yard)
	local purple = pathColor("kitchen", "value")
	model:SetAttribute("GoodsGlow", purple)
	local top = Kit.solid(Kit.block(model, yard(0.5, 1.1, 2), V(3, 0.2, 1.6), P.DarkWood, M.Wood))
	Kit.block(model, yard(0.5, 0.5, 2), V(2.4, 1, 1.1), P.DarkStone, M.Slate)
	for _, x in { -0.3, 1.3 } do
		Kit.glow(model, yard(x, 1.35, 2), V(0.9, 0.3, 0.9), purple, true)
	end
	stop(top, yard, 0.5, 0, 3.6, 0.5, 2, 1.5, { Carry = "pie", Chance = 0.4 })
	if tier >= 2 then
		local ring = Kit.glow(model, yard(0, 0.05, -2), V(0.1, 3.6, 3.6), purple)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = yard(0, 0.05, -2) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.35
		for _, x in { -1.5, 1.5 } do
			Kit.glow(model, yard(x, 0.4, -2), V(0.25, 0.7, 0.25), P.Candle)
		end
	end
	if tier >= 3 then
		local book = Kit.model(model, "Spellbook")
		Kit.block(book, yard(0, 2.4, -2) * CFrame.Angles(0.3, 0, 0), V(1.3, 0.2, 1), P.Roof, M.Fabric)
		Kit.glow(book, yard(0, 2.52, -2) * CFrame.Angles(0.3, 0, 0), V(1.15, 0.05, 0.85), P.Moonlight)
		Kit.float(book, yard(0, 2.4, -2), 0.4, 3, 8)
	end
	if tier >= 4 then
		Kit.block(model, yard(-2.6, 0.4, -3.6), V(1.6, 0.8, 1.4), P.DarkStone, M.Slate)
		local crystal =
			Kit.glow(model, yard(-2.6, 2, -3.6) * CFrame.Angles(0, math.pi / 4, 0.2), V(0.9, 2.8, 0.9), purple)
		Kit.light(crystal, purple, 16, 1.5, true)
	end
end

-- Creepy Café: tables outside the kitchen where visitors sit and eat pie,
-- first one under an umbrella, then another, a sign, and a third table.
function looks.kitchen_vendor(model, tier, _at, yard)
	local orange = pathColor("kitchen", "vendor")
	cafeTable(model, yard, -1.6, 2.6, "pie", orange)
	if tier >= 2 then
		cafeTable(model, yard, 1.6, -1.2, "pie", W.Purple)
	end
	if tier >= 3 then
		signPosts(model, yard, 0.5, -4.4, 4.2, 3.2, "kitchen_vendor_1", orange)
	end
	if tier >= 4 then
		local top = cafeTable(model, yard, -2.1, -2.6, "pie", nil)
		Kit.light(top, P.Candle, 12, 1.2, true)
	end
end

-- Endless Maze: new rows of hedge growing out into the yard, tier by tier,
-- with lanterns, and at the last an arch over the way in.
function looks.attraction_1_capacity(model, tier, _at, yard)
	local height = 4.2
	local function hedge(x1: number, z1: number, x2: number, z2: number): BasePart
		return Kit.solid(
			Kit.span(
				model,
				point(yard, x1, height / 2, z1),
				point(yard, x2, height / 2, z2),
				1.2,
				height,
				P.Hedge,
				M.Grass
			)
		)
	end
	local first = hedge(-2.6, -5.4, -2.6, 3.6)
	Kit.post(model, yard(-2.6, height + 0.6, 3.6), 1.2, 0.2, P.DarkWood, M.Wood)
	Kit.glow(model, yard(-2.6, height + 1.4, 3.6), V(0.5, 0.7, 0.5), P.Candle)
	stop(first, yard, -1, 0, 0, -1, -3, 2.5, { Chance = 0.5 })
	if tier >= 2 then
		hedge(0.6, -3.4, 0.6, 5.4)
		stop(first, yard, 2.2, 0, -2, 2.2, -5, 2.5, { Chance = 0.5 })
	end
	if tier >= 3 then
		hedge(3.3, -5.4, 3.3, 3)
		hedge(-2, -5.4, 3.3, -5.4)
		Kit.post(model, yard(3.3, height + 0.6, 3), 1.2, 0.2, P.DarkWood, M.Wood)
		Kit.glow(model, yard(3.3, height + 1.4, 3), V(0.5, 0.7, 0.5), W.Toxic)
	end
	if tier >= 4 then
		for _, x in { -1.6, 0.2 } do
			Kit.solid(Kit.post(model, yard(x, 2.8, 5.6), 5.6, 0.4, P.DarkWood, M.Wood))
		end
		Kit.block(model, yard(-0.7, 5.8, 5.6), V(2.8, 0.4, 0.4), P.DarkWood, M.Wood)
		local moon = Kit.glow(model, yard(-0.7, 6.6, 5.6), V(1, 1, 0.2), P.Moonlight, true)
		Kit.light(moon, P.Moonlight, 14, 1.2)
	end
end

-- Scream Maze: scares that pop up as visitors pass, and make them jump: a
-- skull in a crate, then a ghost over a hedge, warning signs, and a red
-- light flickering over a hand reaching out of the ground.
function looks.attraction_1_ticket(model, tier, _at, yard)
	local red = pathColor("attraction_1", "ticket")
	crateScare(model, yard, -1.5, 1.5, 5)
	if tier >= 2 then
		local hedge = Kit.solid(Kit.block(model, yard(2.4, 1.6, -2), V(1.2, 3.2, 5), P.Hedge, M.Grass))
		local ghost = Kit.model(model, "Scare")
		local hidden = yard(2.4, 2.2, -2)
		ghostlet(ghost, hidden, 1.6)
		Kit.pop(ghost, hidden, 2.2, 6)
		stop(hedge, yard, 0.6, 0, -2, 2.4, -2, 1.5, { Pose = "Jump", Chance = 0.8 })
	end
	if tier >= 3 then
		for _, spec in { { -2.8, -4.6, 0.3 }, { 2.8, 4.4, -0.4 } } do
			Kit.solid(Kit.post(model, yard(spec[1], 1.4, spec[2]), 2.8, 0.2, P.DarkWood, M.Wood))
			Pieces.sign(
				model,
				yard(spec[1], 2.6, spec[2] + 0.15) * CFrame.Angles(0, 0, spec[3] * 0.4),
				Vector2.new(2.2, 0.8),
				Theme.Strings.ScareSign,
				red
			)
		end
	end
	if tier >= 4 then
		Kit.solid(Kit.post(model, yard(-3.4, 2.5, 4.8), 5, 0.25, P.Metal, M.Metal))
		local strobe = Kit.glow(model, yard(-3.4, 5.2, 4.8), V(0.6, 0.6, 0.6), red, true)
		Kit.light(strobe, red, 16, 2, true)
		-- A bony hand reaching out of the ground.
		local hand = yard(0.8, 0, 3.4)
		Kit.block(model, hand * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, 0.2), V(0.5, 1, 0.3), P.Bone)
		for finger = -1, 1 do
			Kit.block(
				model,
				hand * CFrame.new(finger * 0.16 + 0.1, 1.25, 0) * CFrame.Angles(0, 0, 0.2 - finger * 0.2),
				V(0.1, 0.6, 0.1),
				P.Bone
			)
		end
	end
end

-- Moon Beacon: a stone pedestal with a glowing moon, then mirrors, then a
-- beam of moonlight into the sky that can be seen from the spawn, then a
-- second beam and a halo.
function looks.attraction_2_draw(model, tier, _at, yard)
	local pale = pathColor("attraction_2", "draw")
	Kit.solid(Kit.block(model, yard(0, 0.6, 0), V(2, 1.2, 2), P.Stone, M.Slate))
	local orb = Kit.glow(model, yard(0, 1.9, 0), V(1.4, 1.4, 1.4), P.Moonlight, true)
	if tier >= 2 then
		for side = -1, 1, 2 do
			Kit.solid(Kit.post(model, yard(side * 2.4, 1, side * 2), 2, 0.25, P.Metal, M.Metal))
			Kit.glow(model, yard(side * 2.4, 2.4, side * 2, side * 0.8), V(1.2, 1.2, 0.15), pale)
		end
		local ring = Kit.glow(model, yard(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), V(0.1, 4.4, 4.4), pale)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.4
	end
	if tier >= 3 then
		Kit.light(orb, pale, 18, 1.6)
		local beams = if tier >= 4 then { 0, 0.12, -0.12 } else { 0 }
		local from = Kit.new("Attachment", orb, { Name = "BeamFrom" })
		for i, lean in beams do
			local to = Kit.new("Attachment", orb, {
				Name = `BeamTo{i}`,
				Position = Vector3.new(math.sin(lean) * 300, math.cos(lean) * 300, 0),
			})
			Kit.new("Beam", orb, {
				Attachment0 = from,
				Attachment1 = to,
				Color = ColorSequence.new(pale),
				LightEmission = 1,
				LightInfluence = 0,
				Width0 = if i == 1 then 2.4 else 1.2,
				Width1 = if i == 1 then 7 else 4,
				Transparency = NumberSequence.new(0.15, 1),
				FaceCamera = true,
				Segments = 1,
			})
		end
	end
	if tier >= 4 then
		local halo = Kit.model(model, "Halo")
		local ring = Kit.glow(halo, yard(0, 3.6, 0) * CFrame.Angles(0, 0, math.pi / 2), V(0.15, 3, 3), pale)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.5
		Kit.float(halo, yard(0, 3.6, 0), 0.4, 4, 6, Vector3.xAxis)
	end
end

-- Fortune Teller: a booth where a hooded seer reads a crystal ball, with a
-- stop where visitors sit for their fortune; then a roped queue, a sign
-- with a tarot card, and a great eye floating over the booth.
function looks.attraction_2_ticket(model, tier, _at, yard)
	local violet = pathColor("attraction_2", "ticket")
	Kit.solid(Kit.block(model, yard(-1, 2, -2.6), V(4, 4, 0.3), P.DarkWood, M.WoodPlanks))
	-- A tent roof sloping down either side.
	for side = -1, 1, 2 do
		Kit.wedge(model, yard(-1 + side * 1, 4.6, -1.4, -side * math.pi / 2), V(2.6, 1.2, 2), violet, M.Fabric)
	end
	local desk = Kit.solid(Kit.block(model, yard(-1, 0.9, -0.6), V(2, 0.2, 1.4), P.Roof, M.Fabric))
	Kit.glow(model, yard(-1, 1.4, -0.6), V(0.8, 0.8, 0.8), violet, true)
	Kit.ball(model, yard(-1, 1.6, -1.8), V(1.2, 2.2, 1), P.Robes[2], M.Fabric)
	Kit.glow(model, yard(-1, 2.4, -1.35), V(0.4, 0.15, 0.1), P.Candle)
	stop(desk, yard, -1, 0, 0.8, -1, -0.6, 3, { Chance = 0.7 })
	if tier >= 2 then
		local first = Kit.solid(Kit.post(model, yard(1.8, 0.55, 0.4), 1.1, 0.2, P.Metal, M.Metal))
		for _, z in { 2.6, 4.8 } do
			Kit.solid(Kit.post(model, yard(1.8, 0.55, z), 1.1, 0.2, P.Metal, M.Metal))
		end
		Kit.block(model, yard(1.8, 0.95, 2.6), V(0.12, 0.12, 4.4), violet, M.Fabric)
		for _, z in { 1.6, 3.2, 4.8 } do
			stop(first, yard, 0.9, 0, z, 0.9, z - 1, 3, { Chance = 0.6 })
		end
	end
	if tier >= 3 then
		Kit.solid(Kit.post(model, yard(2.8, 1.6, -1.6), 3.2, 0.25, P.DarkWood, M.Wood))
		Kit.glow(model, yard(2.8, 3.6, -1.6, -0.3), V(0.9, 1.4, 0.1), violet)
	end
	if tier >= 4 then
		local eye = Kit.model(model, "Eye")
		local white = Kit.ball(eye, yard(-1, 6.4, -1.4), V(1.6, 1.6, 1.6), P.Ghost)
		Kit.glow(eye, yard(-1, 6.4, -0.65), V(0.7, 0.7, 0.2), violet, true)
		Kit.float(eye, yard(-1, 6.4, -1.4), 0.5, 3)
		Kit.light(white, violet, 14, 1.4)
	end
end

-- The ghost train's track and timing, as Props.attraction_3 builds them, so
-- the Midnight Express's extra cars run on it (a test checks they match).
local TRAIN = { CentreZ = -1, Lift = 0.55, RadiusX = 7.8, RadiusZ = 5, LapSeconds = 16, Gap = 0.5 }

-- A plain car for the end of the train, numbered order.
local function extraCar(parent: Instance, cframe: CFrame, order: number, color: Color3): Model
	local car = Kit.model(parent, `Car{order}`)
	car:SetAttribute("Order", order)
	Kit.block(car, cframe * CFrame.new(0, 0.35, 0), V(1.9, 0.4, 2.6), P.Metal, M.Metal)
	Kit.block(car, cframe * CFrame.new(0, 1.05, 0), V(1.8, 1, 2.3), P.Roof)
	Kit.block(car, cframe * CFrame.new(0, 1.9, 1), V(1.8, 0.9, 0.3), P.Roof)
	Kit.log(car, cframe * CFrame.new(0, 0.3, 0), 2.15, 0.6, P.Bat, M.Metal)
	Kit.glow(car, cframe * CFrame.new(0, 1.15, 1.17), V(1.2, 0.3, 0.05), color)
	car.WorldPivot = cframe
	return car
end

-- Midnight Express: more cars on the ghost train, a car a tier but the
-- third, which puts up a station clock.
function looks.attraction_3_seats(model, tier, at, yard)
	local teal = pathColor("attraction_3", "seats")
	local train = Kit.model(model, "Train")
	local centre = at(0, 0, TRAIN.CentreZ) * CFrame.new(0, TRAIN.Lift, 0)
	local cars = if tier >= 4 then 3 elseif tier >= 2 then 2 else 1
	for i = 1, cars do
		local order = 3 + i
		local angle = -(order - 1) * TRAIN.Gap
		local spot =
			centre:PointToWorldSpace(Vector3.new(math.cos(angle) * TRAIN.RadiusX, 0, math.sin(angle) * TRAIN.RadiusZ))
		local heading =
			centre:VectorToWorldSpace(Vector3.new(-math.sin(angle) * TRAIN.RadiusX, 0, math.cos(angle) * TRAIN.RadiusZ))
		local car = extraCar(train, CFrame.lookAt(spot, spot + heading), order, teal)
		if i == 3 then
			Kit.light(car:FindFirstChildWhichIsA("BasePart") :: BasePart, teal, 12, 1.2)
		end
	end
	train.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	train:SetAttribute("TrackCentre", centre)
	train:SetAttribute("RadiusX", TRAIN.RadiusX)
	train:SetAttribute("RadiusZ", TRAIN.RadiusZ)
	train:SetAttribute("LapSeconds", TRAIN.LapSeconds)
	train:SetAttribute("Gap", TRAIN.Gap)
	train:AddTag("Train")
	if tier >= 3 then
		Kit.solid(Kit.post(model, yard(-2, 2.5, 4), 5, 0.3, P.DarkWood, M.Wood))
		Kit.post(model, yard(-2, 5.4, 4.1) * CFrame.Angles(math.pi / 2, 0, 0), 0.2, 1.6, P.Moonlight, M.Neon)
		Kit.block(model, yard(-2, 5.5, 4.25), V(0.08, 0.6, 0.05), P.Eye)
	end
end

-- Terror Train: a skull over the tunnel, then a loop of track in the yard,
-- flaming braziers either side of it, and a red glow inside the loop.
function looks.attraction_3_ticket(model, tier, at, yard)
	local orange = pathColor("attraction_3", "ticket")
	local skull = at(0, 3.8, -2.6)
	Kit.ball(model, skull, V(1.6, 1.4, 1), P.Bone)
	for side = -1, 1, 2 do
		Kit.glow(model, skull * CFrame.new(side * 0.35, 0.1, 0.45), V(0.35, 0.35, 0.1), orange, true)
	end
	if tier >= 2 then
		local loop = yard(0, 3.8, 0)
		local radius, pieces = 3, 6
		for i = 0, pieces - 1 do
			local a = (loop * CFrame.new(
				0,
				math.cos(i / pieces * math.pi * 2) * radius,
				math.sin(i / pieces * math.pi * 2) * radius
			)).Position
			local b = (loop * CFrame.new(
				0,
				math.cos((i + 1) / pieces * math.pi * 2) * radius,
				math.sin((i + 1) / pieces * math.pi * 2) * radius
			)).Position
			Kit.span(model, a, b, 1.6, 0.3, P.DarkWood, M.WoodPlanks)
		end
		for side = -1, 1, 2 do
			Kit.solid(Kit.post(model, yard(side * 1, 0.4, 0), 0.8, 0.4, P.Metal, M.Metal))
		end
	end
	if tier >= 3 then
		for side = -1, 1, 2 do
			local brazier = Kit.solid(Kit.post(model, yard(side * 2.6, 0.6, 3.6), 1.2, 0.9, P.Metal, M.Metal))
			Kit.new("Fire", brazier, { Size = 3, Heat = 6, Color = orange, SecondaryColor = W.Red })
		end
	end
	if tier >= 4 then
		local glow = Kit.glow(model, yard(0, 3.8, 0), V(0.6, 0.6, 0.6), W.Red, true)
		Kit.light(glow, W.Red, 16, 2, true)
	end
end

-- Ghost Parade: ghosts march out of the yard beside the station across the
-- plot and back, one more a tier but the third, which puts up a banner over
-- their way.
function looks.attraction_3_draw(model, tier, _at, yard)
	local white = pathColor("attraction_3", "draw")
	local count = if tier >= 4 then 3 elseif tier >= 2 then 2 else 1
	for i = 1, count do
		local marcher = Kit.model(model, "Marcher")
		local start = yard(-2.5 + (i - 1) * 2.2, 2.4, -4)
		local body = ghostlet(marcher, start, if i == 3 then 2 else 1.4)
		if i == 3 then
			Kit.light(body, white, 10, 1)
		end
		Kit.patrol(marcher, start, Vector3.new(0, 0, 13), 10 + i)
	end
	if tier >= 3 then
		-- A banner over their way.
		for side = -1, 1, 2 do
			Kit.solid(Kit.post(model, yard(side * 3.6, 3, 2), 6, 0.3, P.DarkWood, M.Wood))
		end
		Kit.block(model, yard(0, 5.6, 2), V(7.2, 1.2, 0.1), white:Lerp(W.Purple, 0.4), M.Fabric)
	end
end

-- Where a part is and how big, to tell which parts of a tier were already
-- there in the tier before.
local function key(part: BasePart): string
	local p, s = part.CFrame.Position, part.Size
	return string.format("%s %.2f %.2f %.2f %.2f %.2f %.2f", part.ClassName, p.X, p.Y, p.Z, s.X, s.Y, s.Z)
end

-- A builder for every path tier, by upgrade id. Parts a tier keeps from the
-- tier before are marked Kept, so only what's new plays the build-up
-- (client/BuildEffects).
local builders: { [string]: (CFrame, Vector3, CFrame?) -> Model } = {}
for _, upgrade in Balance.Upgrades do
	if upgrade.Path then
		local prefix, number = string.match(upgrade.Id, "^(.*)_(%d+)$")
		local look = looks[prefix :: string]
		local tier = tonumber(number) :: number
		assert(look, `no look for the {upgrade.Id} path`)
		builders[upgrade.Id] = function(origin: CFrame, _size: Vector3, yard: CFrame?): Model
			local model = Instance.new("Model")
			look(model, tier, placer(origin), placer(yard or origin))
			if tier > 1 then
				model:SetAttribute("Replaces", `{prefix}_{tier - 1}`)
				local before = Instance.new("Model")
				look(before, tier - 1, placer(origin), placer(yard or origin))
				local had = {}
				for _, part in before:GetDescendants() do
					if part:IsA("BasePart") then
						had[key(part)] = true
					end
				end
				before:Destroy()
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and had[key(part)] then
						part:SetAttribute("Kept", true)
					end
				end
			end
			return model
		end
	end
end

return builders
