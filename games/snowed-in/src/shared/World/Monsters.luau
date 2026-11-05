-- The blizzard's monsters, built from parts on each client (the server only
-- moves numbers, see shared/EnemySim). They are round, cartoonish and
-- snow-white with glowing ice-blue eyes: spooky enough for a night in a
-- blizzard, never gory. Each model's PrimaryPart "Root" sits at its feet,
-- facing -Z; parts named "Eye" glow, and the client bobs and lunges the
-- whole model rather than animating limbs.

local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)

local Monsters = {}

local SNOW = Enum.Material.Snow
local ICE = Enum.Material.Ice

local function root(model: Model, height: number): Part
	local part = Kit.block(model, CFrame.new(0, height / 2, 0), Vector3.new(1, height, 1), Palette.White)
	part.Name = "Root"
	part.Transparency = 1
	model.PrimaryPart = part
	return part
end

local function eyes(model: Model, at: CFrame, spread: number, size: number)
	for side = -1, 1, 2 do
		local eye = Kit.glow(
			model,
			at * CFrame.new(side * spread, 0, 0),
			Vector3.new(size, size * 1.2, size * 0.6),
			Palette.FrostEye,
			true
		)
		eye.Name = "Eye"
		local pupil = Kit.ball(
			model,
			at * CFrame.new(side * spread, 0, -size * 0.25),
			Vector3.new(size * 0.4, size * 0.5, size * 0.3),
			Palette.Black
		)
		pupil.Name = "Pupil"
	end
end

-- A frostling: a knee-high snow imp with icicle horns.
function Monsters.Frostling(parent: Instance): Model
	local model = Kit.model(parent, "Frostling")
	root(model, 4)
	Kit.ball(model, CFrame.new(0, 1.6, 0), Vector3.new(2.8, 2.6, 2.6), Palette.Snow, SNOW).Name = "Body"
	Kit.ball(model, CFrame.new(0, 3.4, -0.2), Vector3.new(2.4, 2.2, 2.2), Palette.Snow, SNOW).Name = "Head"
	eyes(model, CFrame.new(0, 3.6, -1.15), 0.5, 0.6)
	for side = -1, 1, 2 do
		Kit.wedge(
			model,
			CFrame.new(side * 0.7, 4.7, -0.1) * CFrame.Angles(0, 0, side * -0.3),
			Vector3.new(0.4, 1.2, 0.5),
			Palette.Ice,
			ICE
		)
		Kit.ball(model, CFrame.new(side * 1.5, 1.8, -0.3), Vector3.new(0.9, 0.9, 0.9), Palette.SnowShade, SNOW)
		Kit.ball(model, CFrame.new(side * 0.7, 0.3, -0.2), Vector3.new(1, 0.6, 1.3), Palette.SnowShade, SNOW)
	end
	return model
end

-- A snow hound: a wolf of packed snow with an icy mane.
function Monsters.SnowHound(parent: Instance): Model
	local model = Kit.model(parent, "SnowHound")
	root(model, 4.5)
	Kit.ball(model, CFrame.new(0, 2.4, 0.4), Vector3.new(2.6, 2.4, 5), Palette.SnowShade, SNOW).Name = "Body"
	Kit.ball(model, CFrame.new(0, 3.4, -2.2), Vector3.new(2.6, 2.4, 2.4), Palette.Frost, ICE)
	Kit.ball(model, CFrame.new(0, 3.6, -3), Vector3.new(2, 1.9, 2), Palette.Snow, SNOW).Name = "Head"
	Kit.ball(model, CFrame.new(0, 3.2, -4), Vector3.new(1, 0.9, 1.4), Palette.Snow, SNOW)
	Kit.ball(model, CFrame.new(0, 3.4, -4.6), Vector3.new(0.4, 0.35, 0.3), Palette.Black)
	eyes(model, CFrame.new(0, 4, -3.85), 0.45, 0.45)
	for side = -1, 1, 2 do
		Kit.wedge(model, CFrame.new(side * 0.6, 4.8, -2.8), Vector3.new(0.4, 1, 0.7), Palette.Snow, SNOW)
		for end_ = -1, 1, 2 do
			Kit.post(model, CFrame.new(side * 0.8, 0.8, 0.4 + end_ * 1.6), 1.6, 0.6, Palette.SnowShade, SNOW)
		end
	end
	Kit.wedge(model, CFrame.new(0, 3, 3.4) * CFrame.Angles(-0.9, 0, 0), Vector3.new(0.6, 0.8, 2.2), Palette.Frost, ICE)
	return model
end

