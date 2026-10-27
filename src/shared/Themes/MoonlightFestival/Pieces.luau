-- The pieces the festival's props and scenery are made of: pumpkins, lanterns,
-- ghosts, trees, fences and the rest, so the builds and the land around them
-- share one look. Each piece is placed by a CFrame on the ground under it,
-- facing +Z, and is added to parent.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Theme = require(script.Parent)

local P = Kit.palette(Theme.Palette)
local M = Enum.Material

local Pieces = { Palette = P }

-- A ribbed pumpkin. Returns the CFrame at its middle.
function Pieces.pumpkin(parent: Instance, base: CFrame, size: number): CFrame
	local height = size * 0.72
	local middle = base * CFrame.new(0, height / 2, 0)
	for rib = 0, 2 do
		local color = if rib == 1 then P.PumpkinDark else P.Pumpkin
		Kit.ball(parent, middle * CFrame.Angles(0, rib * math.pi / 3, 0), Vector3.new(size, height, size * 0.62), color)
	end
	Kit.post(
		parent,
		middle * CFrame.new(0, height / 2 + size * 0.06, 0) * CFrame.Angles(0.25, 0, 0.15),
		size * 0.28,
		size * 0.13,
		P.Stem,
		M.Wood
	)
	return middle
end

-- A pumpkin with a glowing face on its front. Lit ones also light the ground.
function Pieces.jackOLantern(parent: Instance, base: CFrame, size: number, lit: boolean?)
	local middle = Pieces.pumpkin(parent, base, size)
	local front = size * 0.43
	for side = -1, 1, 2 do
		Kit.glow(
			parent,
			middle * CFrame.new(side * size * 0.17, size * 0.1, front) * CFrame.Angles(0, 0, math.pi / 4),
			Vector3.new(size * 0.13, size * 0.13, size * 0.08),
			P.Candle
		)
	end
	local mouth =
		Kit.glow(parent, middle * CFrame.new(0, -size * 0.11, front - size * 0.01), Vector3.new(size * 0.4, size * 0.09, size * 0.08), P.Candle)
	if lit then
		Kit.light(mouth, P.Glow, size * 5, 1.4, true)
	end
end

-- A small hanging lantern, centred on centre. With range, it lights its
-- surroundings as well as glowing.
function Pieces.lantern(parent: Instance, centre: CFrame, size: number, color: Color3?, range: number?): BasePart
	local glow = color or P.Candle
	Kit.block(parent, centre * CFrame.new(0, size * 0.6, 0), Vector3.new(size * 0.9, size * 0.2, size * 0.9), P.Metal, M.Metal)
	local body = Kit.glow(parent, centre, Vector3.new(size * 0.65, size, size * 0.65), glow)
	Kit.block(parent, centre * CFrame.new(0, -size * 0.58, 0), Vector3.new(size * 0.8, size * 0.15, size * 0.8), P.Metal, M.Metal)
	if range then
		Kit.light(body, glow, range, 1.6, true)
	end
	return body
end

-- A lamp post with a lantern hanging off an arm towards +Z. Returns the top
-- of the post, for hanging string lights from.
function Pieces.lanternPost(parent: Instance, base: CFrame, height: number, color: Color3?, range: number?): Vector3
	Kit.solid(Kit.post(parent, base * CFrame.new(0, height / 2, 0), height, 0.45, P.DarkWood, M.Wood))
	Kit.block(parent, base * CFrame.new(0, height + 0.15, 0), Vector3.new(0.8, 0.3, 0.8), P.Metal, M.Metal)
	Kit.block(parent, base * CFrame.new(0, height - 0.6, 0.8), Vector3.new(0.18, 0.18, 1.6), P.Metal, M.Metal)
	Kit.block(parent, base * CFrame.new(0, height - 0.8, 1.45), Vector3.new(0.08, 0.4, 0.08), P.Metal, M.Metal)
	Pieces.lantern(parent, base * CFrame.new(0, height - 1.6, 1.45), 0.9, color, range)
	return (base * CFrame.new(0, height, 0)).Position
