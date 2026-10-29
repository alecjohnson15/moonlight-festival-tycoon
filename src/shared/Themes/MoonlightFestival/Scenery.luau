-- Dresses the world around the builds. Scenery.plot dresses one plot: a
-- fence with lantern posts in the plot's own colour, string lights, an arch
-- over the gate, a cobbled walkway, mist and clutter in the corners, all clear
-- of the slots and buttons in Config/Layout. Scenery.world does the plaza and
-- the haunted land around the plots: lamps, a bonfire, a graveyard with a
-- crypt, a pond, a windmill, dead woods and circling bats. It returns the
-- terrain to fill as a list, for the server to paint.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.Config.Layout)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

export type Fill = {
	Shape: string,
	Material: string,
	CFrame: CFrame?,
	Size: Vector3?,
	Centre: Vector3?,
	Radius: number?,
	Height: number?,
}

export type Site = {
	Plots: { BasePart },
	Plaza: BasePart?,
	Spawns: { BasePart },
}

local Scenery = {}

-- The direction from (x, z) towards the middle, as a turn about Y.
local function inward(x: number, z: number): number
	return math.atan2(-x, -z)
end

function Scenery.plot(plot: BasePart, index: number, parent: Instance): Model
	plot.Material = M.Grass
	plot.Color = Kit.color(Theme.Look.PlotGround)
	local floor = plot.CFrame * CFrame.new(0, plot.Size.Y / 2, 0)
	local function at(x: number, y: number, z: number, yaw: number?): CFrame
		return floor * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	local function point(x: number, y: number, z: number): Vector3
		return at(x, y, z).Position
	end

	local model = Kit.model(parent, plot.Name)
	local random = Kit.random(index * 101)
	local wash = P.PlotWashes[(index - 1) % #P.PlotWashes + 1]
	local bulbs = { wash, P.Candle }
	local edge = Layout.PlotSize / 2 - 1
	local gate = Layout.Gate
	local opening = gate.Size[1] / 2 + 3.5

	-- A cobbled walkway from the gate down the middle, between the buttons.
	Kit.block(model, at(-1, 0.05, -0.3), V(10, 0.1, 91.4), Kit.color(Theme.Look.Path), M.Cobblestone)

	-- The fence, open at the gate.
	Pieces.fence(model, point(-edge, 0, edge), point(-edge, 0, -edge), 3)
	Pieces.fence(model, point(edge, 0, edge), point(edge, 0, -edge), 3)
	Pieces.fence(model, point(-edge, 0, -edge), point(edge, 0, -edge), 3)
	Pieces.fence(model, point(-edge, 0, edge), point(-opening, 0, edge), 3)
	Pieces.fence(model, point(opening, 0, edge), point(edge, 0, edge), 3)

	-- Lantern posts around the edge, lit in this plot's colour, with string
	-- lights between them.
	local inset = edge - 1.5
	local ring = {
		{ -inset, inset },
		{ -inset, 0 },
		{ -inset, -inset },
		{ -24, -inset },
		{ 24, -inset },
		{ inset, -inset },
		{ inset, 0 },
		{ inset, inset },
	}
	local tops = {}
	for _, spot in ring do
		local x, z = spot[1], spot[2]
		table.insert(tops, Pieces.lanternPost(model, at(x, 0, z, inward(x, z)), 7.5, wash, 18))
	end
	for i = 1, #tops - 1 do
		Pieces.stringLights(model, tops[i], tops[i + 1], 2, bulbs)
	end

	-- The arch over the gate: stone pillars topped with jack-o'-lanterns, a
	-- wooden arc with a skull at its peak, and lights strung along it.
	local pillarX, pillarHeight = opening - 1.5, 10
	for side = -1, 1, 2 do
		local x = side * pillarX
		Kit.solid(Kit.block(model, at(x, pillarHeight / 2, gate.Z), V(2, pillarHeight, 2), P.DarkStone, M.Slate))
		Kit.block(model, at(x, pillarHeight + 0.2, gate.Z), V(2.4, 0.4, 2.4), P.Stone, M.Slate)
		Pieces.jackOLantern(model, at(x, pillarHeight + 0.4, gate.Z), 1.8, true)
	end
	local arc = {}
	for i = 0, 8 do
		local angle = math.pi * (1 - i / 8)
		table.insert(arc, point(math.cos(angle) * pillarX, pillarHeight + 0.4 + math.sin(angle) * 3, gate.Z))
	end
	for i = 1, #arc - 1 do
		Kit.span(model, arc[i], arc[i + 1], 1.2, 0.8, P.DarkWood, M.Wood)
		local lift = Vector3.new(0, 0.6, 0)
		Pieces.stringLights(model, arc[i] + lift, arc[i + 1] + lift, 0, bulbs)
	end
	local skull = at(0, pillarHeight + 3.9, gate.Z + 0.3)
	Kit.ball(model, skull, V(1.3, 1.2, 1.2), P.Bone)
	for side = -1, 1, 2 do
		Kit.glow(model, skull * CFrame.new(side * 0.28, 0.08, 0.56), V(0.3, 0.3, 0.1), W.Red, true)
	end
	Pieces.stringLights(model, tops[#tops], arc[#arc] + Vector3.new(0, 0.4, 0), 1.5, bulbs)
	Pieces.stringLights(model, arc[1] + Vector3.new(0, 0.4, 0), tops[1], 1.5, bulbs)

	-- Clutter in the corners and along the sides, clear of everything built.
	local function corner(x: number, z: number, scary: boolean)
		local yaw = inward(x, z)
		if scary then
			Pieces.gravestone(model, at(x, 0, z, yaw), random.number(1.2, 1.8))
			Pieces.gravestone(model, at(x + 2.5, 0, z + 1, yaw + 0.3), random.number(1, 1.4))
			Pieces.skeleton(model, at(x - 2.2, 0, z - 1.5, yaw), 1.8)
		else
			Pieces.hayBale(model, at(x, 0, z, yaw))
			Pieces.jackOLantern(model, at(x + 1, 1.5, z, yaw), 1.3, false)
			Pieces.corn(model, at(x - 2.5, 0, z - 1.5), 4, random)
		end
		Pieces.pumpkin(model, at(x + 1.5, 0, z - 2.5, random.number(0, 3)), random.number(1, 1.6))
	end
	corner(-41, 41, false)
	corner(41, 41, true)
	corner(-41, -41, true)
	corner(41, -41, false)
	Pieces.barrel(model, at(-43, 0, 14), 2)
	Pieces.barrel(model, at(-42, 0, 16.5), 1.7)
	Pieces.corn(model, at(43, 0, 12), 4.5, random)
	Pieces.gravestone(model, at(42, 0, 8, -math.pi / 2), 1.4)
	for _, x in { -10, 8 } do
		Pieces.pumpkin(model, at(x, 0, -43, random.number(0, 3)), random.number(1, 1.5))
	end
	Pieces.cobweb(model, point(-pillarX + 1, pillarHeight, gate.Z + 1.1), point(-pillarX + 1, pillarHeight - 2.4, gate.Z + 1.1), point(-pillarX + 3.2, pillarHeight + 1.6, gate.Z + 1.1))

	-- Ground mist, and green wisps drifting over the grass.
	Pieces.mist(model, at(0, 1, 0), Vector2.new(90, 90), 4)
	local air = Kit.block(model, at(0, 5, 0), V(90, 8, 90), P.Firefly)
	air.Name = "Wisps"
	air.Transparency = 1
	air.CanQuery = false
	Kit.new("ParticleEmitter", air, {
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 5,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Color = ColorSequence.new(P.Firefly),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	})
	return model
end

-- A crypt: a little stone tomb with pillars and a green glow behind its door.
local function crypt(parent: Instance, base: CFrame)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 0.3, 0), V(9, 0.6, 8), P.DarkStone, M.Slate))
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 3.1, -0.5), V(7, 5, 6), P.Stone, M.Slate))
	for _, x in { -3, 3 } do
		Kit.solid(Kit.post(parent, base * CFrame.new(x, 3.1, 3), 5, 0.8, P.Stone, M.Slate))
	end
	Kit.block(parent, base * CFrame.new(0, 5.85, 0), V(8, 0.5, 7.5), P.DarkStone, M.Slate)
	for side = -1, 1, 2 do
		Kit.wedge(
			parent,
			base * CFrame.new(side * 2, 7.1, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
			V(7.5, 2, 4),
			P.DarkStone,
			M.Slate
		)
	end
	Kit.block(parent, base * CFrame.new(0, 2.1, 2.55), V(2.4, 3.4, 0.1), P.Eye)
	local slit = Kit.glow(parent, base * CFrame.new(0, 2.1, 2.62), V(0.15, 3, 0.05), W.Toxic)
	Kit.light(slit, W.Toxic, 16, 2, true)
	local skull = base * CFrame.new(0, 5.2, 2.6)
	Kit.ball(parent, skull, V(0.9, 0.8, 0.5), P.Bone)
	for side = -1, 1, 2 do
		Kit.ball(parent, skull * CFrame.new(side * 0.2, 0.05, 0.22), V(0.2, 0.22, 0.06), P.Eye)
	end
end

-- An old windmill with ragged sails turning slowly.
local function windmill(parent: Instance, base: CFrame)
	local boards = P.DarkWood:Lerp(P.Stone, 0.2)
	for level = 0, 3 do
		local width = 7 - level * 1.1
		Kit.solid(Kit.block(parent, base * CFrame.new(0, 2 + level * 4, 0), V(width, 4, width), boards, M.WoodPlanks))
	end
	Pieces.roof(parent, base * CFrame.new(0, 0, 0), 3.8, 3.8, 16, 3, P.Roof, 0.3)
	local window = Kit.glow(parent, base * CFrame.new(0, 9, 2.45), V(1, 1.4, 0.1), W.Red)
	Kit.light(window, W.Red, 14, 1.5, true)

	local hub = base * CFrame.new(0, 14, 2.6)
	local sails = Kit.model(parent, "Sails")
	Kit.ball(sails, hub, V(1.2, 1.2, 1.2), P.DarkWood, M.Wood)
	for blade = 0, 3 do
		local turn = hub * CFrame.Angles(0, 0, blade * math.pi / 2)
		local length = if blade == 2 then 5 else 9
		Kit.block(sails, turn * CFrame.new(0, length / 2 + 0.5, 0.3), V(0.3, length, 0.2), P.DarkWood, M.Wood)
		Kit.block(sails, turn * CFrame.new(0.9, length / 2 + 1, 0.3), V(1.6, length - 1, 0.1), P.Plaster:Lerp(P.Bat, 0.4), M.Fabric)
	end
	Kit.float(sails, hub, 0, 1, 24, Vector3.new(0, 0, 1))
end

-- Whether (x, z) is clear of every box, each { x, z, half width, half depth }.
local function clear(boxes: { { number } }, x: number, z: number, margin: number): boolean
	for _, box in boxes do
		if math.abs(x - box[1]) < box[3] + margin and math.abs(z - box[2]) < box[4] + margin then
			return false
		end
	end
	return true
end

function Scenery.world(site: Site, parent: Instance): { Fill }
	local fills: { Fill } = {}
	local random = Kit.random(2027)

	-- Everything is laid out from the plots and the plaza, in world space.
	local boxes: { { number } } = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local function addBox(part: BasePart)
		local position, half = part.CFrame.Position, part.Size / 2
		table.insert(boxes, { position.X, position.Z, half.X, half.Z })
		minX, maxX = math.min(minX, position.X - half.X), math.max(maxX, position.X + half.X)
		minZ, maxZ = math.min(minZ, position.Z - half.Z), math.max(maxZ, position.Z + half.Z)
	end
	for _, plot in site.Plots do
		addBox(plot)
	end
	local plaza = site.Plaza
	if plaza then
		addBox(plaza)
		plaza.Material = M.Cobblestone
		plaza.Color = Kit.color(Theme.Look.Plaza)
	end
	for _, spawn in site.Spawns do
		local position = spawn.CFrame.Position
		table.insert(boxes, { position.X, position.Z, 6, 6 })
	end
	-- The terrain's top is at y = 0; things on the plaza stand on its top.
	local plazaTop = if plaza then plaza.CFrame.Position.Y + plaza.Size.Y / 2 else 0
	local frontZ = maxZ
	local middleX = (minX + maxX) / 2
	local function at(x: number, z: number, yaw: number?, y: number?): CFrame
		return CFrame.new(x, y or 0, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	local function claim(x: number, z: number, halfWidth: number, halfDepth: number)
		table.insert(boxes, { x, z, halfWidth, halfDepth })
	end

	-- The ground: one wide sheet of grass with its top at y = 0, and hills
	-- around the edge so the woods don't end at a flat horizon.
	local function snap(value: number): number
		return math.floor(value / 4 + 0.5) * 4
	end
	local left, right = snap(minX - 112), snap(maxX + 112)
	local back, front = snap(minZ - 200), snap(maxZ + 200)
	table.insert(fills, {
		Shape = "Block",
		Material = "Grass",
		CFrame = CFrame.new((left + right) / 2, -8, (back + front) / 2),
		Size = V(right - left, 16, front - back),
	})
	for i = 0, 6 do
		local x = left + (right - left) * i / 6 + random.number(-30, 30)
		table.insert(fills, { Shape = "Ball", Material = "Grass", Centre = V(x, -34, back - 20), Radius = random.number(70, 95) })
		table.insert(fills, { Shape = "Ball", Material = "Grass", Centre = V(x, -34, front + 20), Radius = random.number(70, 95) })
	end
	for _, x in { left - 20, right + 20 } do
		for i = 0, 3 do
			local z = back + (front - back) * i / 3
			table.insert(fills, { Shape = "Ball", Material = "Grass", Centre = V(x, -34, z), Radius = random.number(70, 95) })
		end
	end

	-- Lamps along the back of the plaza, with lights strung between them.
	if plaza then
		local half = plaza.Size / 2
		local backEdge = plaza.CFrame.Position.Z + half.Z
		local tops = {}
		local count = math.floor(plaza.Size.X / 40)
		for i = 0, count do
			local x = plaza.CFrame.Position.X - half.X + 20 + i * (plaza.Size.X - 40) / count
			local lit = i % 2 == 0
			table.insert(
				tops,
				Pieces.lanternPost(parent, at(x, backEdge - 1.5, math.pi, plazaTop), 8, P.Candle, if lit then 22 else nil)
			)
			if i % 3 == 1 then
				Pieces.corn(parent, at(x + 6, backEdge - 2, 0, plazaTop), 4.5, random)
				Pieces.jackOLantern(parent, at(x + 9, backEdge - 2.5, math.pi, plazaTop), 1.5, false)
			end
		end
		for i = 1, #tops - 1 do
			Pieces.stringLights(parent, tops[i], tops[i + 1], 2.5, { P.Candle, W.Red, W.Purple, W.Toxic })
		end
		frontZ = backEdge
	end

	-- A gateway out of the plaza towards the bonfire, with the festival's name.
	local gateZ = frontZ + 4
	for side = -1, 1, 2 do
		Kit.solid(Kit.block(parent, at(middleX + side * 7, gateZ) * CFrame.new(0, 6, 0), V(1.6, 12, 1.6), P.DarkWood, M.Wood))
		Pieces.jackOLantern(parent, at(middleX + side * 7, gateZ) * CFrame.new(0, 12, 0), 1.8, true)
	end
	for _, yaw in { 0, math.pi } do
		Pieces.sign(parent, at(middleX, gateZ, yaw) * CFrame.new(0, 10.5, 0.15), Vector2.new(12, 2.2), Theme.Name, P.Candle)
	end
	Kit.block(parent, at(middleX, frontZ + 6) * CFrame.new(0, 0.05, 0), V(8, 0.1, 12), Kit.color(Theme.Look.Path), M.Cobblestone)
	claim(middleX, gateZ, 9, 3)

	-- The bonfire, with log benches round it and a guest who never left.
	local fireZ = frontZ + 22
	local fire = at(middleX, fireZ)
	claim(middleX, fireZ, 14, 14)
	for i = 0, 9 do
		local angle = i * math.pi / 5
		Kit.ball(parent, fire * CFrame.new(math.cos(angle) * 4.5, 0.4, math.sin(angle) * 4.5), V(1.4, 0.9, 1.2), P.DarkStone, M.Slate)
	end
	for i = 0, 3 do
		Kit.log(parent, fire * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, i * math.pi / 4, 0.25), 5, 0.6, P.Trunk, M.Wood)
	end
	local flames = Kit.block(parent, fire * CFrame.new(0, 1.2, 0), V(2, 1, 2), P.Trunk)
	flames.Transparency = 1
	Kit.new("Fire", flames, { Size = 8, Heat = 10, Color = W.Orange, SecondaryColor = P.Candle })
	Kit.light(flames, P.Ember, 50, 3, true)
	Kit.new("ParticleEmitter", flames, {
		Rate = 12,
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = V(0, 2, 0),
		Size = NumberSequence.new(0.25, 0),
		Color = ColorSequence.new(P.Ember),
		LightEmission = 1,
	})
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local spot = fire * CFrame.new(math.cos(angle) * 9, 0, math.sin(angle) * 9)
		Kit.solid(Kit.log(parent, spot * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0.6, 0), 5, 1.2, P.Trunk, M.Wood))
		if i == 1 then
			local seat = spot * CFrame.Angles(0, -angle + math.pi / 2, 0)
			Pieces.skeleton(parent, seat * CFrame.new(0, 1.1, 0.2) * CFrame.Angles(0, math.pi, 0), 2)
		end
	end

	-- A fenced graveyard to one side of the bonfire, with a crypt at the back.
	local yardX, yardZ, yardWidth, yardDepth = middleX - 70, fireZ + 10, 56, 36
	claim(yardX, yardZ, yardWidth / 2 + 4, yardDepth / 2 + 4)
	local function yard(x: number, z: number, yaw: number?): CFrame
		return at(yardX + x, yardZ + z, yaw)
	end
	local hw, hd = yardWidth / 2, yardDepth / 2
	Pieces.fence(parent, yard(-hw, -hd).Position, yard(-4, -hd).Position, 2.4)
	Pieces.fence(parent, yard(4, -hd).Position, yard(hw, -hd).Position, 2.4)
	Pieces.fence(parent, yard(-hw, hd).Position, yard(hw, hd).Position, 2.4)
	Pieces.fence(parent, yard(-hw, -hd).Position, yard(-hw, hd).Position, 2.4)
	Pieces.fence(parent, yard(hw, -hd).Position, yard(hw, hd).Position, 2.4)
	for row = 0, 3 do
		for column = 0, 7 do
			local x = -hw + 5 + column * 6.5 + random.number(-1, 1)
			local z = -hd + 5 + row * 5.5 + random.number(-0.8, 0.8)
			if math.abs(x) > 3.5 and not (row == 3 and math.abs(x) < 9) then
				Pieces.gravestone(parent, yard(x, z, math.pi + random.number(-0.2, 0.2)), random.number(1.2, 2.1))
			end
		end
	end
	crypt(parent, yard(0, hd - 6, math.pi))
	for side = -1, 1, 2 do
		Pieces.reaper(parent, yard(side * 6, -hd + 3, math.pi), 7)
		Pieces.bareTree(parent, yard(side * (hw - 4), hd - 4), 18, random)
		Pieces.lanternPost(parent, yard(side * 4, -hd - 1, math.pi), 6, W.Toxic, 16)
		Kit.wash(parent, yard(side * (hw - 1), -hd + 1).Position + V(0, 0.4, 0), yard(0, 0).Position + V(0, 3, 0), W.Toxic, 40, 2)
	end
	Pieces.mist(parent, yard(0, 0) * CFrame.new(0, 1, 0), Vector2.new(yardWidth, yardDepth), 6)

	-- A pond off to the other side, with lanterns floating on it.
	local pondX, pondZ, pondRadius = middleX + 72, fireZ + 18, 18
	claim(pondX, pondZ, pondRadius + 6, pondRadius + 6)
	table.insert(fills, { Shape = "Cylinder", Material = "Mud", CFrame = CFrame.new(pondX, -1, pondZ), Height = 2, Radius = pondRadius + 4 })
	table.insert(fills, { Shape = "Cylinder", Material = "Water", CFrame = CFrame.new(pondX, -2.5, pondZ), Height = 5, Radius = pondRadius })
	for i = 0, 4 do
		local angle = i * math.pi * 2 / 5 + random.number(-0.3, 0.3)
		local distance = random.number(4, pondRadius - 4)
		local spot = at(pondX + math.cos(angle) * distance, pondZ + math.sin(angle) * distance) * CFrame.new(0, 0.6, 0)
		local lantern = Kit.model(parent, "FloatingLantern")
		Pieces.lantern(lantern, spot, 1, P.Candle, if i < 2 then 14 else nil)
		Kit.float(lantern, spot, 0.3, random.number(3, 5))
	end

	-- The windmill on the far side of the pond.
	local millX, millZ = pondX + 46, fireZ + 40
	claim(millX, millZ, 12, 12)
	windmill(parent, at(millX, millZ, math.pi))

	-- Bats circling high over the plaza.
	local swarm = Kit.model(parent, "Bats")
	local swarmCentre = at(middleX, frontZ - 10) * CFrame.new(0, 40, 0)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local spot = (swarmCentre * CFrame.new(math.cos(angle) * 30, random.number(-5, 5), -math.sin(angle) * 30)).Position
		Pieces.bat(swarm, CFrame.lookAt(spot, spot + V(math.sin(angle), 0, math.cos(angle))), 2.2)
	end
	Kit.float(swarm, swarmCentre, 3, 6, 20)

	-- Woods of dead and autumn trees everywhere else, with things among them.
	local function scatter(
		fromX: number,
		toX: number,
		fromZ: number,
		toZ: number,
		step: number,
		chance: number,
		minHeight: number,
		maxHeight: number
	)
		for x = fromX, toX, step do
			for z = fromZ, toZ, step do
				local tx, tz = x + random.number(-step / 3, step / 3), z + random.number(-step / 3, step / 3)
				local roll = random.number(0, 1)
				local height = random.number(minHeight, maxHeight)
				-- A tree's crown or branches reach about half its height out.
				if roll < chance and clear(boxes, tx, tz, height * 0.5 + 1) then
					local spot = at(tx, tz, random.number(0, math.pi * 2))
					if random.number(0, 1) < 0.55 then
						Pieces.bareTree(parent, spot, height, random)
					else
						Pieces.tree(parent, spot, height, random)
					end
				elseif roll < chance + 0.06 and clear(boxes, tx, tz, 3) then
					local spot = at(tx, tz, random.number(0, math.pi * 2))
					local what = random.integer(1, 3)
					if what == 1 then
						Pieces.gravestone(parent, spot, random.number(1.2, 1.8))
					elseif what == 2 then
						Pieces.jackOLantern(parent, spot, random.number(1.2, 2), false)
					else
						Pieces.pumpkin(parent, spot, random.number(1.2, 2.2))
					end
				end
			end
		end
	end
	scatter(left + 10, right - 10, back + 30, minZ - 14, 20, 0.5, 14, 24)
	scatter(left + 10, right - 10, frontZ + 8, front - 30, 20, 0.45, 14, 24)
	scatter(left + 10, minX - 12, minZ, frontZ, 18, 0.5, 14, 24)
	scatter(maxX + 12, right - 10, minZ, frontZ, 18, 0.5, 14, 24)
	-- Between the plots, a few trees in each gap.
	for i = 1, #site.Plots - 1 do
		local a, b = site.Plots[i], site.Plots[i + 1]
		local gapX = (a.CFrame.Position.X + b.CFrame.Position.X) / 2
		scatter(gapX, gapX, a.CFrame.Position.Z - 36, a.CFrame.Position.Z + 36, 18, 0.8, 9, 14)
	end

	-- Mist rolling through the woods behind the plots and beyond the plaza.
	Pieces.mist(parent, CFrame.new(middleX, 1.5, minZ - 60), Vector2.new(right - left, 90), 18)
	Pieces.mist(parent, CFrame.new(middleX, 1.5, frontZ + 60), Vector2.new(right - left, 90), 14)

	-- No terrain under the plots or the plaza: their floors are the ground
	-- there. Terrain sits only half a stud below a floor, so the grass (and its
	-- animated blades) would otherwise show through it and bury buy buttons.
	local floors = table.clone(site.Plots)
	if plaza then
		table.insert(floors, plaza)
	end
	for _, floor in floors do
		local top = floor.CFrame.Position.Y + floor.Size.Y / 2 + 4
		local bottom = -24
		local position = floor.CFrame.Position
		table.insert(fills, {
			Shape = "Block",
			Material = "Air",
			CFrame = CFrame.new(position.X, (top + bottom) / 2, position.Z) * floor.CFrame.Rotation,
			Size = V(floor.Size.X, top - bottom, floor.Size.Z),
		})
	end
	return fills
end

return Scenery
