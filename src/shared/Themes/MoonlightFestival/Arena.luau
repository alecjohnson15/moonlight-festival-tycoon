-- The PvP arena's look: the wall round the stage, its entrance arch and signs,
-- braziers with beams of light that show through the fog, a ghost referee,
-- the pumpkin bonker the arena lends to anyone who walks in empty-handed, and
-- the name, colours and sounds of every weapon's special move. Its words are
-- with the rest of the pack's, in Strings.
--
-- The stage itself (the round floor and its ramp) is made by ArenaService;
-- this only dresses it. Everything here stays outside the fighting circle,
-- apart from flat markings on the floor, and off the ramp.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Config = require(script.Parent.Parent.Parent.Config.Arena)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

local Arena = {}

-- Each weapon's special move: its name on the button, the two colours its
-- effects are drawn in, and its Flair, which picks the effect the client
-- draws (see client/ArenaEffects). Premium weapons get the biggest ones.
Arena.Specials = {
	bonker = { Name = "Pumpkin Pound", Color = "#FF8A2A", Accent = "#FFD27A", Flair = "Pumpkin" },
	mallet = { Name = "Ground Thump", Color = "#D9A35B", Accent = "#FFE9C2", Flair = "Dust" },
	broom = { Name = "Broom Dash", Color = "#A45CFF", Accent = "#E8D6FF", Flair = "Sparkles" },
	claws = { Name = "Moon Pounce", Color = "#FF4A4A", Accent = "#FFD6D6", Flair = "Claws" },
	moon_saber = { Name = "Crescent Wave", Color = "#9FD8FF", Accent = "#FFFFFF", Flair = "Crescent" },
	thunder_hammer = { Name = "Thunderfall", Color = "#4FC3FF", Accent = "#FFFFFF", Flair = "Lightning" },
	ghost_blade = { Name = "Phantom Crescent", Color = "#BFFFEA", Accent = "#6DFFC4", Flair = "Ghosts" },
	reaper_scythe = { Name = "Soul Whirl", Color = "#5CFF4A", Accent = "#E8E2CC", Flair = "Souls" },
	trident = { Name = "Riptide Charge", Color = "#2F9BFF", Accent = "#BFF4FF", Flair = "Water" },
	foxfire_fan = { Name = "Foxfire Whirl", Color = "#4A6BFF", Accent = "#C9F2FF", Flair = "Foxfire" },
}

-- Sounds as Roblox asset ids ("rbxassetid://123"), empty for silent. The
-- originals are in assets/audio (made by tools/make_arena_sounds.py).
Arena.Sounds = {
	Bonk = { Id = "", Volume = 0.6 },
	KnockOut = { Id = "", Volume = 0.7 },
	Special = { Id = "", Volume = 0.6 },
	Thunder = { Id = "", Volume = 0.7 },
}

-- The top of the stage, at its middle, facing the entrance (-Z).
local function topOf(stage: BasePart): CFrame
	local height = if stage.Shape == Enum.PartType.Cylinder then stage.Size.X else stage.Size.Y
	local position = stage.CFrame.Position
	return CFrame.new(position.X, position.Y + height / 2, position.Z)
end

-- A stone bowl of fire on a short pillar, with a beam of light rising out of
-- it that shows through the fog from the plaza.
local function brazier(parent: Instance, base: CFrame, color: Color3)
	Kit.solid(Kit.block(parent, base * CFrame.new(0, 1.5, 0), V(1.8, 3, 1.8), P.DarkStone, M.Slate))
	Kit.solid(Kit.post(parent, base * CFrame.new(0, 3.3, 0), 0.6, 3, P.Stone, M.Slate))
	local coals = Kit.glow(parent, base * CFrame.new(0, 3.65, 0), V(2.2, 0.3, 2.2), P.Ember)
	Kit.new("Fire", coals, { Size = 5, Heat = 9, Color = color, SecondaryColor = P.Candle })
	Kit.light(coals, color, 30, 2.5, true)
	local beam = Kit.glow(parent, base * CFrame.new(0, 40, 0), V(0.8, 72, 0.8), color)
	beam.Transparency = 0.45