end

-- A string of coloured bulbs sagging between two points.
function Pieces.stringLights(parent: Instance, a: Vector3, b: Vector3, sag: number, colors: { Color3 })
	local count = math.max(2, math.floor((b - a).Magnitude / 2.2))
	for i = 1, count - 1 do
		local t = i / count
		local point = a:Lerp(b, t) - Vector3.new(0, 4 * sag * t * (1 - t), 0)
		Kit.glow(parent, CFrame.new(point), Vector3.new(0.45, 0.45, 0.45), colors[(i - 1) % #colors + 1], true)
	end
end

-- A row of little flags hanging between two points.
function Pieces.bunting(parent: Instance, a: Vector3, b: Vector3, sag: number, colors: { Color3 })
	local count = math.max(2, math.floor((b - a).Magnitude / 1.1))
	local along = CFrame.lookAt(a, b)
	for i = 1, count - 1 do
		local t = i / count
		local point = a:Lerp(b, t) - Vector3.new(0, 4 * sag * t * (1 - t) + 0.3, 0)
		Kit.block(
			parent,
			CFrame.lookAt(point, point + along.RightVector) * CFrame.Angles(0, 0, math.pi / 4),
			Vector3.new(0.55, 0.55, 0.05),
			colors[(i - 1) % #colors + 1],
			M.Fabric
		)
	end
end

-- A ghost with hollow eyes, facing +Z. It is its own model so it can float.
function Pieces.ghost(parent: Instance, centre: CFrame, size: number): Model
	local model = Kit.model(parent, "Ghost")
	local front = centre * CFrame.Angles(0, math.pi, 0)
	local body = Kit.ball(model, front, Vector3.new(size, size * 1.15, size), P.Ghost)
	body.Transparency = 0.1
	local tail = Kit.ball(
		model,
		front * CFrame.new(0, -size * 0.55, size * 0.1) * CFrame.Angles(-0.4, 0, 0),
		Vector3.new(size * 0.7, size * 0.8, size * 0.55),
		P.Ghost
	)
	tail.Transparency = 0.1
	for side = -1, 1, 2 do
		Kit.ball(
			model,
			front * CFrame.new(side * size * 0.19, size * 0.12, -size * 0.46),
			Vector3.new(size * 0.13, size * 0.22, size * 0.08),
			P.Eye
		)
		Kit.ball(
			model,
			front * CFrame.new(side * size * 0.5, -size * 0.08, -size * 0.05) * CFrame.Angles(0, 0, side * 0.5),
			Vector3.new(size * 0.35, size * 0.18, size * 0.18),
			P.Ghost
		)
	end
	Kit.ball(model, front * CFrame.new(0, -size * 0.14, -size * 0.45), Vector3.new(size * 0.2, size * 0.26, size * 0.06), P.Eye)
	Kit.light(body, P.EerieGlow, size * 4, 0.9)
	return model
end

-- An autumn tree with a round crown.
function Pieces.tree(parent: Instance, base: CFrame, height: number, random: Kit.Random)
	Kit.solid(Kit.post(parent, base * CFrame.new(0, height * 0.35, 0), height * 0.7, height * 0.09, P.Trunk, M.Wood))
	local leaves = random.pick(P.Foliage)
	for _ = 1, 3 do
		local angle = random.number(0, math.pi * 2)
		local size = height * random.number(0.38, 0.5)
		Kit.ball(
			parent,
			base * CFrame.new(math.cos(angle) * height * 0.13, height * random.number(0.6, 0.78), math.sin(angle) * height * 0.13),
			Vector3.new(size, size * 0.85, size),
			leaves:Lerp(random.pick(P.Foliage), 0.3)
		)
	end
	local top = height * 0.36
	Kit.ball(parent, base * CFrame.new(0, height * 0.9, 0), Vector3.new(top, top * 0.85, top), leaves)
end

-- A bare, crooked tree.
function Pieces.bareTree(parent: Instance, base: CFrame, height: number, random: Kit.Random)
	local width = height * 0.08
	Kit.solid(Kit.post(parent, base * CFrame.new(0, height * 0.4, 0), height * 0.8, width, P.Trunk, M.Wood))
	for i = 1, 4 do
		local angle = i * math.pi / 2 + random.number(-0.4, 0.4)
		local from = (base * CFrame.new(0, height * random.number(0.5, 0.75), 0)).Position
		local reach = height * random.number(0.25, 0.4)
		local to = (base * CFrame.new(math.cos(angle) * reach, height * random.number(0.85, 1), math.sin(angle) * reach)).Position
		Kit.span(parent, from, to, width * 0.45, width * 0.45, P.Trunk, M.Wood)
	end
end

-- A fence of posts and two rails from a to b, both on the ground.
function Pieces.fence(parent: Instance, a: Vector3, b: Vector3, height: number)
	local count = math.max(1, math.floor((b - a).Magnitude / 4 + 0.5))
	for i = 0, count do
		local point = a:Lerp(b, i / count)
		Kit.solid(
			Kit.block(
				parent,
				CFrame.lookAt(point, b) + Vector3.new(0, height / 2, 0),
				Vector3.new(0.4, height, 0.4),
				P.Wood,
				M.WoodPlanks
			)
		)
	end
	for _, y in { height * 0.35, height * 0.8 } do
		local lift = Vector3.new(0, y, 0)
		Kit.solid(Kit.span(parent, a + lift, b + lift, 0.25, 0.3, P.Wood, M.WoodPlanks))
	end
end

-- A rounded gravestone with moss on top. Friendly, not grim.
function Pieces.gravestone(parent: Instance, base: CFrame, size: number)
	local tilt = base * CFrame.Angles(0.08, 0, 0.05)
	Kit.solid(Kit.block(parent, tilt * CFrame.new(0, size * 0.5, 0), Vector3.new(size * 0.9, size, size * 0.25), P.Stone, M.Slate))
	Kit.log(
		parent,
		tilt * CFrame.new(0, size, 0) * CFrame.Angles(0, math.pi / 2, 0),
		size * 0.25,
		size * 0.9,
		P.Stone,
		M.Slate
	)
	Kit.block(parent, tilt * CFrame.new(0, size * 1.38, 0), Vector3.new(size * 0.5, size * 0.1, size * 0.27), P.Moss, M.Grass)
end

-- A clump of corn stalks.
function Pieces.corn(parent: Instance, base: CFrame, height: number, random: Kit.Random)
	for _ = 1, 3 do
		local spot = base * CFrame.new(random.number(-0.8, 0.8), 0, random.number(-0.8, 0.8))
		local tall = height * random.number(0.8, 1.1)
		Kit.post(parent, spot * CFrame.new(0, tall / 2, 0), tall, 0.18, P.CornLeaf, M.Grass)
		for leaf = 1, 2 do
			local angle = leaf * math.pi + random.number(-0.5, 0.5)
			Kit.block(
				parent,
				spot * CFrame.new(0, tall * (0.35 + leaf * 0.2), 0) * CFrame.Angles(0, angle, 0.7) * CFrame.new(0.5, 0, 0),
				Vector3.new(1.1, 0.06, 0.25),
				P.CornLeaf,
				M.Grass
			)
		end
		Kit.ball(parent, spot * CFrame.new(0.15, tall * 0.6, 0), Vector3.new(0.3, 0.7, 0.3), P.Corn)
	end
end

function Pieces.barrel(parent: Instance, base: CFrame, height: number)
	local width = height * 0.75
	Kit.solid(Kit.post(parent, base * CFrame.new(0, height / 2, 0), height, width, P.Wood, M.WoodPlanks))
	for _, y in { 0.2, 0.8 } do
		Kit.post(parent, base * CFrame.new(0, height * y, 0), height * 0.08, width + 0.08, P.Metal, M.Metal)
	end
end

function Pieces.hayBale(parent: Instance, base: CFrame)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 0.75, 0), Vector3.new(3, 1.5, 1.8), P.Hay, M.Fabric))
end

