-- The arrival courtyard between the middle two plots, which players see
-- straight ahead when they spawn on the plaza. Its landmark is the Moonlight
-- Wheel, the one thing in the festival lit in pale moonlight gold, so it
-- stands out from the red, green and purple washes everywhere else and can
-- be seen from every plot. Courtyard.spawn dresses a spawn on the plaza: a
-- moon on its floor and glowing arrows to the plots either side.
--
-- The wheel turns on each client (client/Motion, the Wheel tag): its rim
-- spins round the hub and its gondolas hang level as they go round.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local M = Enum.Material
local V = Vector3.new

local Courtyard = {}

-- The wheel's size, from its hub. Exposed for the tests.
Courtyard.WheelRadius = 19
Courtyard.HubHeight = 25
Courtyard.Gondolas = 8
-- How far the wheel stands back from the courtyard's front edge.
Courtyard.WheelSetback = 36
local LAP_SECONDS = 70
local RING_GAP = 1.6
local LEG_SPREAD = 13

local function onRing(face: CFrame, angle: number, radius: number): Vector3
	return (face * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)).Position
end

-- A gondola hanging from pivot (its axle point, upright and facing the
-- plaza), with a striped canopy and a lantern.
local function gondola(parent: Instance, pivot: CFrame, index: number): Model
	local model = Kit.model(parent, "Gondola")
	local canopy = P.Bunting[(index - 1) % #P.Bunting + 1]
	for side = -1, 1, 2 do
		Kit.block(model, pivot * CFrame.new(side * 0.9, -0.9, 0), V(0.15, 1.8, 0.15), P.Metal, M.Metal)
	end
	Kit.ball(model, pivot * CFrame.new(0, -1.8, 0), V(3, 0.9, 2.6), canopy, M.Fabric)
	Kit.block(model, pivot * CFrame.new(0, -3.4, 0), V(2.8, 0.3, 2.4), P.DarkWood, M.Wood)
	Kit.block(model, pivot * CFrame.new(0, -2.9, 0), V(2.6, 0.7, 2.2), P.Roof, M.Wood)
	Kit.block(model, pivot * CFrame.new(0, -2.75, 1.15), V(2.8, 0.4, 0.15), canopy, M.Fabric)
	Kit.glow(model, pivot * CFrame.new(0, -2.25, 0), V(0.4, 0.5, 0.4), P.Moonlight)
	model.WorldPivot = pivot
	model:SetAttribute("Seat", index - 1)
	return model
end

-- The Moonlight Wheel, with its hub at hub (its Z axis along the axle,
-- towards the plaza) and its feet on the ground at floorY.
local function wheel(parent: Instance, hub: CFrame, floorY: number): Model
	local model = Kit.model(parent, "MoonlightWheel")
	local radius, cars = Courtyard.WheelRadius, Courtyard.Gondolas
	local rim = Kit.model(model, "Rim")

	-- Two rings of lights, a plain inner ring, and spokes, on both faces.
	for side = -1, 1, 2 do
		local face = hub * CFrame.new(0, 0, side * RING_GAP)
		local segments = 24
		for i = 0, segments - 1 do
			local a, b = i / segments * math.pi * 2, (i + 1) / segments * math.pi * 2
			local color = if i % 2 == 0 then P.Moonlight else P.Moon
			Kit.span(rim, onRing(face, a, radius), onRing(face, b, radius), 0.45, 0.45, color, M.Neon)
		end
		for i = 0, 11 do
			local a, b = i / 12 * math.pi * 2, (i + 1) / 12 * math.pi * 2
			Kit.span(rim, onRing(face, a, radius * 0.55), onRing(face, b, radius * 0.55), 0.3, 0.3, P.Metal, M.Metal)
		end
		for i = 0, cars - 1 do
			local a = (i + 0.5) / cars * math.pi * 2
			Kit.span(rim, onRing(face, a, 1.2), onRing(face, a, radius), 0.3, 0.3, P.Metal, M.Metal)
		end
	end
	-- An axle across the rings at each gondola.
	for i = 0, cars - 1 do
		local a = i / cars * math.pi * 2
		local back = onRing(hub * CFrame.new(0, 0, -RING_GAP - 0.2), a, radius)
		local front = onRing(hub * CFrame.new(0, 0, RING_GAP + 0.2), a, radius)
		Kit.span(rim, back, front, 0.3, 0.3, P.Metal, M.Metal)
	end
	-- The hub, with a glowing moon on its front.
	Kit.log(rim, hub * CFrame.Angles(0, math.pi / 2, 0), RING_GAP * 2 + 1.2, 2.6, P.DarkStone, M.Metal)
	local moon = Kit.glow(rim, hub * CFrame.new(0, 0, RING_GAP + 0.75), V(2, 2, 0.2), P.Moonlight, true)
	Kit.light(moon, P.Moonlight, 24, 1.5)
	rim.WorldPivot = hub

	for i = 1, cars do
		local a = (i - 1) / cars * math.pi * 2
		gondola(model, CFrame.new(onRing(hub, a, radius)) * hub.Rotation, i)
	end

	-- Two A-frames hold the axle, with a brace across each.
	for side = -1, 1, 2 do
		local top = (hub * CFrame.new(0, 0, side * (RING_GAP + 1.4))).Position
		for leg = -1, 1, 2 do
			local foot = (hub * CFrame.new(leg * LEG_SPREAD, 0, side * (RING_GAP + 2.6))).Position
			foot = V(foot.X, floorY, foot.Z)
			Kit.solid(Kit.span(model, top, foot, 1.1, 1.1, P.DarkStone, M.Metal))
			Kit.solid(
				Kit.block(
					model,
					CFrame.new(foot) * hub.Rotation * CFrame.new(0, 0.4, 0),
					V(2.4, 0.8, 2.4),
					P.Stone,
					M.Slate
				)
			)
		end
		local braceY = floorY + 8
		local along = (braceY - floorY) / (top.Y - floorY)
		local braceAt = hub * CFrame.new(0, braceY - hub.Position.Y, side * (RING_GAP + 2.6 - along * 1.2))
		Kit.block(model, braceAt, V(LEG_SPREAD * 2 * (1 - along) - 1, 0.6, 0.6), P.DarkStone, M.Metal)
	end

	-- The festival's name across the front legs, facing the plaza.
	local signAt = hub * CFrame.new(0, floorY + 6.5 - hub.Position.Y, RING_GAP + 3.8)
	Pieces.sign(model, signAt, Vector2.new(15, 2.4), Theme.Name, P.Moonlight)

	model:SetAttribute("Centre", hub)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("LapSeconds", LAP_SECONDS)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:AddTag("Wheel")
	return model
end

-- Dresses the courtyard whose floor is centred on centre (the middle of its
-- top face, front towards +Z and the plaza), size wide and deep. Returns its
-- floor, a part the terrain must be cleared from under.
function Courtyard.build(parent: Instance, centre: CFrame, size: Vector2): BasePart
	local model = Kit.model(parent, "Courtyard")
	local function at(x: number, z: number, yaw: number?): CFrame
		return centre * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	local floor = Kit.solid(
		Kit.block(
			model,
			centre * CFrame.new(0, -0.5, 0),
			V(size.X, 1, size.Y),
			Kit.color(Theme.Look.Plaza),
			M.Cobblestone
		)
	)
	floor.Name = "CourtyardFloor"

	local front = size.Y / 2
	local wheelZ = front - Courtyard.WheelSetback
	local hub = at(0, wheelZ) * CFrame.new(0, Courtyard.HubHeight, 0)
	wheel(model, hub, centre.Position.Y)

	-- Pale light thrown up at the wheel from the courtyard floor.
	for side = -1, 1, 2 do
		local from = at(side * 12, wheelZ + 14).Position + V(0, 0.4, 0)
		Kit.wash(model, from, hub.Position, P.Moonlight, 45, 2.5)
	end

	-- Lamps down both sides, every other one lit, and log benches facing the
	-- wheel for a place to sit.
	local inset = size.X / 2 - 2.5
	for side = -1, 1, 2 do
		for i = 0, 5 do
			local z = front - 6 - i * 16
			local lit = (i + (if side > 0 then 1 else 0)) % 2 == 0
			Pieces.lanternPost(
				model,
				at(side * inset, z, -side * math.pi / 2),
				7.5,
				P.Moonlight,
				if lit then 16 else nil
			)
		end
		local bench = at(side * 10, wheelZ + 20, 0)
		Kit.solid(Kit.log(model, bench * CFrame.new(0, 0.6, 0), 6, 1.2, P.Trunk, M.Wood))
		Pieces.pumpkin(model, bench * CFrame.new(side * 4, 0, 0.5), 1.4)
	end

	-- Mist pooling behind the wheel, where the courtyard is quieter.
	Pieces.mist(model, at(0, (wheelZ - 6 - front) / 2) * CFrame.new(0, 1, 0), Vector2.new(size.X - 6, 30), 6)
	return floor
end

-- A crescent moon drawn on a spawn's floor, and glowing arrows either side
-- of it pointing along the plaza to the plots. Nothing stands on the spawn.
function Courtyard.spawn(parent: Instance, spawn: BasePart)
	spawn.Material = M.Slate
	spawn.Color = P.DarkStone
	local gui = Kit.new("SurfaceGui", spawn, {
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 25,
		LightInfluence = 0,
		Brightness = 1.2,
	})
	local function disc(position: UDim2, scale: number, color: Color3)
		local frame = Kit.new("Frame", gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromScale(scale, scale),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
		Kit.new("UICorner", frame, { CornerRadius = UDim.new(0.5, 0) })
	end
	disc(UDim2.fromScale(0.5, 0.5), 0.7, P.Moonlight)
	disc(UDim2.fromScale(0.62, 0.42), 0.6, P.DarkStone)

	local base = spawn.CFrame * CFrame.new(0, -spawn.Size.Y / 2, 0)
	local random = Kit.random(math.floor(spawn.CFrame.Position.X + spawn.CFrame.Position.Z))
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local spot = base * CFrame.new(math.cos(angle) * 9.5, 0, math.sin(angle) * 9.5)
		if i % 4 == 1 then
			-- Grinning in at the spawn.
			local yaw = math.atan2(-math.cos(angle), -math.sin(angle))
			Pieces.jackOLantern(parent, spot * CFrame.Angles(0, yaw, 0), 1.3, true)
		else
			Pieces.pumpkin(parent, spot * CFrame.Angles(0, random.number(0, 3), 0), random.number(1, 1.3))
		end
	end
	for side = -1, 1, 2 do
		Pieces.arrowSign(parent, base * CFrame.new(side * 11, 0, -3), Theme.Strings.ClaimSign, P.Moonlight, side)
	end
end

return Courtyard
