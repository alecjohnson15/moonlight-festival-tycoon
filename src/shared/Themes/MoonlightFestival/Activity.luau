-- Ghost Catcher's look (Config/Activity): the booth at the back of each
-- plot's walkway, and the wisps a round sends out. The server builds the
-- booth when a plot is claimed; each client makes its own wisps
-- (client/Activity) and writes on the booth's Status board.

local Kit = require(script.Parent.Parent.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local Theme = require(script.Parent)

local P = Pieces.Palette
local W = P.Washes
local M = Enum.Material
local V = Vector3.new

local Activity = {}

-- The wisps' pale blue-green glow, which the booth is lit in too.
Activity.Color = W.Teal:Lerp(P.Ghost, 0.45)

-- A booth of striped canvas, facing +Z: a counter of jars holding caught
-- wisps, a big net, a ghost bobbing over one corner and the game's name over
-- the top. origin is the middle of its footprint on the floor, and it stays
-- inside size. A blank board on the back wall, named Status, is for the
-- client to say when the next round is ready.
function Activity.booth(origin: CFrame, size: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Booth"
	Kit.anchor(model, origin, size)
	local function at(x: number, y: number, z: number, yaw: number?): CFrame
		return origin * CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	local glow = Activity.Color
	local stripes = { W.Purple:Lerp(P.DarkStone, 0.35), P.Ghost:Lerp(glow, 0.3) }

	Kit.block(model, at(0, 0.15, 0), V(11, 0.3, 5.6), P.DarkWood, M.WoodPlanks)
	for i = 1, 3 do
		local x = -5 + (i - 0.5) * (10 / 3)
		Kit.solid(Kit.block(model, at(x, 3.2, -2.55), V(10 / 3, 6.1, 0.3), stripes[(i - 1) % 2 + 1], M.Fabric))
	end
	for _, x in { -5.2, 5.2 } do
		for _, z in { -2.5, 2.4 } do
			Kit.solid(Kit.post(model, at(x, 3.3, z), 6.6, 0.4, P.DarkWood, M.Wood))
		end
	end

	-- A striped awning sloping down to the front.
	local run, drop = 5.4, 1
	local slope = math.atan2(drop, run)
	local length = math.sqrt(run * run + drop * drop)
	for i = 1, 6 do
		local x = -5.5 + (i - 0.5) * (11 / 6)
		local color = stripes[(i - 1) % 2 + 1]
		Kit.block(model, at(x, 7, -0.1) * CFrame.Angles(slope, 0, 0), V(11 / 6, 0.25, length), color, M.Fabric)
	end

	-- The counter, with jars of caught wisps on top.
	Kit.solid(Kit.block(model, at(0, 1.3, 1.8), V(9, 2.6, 1.1), P.Wood, M.WoodPlanks))
	Kit.block(model, at(0, 2.7, 1.8), V(9.4, 0.2, 1.4), P.DarkWood, M.Wood)
	Kit.glow(model, at(0, 1.9, 2.37), V(9.1, 0.25, 0.06), glow)
	for i = 0, 4 do
		local x = -3.4 + i * 1.7
		local jar = Kit.glow(model, at(x, 3.25, 1.8), V(0.8, 0.9, 0.8), glow, true)
		jar.Transparency = 0.15
		if i == 2 then
			Kit.light(jar, glow, 16, 1.6, true)
		end
	end

	-- The status board on the back wall, and the name over the awning.
	local status = Pieces.sign(model, at(0, 4.6, -2.3), Vector2.new(6.4, 1.1), "", glow)
	status.Name = "Status"
	Pieces.sign(model, at(0, 7.9, 2.75), Vector2.new(8, 1.3), Theme.Strings.ActivityName, glow)

	-- A big net leaning on the right post, its hoop a ring of short rods.
	local handle = at(4.4, 0, 2.6) * CFrame.Angles(0, 0, 0.25)
	Kit.post(model, handle * CFrame.new(0, 2.4, 0), 4.8, 0.18, P.Wood, M.Wood)
	local hoop = handle * CFrame.new(0, 5.4, 0)
	for i = 0, 5 do
		local a, b = i / 6 * math.pi * 2, (i + 1) / 6 * math.pi * 2
		local p1 = (hoop * CFrame.new(math.cos(a) * 0.8, math.sin(a) * 0.8, 0)).Position
		local p2 = (hoop * CFrame.new(math.cos(b) * 0.8, math.sin(b) * 0.8, 0)).Position
		Kit.span(model, p1, p2, 0.12, 0.12, P.Metal, M.Metal)
	end
	local net = Kit.ball(model, hoop * CFrame.new(0, 0, -0.5), V(1.4, 1.4, 1), P.Cobweb, M.Fabric)
	net.Transparency = 0.5

	-- A ghost bobbing over the left corner, keeping watch.
	local ghost = Pieces.ghost(model, at(-4.4, 9.2, 1.6), 1.4)
	Kit.float(ghost, at(-4.4, 9.2, 1.6), 0.5, 3.5)
	return model
end

-- One wisp: a glowing ball with hollow eyes and a smaller ball trailing
-- under it, lit and sparkling. Its body is the PrimaryPart, at the model's
-- pivot.
function Activity.wisp(): Model
	local model = Kit.model(nil, "Wisp")
	local glow = Activity.Color
	local body = Kit.glow(model, CFrame.new(), V(1.6, 1.6, 1.6), glow, true)
	body.Name = "Body"
	Kit.glow(model, CFrame.new(0, -0.8, 0.45), V(0.8, 0.8, 0.8), glow, true)
	for side = -1, 1, 2 do
		Kit.ball(model, CFrame.new(side * 0.3, 0.15, 0.72), V(0.25, 0.4, 0.12), P.Eye)
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	Kit.light(body, glow, 10, 1.6)
	Kit.new("ParticleEmitter", body, {
		Name = "Sparkles",
		Rate = 6,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.25, 0),
		Color = ColorSequence.new(glow),
		LightEmission = 1,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	})
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

return Activity