-- A gable roof over a box from x = -width / 2 to width / 2 and z = -depth / 2
-- to depth / 2, with its eaves at height (from base) and its ridge running
-- along X, rise above the eaves. The roof overhangs the front and back walls
-- by overhang.
function Pieces.roof(
	parent: Instance,
	base: CFrame,
	width: number,
	depth: number,
	height: number,
	rise: number,
	color: Color3,
	overhang: number
)
	local half = depth / 2 + overhang
	local slope = math.atan2(rise, half)
	local length = math.sqrt(half * half + rise * rise) + 0.3
	for side = -1, 1, 2 do
		Kit.solid(
			Kit.block(
				parent,
				base * CFrame.new(0, height + rise / 2, side * half / 2) * CFrame.Angles(side * slope, 0, 0),
				Vector3.new(width + 0.8, 0.4, length),
				color,
				M.Slate
			)
		)
	end
	-- The triangles under the roof at each end.
	for _, x in { -width / 2, width / 2 } do
		for side = -1, 1, 2 do
			Kit.wedge(
				parent,
				base * CFrame.new(x, height + rise / 2, side * depth / 4) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				Vector3.new(0.4, rise, depth / 2),
				P.DarkWood,
				M.WoodPlanks
			)
		end
	end
end

-- A cartoon skeleton sitting against something behind it (-Z), legs out
-- towards +Z. Spooky, not gory.
function Pieces.skeleton(parent: Instance, base: CFrame, size: number)
	local bone = P.Bone
	local hip = base * CFrame.new(0, size * 0.12, 0)
	Kit.block(parent, hip, Vector3.new(size * 0.35, size * 0.12, size * 0.18), bone)
	Kit.block(parent, hip * CFrame.new(0, size * 0.32, -size * 0.06) * CFrame.Angles(-0.2, 0, 0), Vector3.new(size * 0.08, size * 0.55, size * 0.08), bone)
	for i = 0, 2 do
		Kit.block(
			parent,
			hip * CFrame.new(0, size * (0.3 + i * 0.12), -size * 0.04 - i * 0.02) * CFrame.Angles(-0.2, 0, 0),
			Vector3.new(size * 0.38 - i * size * 0.04, size * 0.04, size * 0.2),
			bone
		)
	end
	local skull = hip * CFrame.new(0, size * 0.72, -size * 0.12)
	Kit.ball(parent, skull, Vector3.new(size * 0.3, size * 0.32, size * 0.3), bone)
	for side = -1, 1, 2 do
		Kit.ball(parent, skull * CFrame.new(side * size * 0.07, size * 0.02, size * 0.13), Vector3.new(size * 0.09, size * 0.1, size * 0.06), P.Eye)
		Kit.block(
			parent,
			hip * CFrame.new(side * size * 0.1, -size * 0.05, size * 0.3),
			Vector3.new(size * 0.07, size * 0.07, size * 0.55),
			bone
		)
		Kit.block(
			parent,
			hip * CFrame.new(side * size * 0.24, size * 0.28, size * 0.08) * CFrame.Angles(0.9, 0, side * 0.3),
			Vector3.new(size * 0.06, size * 0.4, size * 0.06),
			bone
		)
	end