-- A snow brute: three stacked boulders of snow with fists of ice.
function Monsters.SnowBrute(parent: Instance): Model
	local model = Kit.model(parent, "SnowBrute")
	root(model, 10)
	Kit.ball(model, CFrame.new(0, 2.6, 0), Vector3.new(6, 5, 6), Palette.SnowShade, SNOW).Name = "Body"
	Kit.ball(model, CFrame.new(0, 6.2, 0), Vector3.new(5, 4.4, 5), Palette.Snow, SNOW)
	Kit.ball(model, CFrame.new(0, 9.2, -0.2), Vector3.new(3.6, 3.2, 3.4), Palette.Snow, SNOW).Name = "Head"
	eyes(model, CFrame.new(0, 9.5, -1.8), 0.7, 0.7)
	Kit.block(model, CFrame.new(0, 8.5, -1.7), Vector3.new(1.6, 0.3, 0.3), Palette.Black)
	for side = -1, 1, 2 do
		Kit.ball(model, CFrame.new(side * 3.4, 6.4, -0.4), Vector3.new(1.8, 1.8, 1.8), Palette.SnowShade, SNOW)
		Kit.block(
			model,
			CFrame.new(side * 3.9, 4, -0.8) * CFrame.Angles(0.3, 0, side * 0.2),
			Vector3.new(2.2, 3, 2.2),
			Palette.Ice,
			ICE
		).Transparency =
			0.1
		Kit.wedge(
			model,
			CFrame.new(side * 1.2, 4.3, 2.4) * CFrame.Angles(-0.4, 0, 0),
			Vector3.new(0.8, 1.6, 0.8),
			Palette.Ice,
			ICE
		)
	end
	return model
end

-- An ice wisp: a floating crystal with a glowing heart, circled by shards.
function Monsters.IceWisp(parent: Instance): Model
	local model = Kit.model(parent, "IceWisp")
	root(model, 3)
	local heart = Kit.glow(
		model,
		CFrame.new(0, 6.5, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4),
		Vector3.new(1.6, 1.6, 1.6),
		Palette.FrostEye
	)
	heart.Name = "Eye"
	local shell = Kit.block(
		model,
		CFrame.new(0, 6.5, 0) * CFrame.Angles(math.pi / 4, 0.3, math.pi / 4),
		Vector3.new(2.6, 2.6, 2.6),
		Palette.Ice,
		ICE
	)
	shell.Name = "Body"
	shell.Transparency = 0.45
	for index = 1, 3 do
		local angle = index / 3 * math.pi * 2
		local shard = Kit.wedge(
			model,
			CFrame.new(math.cos(angle) * 2.2, 6.5 + math.sin(angle * 2) * 0.6, math.sin(angle) * 2.2)
				* CFrame.Angles(0, angle, 0.5),
			Vector3.new(0.4, 1.4, 0.6),
			Palette.Frost,
			ICE
		)
		shard.Transparency = 0.2
	end
	return model
end

local function yeti(parent: Instance, name: string, fur: Color3, glow: boolean): Model
	local model = Kit.model(parent, name)
	root(model, 16)
	Kit.ball(model, CFrame.new(0, 6, 0), Vector3.new(10, 9, 8), fur, Enum.Material.Fabric).Name = "Body"
	Kit.ball(model, CFrame.new(0, 5.4, -2.8), Vector3.new(6, 6, 3), Palette.Frost, SNOW)
	Kit.ball(model, CFrame.new(0, 12, -0.8), Vector3.new(6, 5.4, 5.4), fur, Enum.Material.Fabric).Name = "Head"
	Kit.ball(model, CFrame.new(0, 11.4, -3.2), Vector3.new(4, 3, 1.4), Palette.Frost, SNOW)
	Kit.block(model, CFrame.new(0, 10.6, -3.85), Vector3.new(2.4, 0.5, 0.3), Palette.Black)
	eyes(model, CFrame.new(0, 12.8, -3.4), 1.1, 0.95)
	for side = -1, 1, 2 do
		-- Curled horns of ice.
		Kit.wedge(
			model,
			CFrame.new(side * 2.6, 15, -0.4) * CFrame.Angles(0, 0, side * -0.6),
			Vector3.new(0.9, 2.6, 1.2),
			Palette.Ice,
			ICE
		)
		-- Long arms with big fists.
		Kit.ball(
			model,
			CFrame.new(side * 5.6, 6.4, -0.6) * CFrame.Angles(0, 0, side * 0.25),
			Vector3.new(3, 8, 3),
			fur,
			Enum.Material.Fabric
		)
		Kit.ball(model, CFrame.new(side * 6.4, 2.4, -1.2), Vector3.new(3.4, 3, 3.4), Palette.Frost, SNOW)
		Kit.ball(model, CFrame.new(side * 2.4, 0.9, -0.6), Vector3.new(3.2, 1.8, 4.4), Palette.Frost, SNOW)
	end
	if glow then
		-- The Elder Yeti wears a crown of glowing icicles.
		for index = -2, 2 do
			local spike = Kit.glow(
				model,
				CFrame.new(index * 0.9, 15.2 - math.abs(index) * 0.3, -0.6),
				Vector3.new(0.5, 1.8 - math.abs(index) * 0.3, 0.5),
				Palette.IceGlow
			)
			spike.Transparency = 0.15
		end
	end
	return model
end

function Monsters.Yeti(parent: Instance): Model
	return yeti(parent, "Yeti", Color3.fromRGB(221, 231, 242), false)
end

function Monsters.ElderYeti(parent: Instance): Model
	return yeti(parent, "ElderYeti", Color3.fromRGB(176, 198, 228), true)
end

-- How high each kind floats above the ground.
Monsters.Hover = {
	IceWisp = 1.5,
}

return Monsters