end

function Arena.dress(stage: BasePart, parent: Instance): Model
	local model = Kit.model(parent, "Arena")
	stage.Material = M.Slate
	stage.Color = P.DarkStone:Lerp(P.Stone, 0.35)
	local ramp = stage.Parent and stage.Parent:FindFirstChild("Ramp")
	if ramp and ramp:IsA("BasePart") then
		ramp.Material = M.Slate
		ramp.Color = P.DarkStone
	end

	local centre = topOf(stage)
	local radius = Config.Radius
	local ground = -Config.Height
	-- A point angle radians round from the entrance, distance out from the
	-- middle and y above the stage.
	local function point(angle: number, distance: number, y: number): Vector3
		return (centre * CFrame.new(math.sin(angle) * distance, y, -math.cos(angle) * distance)).Position
	end
	-- Standing at that point, facing the middle.
	local function facingIn(angle: number, distance: number, y: number): CFrame
		local spot = point(angle, distance, y)
		return CFrame.lookAt(spot, Vector3.new(centre.Position.X, spot.Y, centre.Position.Z))
	end

	-- Flat markings: a glowing ring just inside the wall, and a crescent moon
	-- in the middle.
	local ringCount = 40
	for i = 0, ringCount - 1 do
		local a, b = i / ringCount * math.pi * 2, (i + 1) / ringCount * math.pi * 2
		Kit.span(model, point(a, radius - 2.5, 0.03), point(b, radius - 2.5, 0.03), 0.5, 0.06, W.Purple, M.Neon)
	end
	Kit.post(model, centre * CFrame.new(0, 0.02, 0), 0.04, 16, P.DarkStone, M.Slate)
	Kit.post(model, centre * CFrame.new(0, 0.04, 0), 0.04, 11, P.Moon, M.Neon)
	Kit.post(model, centre * CFrame.new(2.6, 0.06, -1), 0.04, 9.6, P.DarkStone, M.Slate)

	-- The wall: low stone, open at the entrance, with pillars topped with
	-- jack-o'-lanterns every few stretches.
	local wallAt = radius - 0.8
	local gap = math.asin((Config.EntranceWidth / 2 + 1) / wallAt)
	local stretches = 30
	local step = (math.pi * 2 - gap * 2) / stretches
	for i = 0, stretches - 1 do
		local a, b = gap + i * step, gap + (i + 1) * step
		local from, to = point(a, wallAt, 1.5), point(b, wallAt, 1.5)
		local along = (to - from).Unit * 0.25
		Kit.solid(Kit.span(model, from - along, to + along, 1.2, 3, P.DarkStone, M.Slate))
		Kit.span(model, point(a, wallAt, 3.2) - along, point(b, wallAt, 3.2) + along, 1.6, 0.4, P.Stone, M.Slate)
	end
	for i = 0, stretches, 5 do
		local angle = gap + i * step
		local pillar = facingIn(angle, wallAt, 0)
		Kit.solid(Kit.block(model, pillar * CFrame.new(0, 2.5, 0), V(2, 5, 2), P.DarkStone, M.Slate))
		Kit.block(model, pillar * CFrame.new(0, 5.2, 0), V(2.4, 0.4, 2.4), P.Stone, M.Slate)
		Pieces.jackOLantern(model, pillar * CFrame.new(0, 5.4, 0), 1.6, i % 10 == 5)
	end
	-- Skeleton fans sitting on the wall, facing the fight.
	for _, angle in { math.pi * 0.55, math.pi, math.pi * 1.45 } do
		Pieces.skeleton(model, facingIn(angle, wallAt + 0.3, 3.4) * CFrame.Angles(0, math.pi, 0), 2)
	end

	-- The entrance: two tall pillars, an arch between them with the arena's
	-- name on both faces, and lights strung along it.
	local halfGap = Config.EntranceWidth / 2 + 1.2
	local frontZ = -wallAt
	local tops = {}
	for side = -1, 1, 2 do
		local base = centre * CFrame.new(side * halfGap, 0, frontZ)
		Kit.solid(Kit.block(model, base * CFrame.new(0, 4.5, 0), V(2.2, 9, 2.2), P.DarkStone, M.Slate))
		Kit.block(model, base * CFrame.new(0, 9.2, 0), V(2.6, 0.4, 2.6), P.Stone, M.Slate)
		Pieces.jackOLantern(model, base * CFrame.new(0, 9.4, 0) * CFrame.Angles(0, math.pi, 0), 2, true)
		table.insert(tops, (base * CFrame.new(0, 8.6, 0)).Position)
	end
	Kit.span(model, tops[1], tops[2], 1, 1, P.DarkWood, M.Wood)
	for _, facing in { { -0.15, math.pi }, { 0.15, 0 } } do
		Pieces.sign(
			model,
			centre * CFrame.new(0, 10.6, frontZ + facing[1]) * CFrame.Angles(0, facing[2], 0),
			Vector2.new(halfGap * 2 - 3, 2.6),
			Theme.Strings.ArenaSign,
			P.Candle
		)
	end
	Pieces.stringLights(
		model,
		tops[1] + V(0, -0.6, 0),
		tops[2] + V(0, -0.6, 0),
		1.2,
		{ W.Red, P.Candle, W.Purple, W.Toxic }
	)

	-- A signpost beside the ramp with the rules.
	local post = centre * CFrame.new(halfGap + 4, ground, frontZ - Config.RampLength / 2) * CFrame.Angles(0, math.pi, 0)
	Kit.solid(Kit.post(model, post * CFrame.new(0, 2, 0), 4, 0.4, P.DarkWood, M.Wood))
	Pieces.sign(model, post * CFrame.new(0, 3.6, 0.32), Vector2.new(7, 1.8), Theme.Strings.ArenaRules, P.Candle)

	-- Braziers round the outside, two of them washing the stage in colour.
	local colors = { W.Purple, W.Toxic, W.Red, W.Purple }
	for i, angle in { math.pi * 0.3, math.pi * 0.75, math.pi * 1.25, math.pi * 1.7 } do
		local spot = point(angle, radius + 3, ground)
		brazier(model, CFrame.new(spot), colors[i])
		if i == 1 or i == 4 then
			Kit.wash(model, point(angle, radius + 3, 6), centre.Position, colors[i], 60, 2)
		end
	end

	-- A ghost referee floating high over the middle, turning to watch.
	local referee = Pieces.ghost(model, centre * CFrame.new(0, 17, 0), 3)
	Kit.float(referee, centre * CFrame.new(0, 17, 0), 1.2, 4, 14)
	return model
end

-- The bonker the arena lends: a jack-o'-lantern on a stick. Built like every
-- held item, with the grip at the origin, +Y up and -Z forward, and welded to
-- its Handle so it can be carried.
function Arena.bonker(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Theme.Strings.ArenaBonker
	tool.ToolTip = Theme.Strings.ArenaBonkerTip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Weapon", "bonker")

	local handle = Kit.block(tool, CFrame.new(0, 1.4, 0), V(0.35, 3.6, 0.35), P.Wood, M.Wood)
	handle.Name = "Handle"
	Kit.block(tool, CFrame.new(0, 0.1, 0), V(0.45, 1.3, 0.45), P.DarkWood, M.Fabric)
	Kit.block(tool, CFrame.new(0, 3.05, 0), V(0.6, 0.25, 0.6), P.Metal, M.Metal)
	Pieces.jackOLantern(tool, CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0), 2.2, false)

	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part ~= handle then
				Kit.new("Weld", part, { Part0 = handle, Part1 = part, C0 = handle.CFrame:Inverse() * part.CFrame })
			end
		end
	end
	tool.Grip = CFrame.new(0, -1.4, 0)
	return tool
end

return Arena