end

-- A cobweb strung across a corner: threads fanning out from a corner point
-- to points along two edges, with a couple of rings across them.
function Pieces.cobweb(parent: Instance, corner: Vector3, a: Vector3, b: Vector3)
	local spokes = 4
	local ends = {}
	for i = 0, spokes do
		local tip = a:Lerp(b, i / spokes)
		table.insert(ends, tip)
		local thread = Kit.span(parent, corner, tip, 0.05, 0.05, P.Cobweb)
		thread.Transparency = 0.35
	end
	for _, ring in { 0.45, 0.8 } do
		for i = 1, spokes do
			local thread = Kit.span(parent, corner:Lerp(ends[i], ring), corner:Lerp(ends[i + 1], ring), 0.04, 0.04, P.Cobweb)
			thread.Transparency = 0.45
		end
	end
end

-- A bat with its wings spread, facing +Z.
function Pieces.bat(parent: Instance, centre: CFrame, size: number)
	Kit.ball(parent, centre, Vector3.new(size * 0.3, size * 0.3, size * 0.45), P.Bat)
	for side = -1, 1, 2 do
		Kit.wedge(
			parent,
			centre * CFrame.new(side * size * 0.45, size * 0.05, 0) * CFrame.Angles(0, side * math.pi / 2, 0),
			Vector3.new(0.05, size * 0.35, size * 0.6),
			P.Bat
		)
		Kit.glow(parent, centre * CFrame.new(side * size * 0.06, size * 0.05, size * 0.22), Vector3.new(0.12, 0.12, 0.05), P.Washes.Red)
	end
end

-- A tall hooded figure in a ragged cloak, leaning on a scythe. A statue, so it
-- never moves; its eyes glow.
function Pieces.reaper(parent: Instance, base: CFrame, height: number)
	local cloak = P.Bat:Lerp(P.Roof, 0.25)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, height * 0.12, 0), Vector3.new(height * 0.3, height * 0.24, height * 0.3), P.DarkStone, M.Slate))
	local robe = base * CFrame.new(0, height * 0.24, 0)
	for i = 0, 3 do
		local width = height * (0.3 - i * 0.04)
		Kit.block(parent, robe * CFrame.new(0, height * (0.1 + i * 0.13), 0), Vector3.new(width, height * 0.14, width * 0.8), cloak, M.Fabric)
	end
	local hood = robe * CFrame.new(0, height * 0.66, 0)
	Kit.ball(parent, hood, Vector3.new(height * 0.17, height * 0.2, height * 0.18), cloak, M.Fabric)
	Kit.ball(parent, hood * CFrame.new(0, -height * 0.01, height * 0.06), Vector3.new(height * 0.12, height * 0.14, height * 0.08), P.Eye)
	for side = -1, 1, 2 do
		Kit.glow(parent, hood * CFrame.new(side * height * 0.025, 0, height * 0.1), Vector3.new(0.18, 0.12, 0.05), P.Washes.Red)
	end
	-- The scythe: a long handle and a curved blade made of short pieces.
	local handle = robe * CFrame.new(height * 0.2, height * 0.38, height * 0.08)
	Kit.post(parent, handle, height * 0.85, height * 0.03, P.DarkWood, M.Wood)
	local top = handle * CFrame.new(0, height * 0.42, 0)
	for i = 0, 3 do
		Kit.block(
			parent,
			top * CFrame.Angles(0, 0, 0.3 + i * 0.28) * CFrame.new(-height * 0.07 * (i + 1), 0, 0),
			Vector3.new(height * 0.08, height * 0.03, 0.08),
			P.Rail,
			M.Metal
		)
	end
end

-- Low mist that drifts over an area: a flat, invisible part that breathes
-- out big, faint puffs.
function Pieces.mist(parent: Instance, cframe: CFrame, size: Vector2, rate: number)
	local area = Kit.block(parent, cframe, Vector3.new(size.X, 1, size.Y), P.Mist)
	area.Name = "Mist"
	area.Transparency = 1
	area.CanQuery = false
	Kit.new("ParticleEmitter", area, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = rate,
		Lifetime = NumberRange.new(10, 16),
		Speed = NumberRange.new(0.1, 0.35),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 8),
			NumberSequenceKeypoint.new(1, 16),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.82),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(P.Mist),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-6, 6),
		LightInfluence = 1,
	})
end

-- A sign board with text on its front (+Z).
function Pieces.sign(parent: Instance, cframe: CFrame, size: Vector2, text: string, color: Color3?)
	local board = Kit.block(parent, cframe * CFrame.Angles(0, math.pi, 0), Vector3.new(size.X, size.Y, 0.2), P.DarkWood, M.Wood)
	local gui = Kit.new("SurfaceGui", board, {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Brightness = 1.5,
	})
	Kit.new("TextLabel", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = color or P.Candle,
		TextStrokeTransparency = 0.6,
		Text = text,
	})
	return board
end

return Pieces
