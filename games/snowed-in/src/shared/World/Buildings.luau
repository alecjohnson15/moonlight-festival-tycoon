-- What players build (Config/Structures), as models standing on the ground
-- at the CFrame given, centred on their footprint, front along -Z. Each
-- uses no more parts than its Parts limit (tests/World.spec checks).
-- Turrets have a part named "Muzzle" where their shots start; warm things
-- carry a PointLight.

local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)

local Buildings = {}

local WOOD = Enum.Material.Wood
local SNOW = Enum.Material.Snow
local ROCK = Enum.Material.Slate
local METAL = Enum.Material.DiamondPlate

local function base(parent: Instance, name: string, at: CFrame, size: Vector3): (Model, Part)
	local model = Kit.model(parent, name)
	local root = Kit.block(model, at * CFrame.new(0, size.Y / 2, 0), size, Palette.White)
	root.Name = "Root"
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	model.PrimaryPart = root
	return model, root
end

function Buildings.WoodWall(parent: Instance, at: CFrame): Model
	local model = base(parent, "WoodWall", at, Vector3.new(8, 6, 2))
	for index = 0, 2 do
		Kit.log(
			model,
			at * CFrame.new(0, 1 + index * 1.9, 0),
			8.4,
			1.9,
			if index % 2 == 0 then Palette.Log else Palette.Plank,
			WOOD
		)
	end
	for side = -1, 1, 2 do
		Kit.post(model, at * CFrame.new(side * 3.6, 3.4, 0), 6.8, 1, Palette.Bark, WOOD)
	end
	Kit.block(model, at * CFrame.new(0, 6.1, 0), Vector3.new(8.2, 0.4, 1.6), Palette.Snow, SNOW)
	return model
end

function Buildings.StoneWall(parent: Instance, at: CFrame): Model
	local model = base(parent, "StoneWall", at, Vector3.new(8, 7, 2))
	Kit.block(model, at * CFrame.new(0, 2, 0), Vector3.new(8, 4, 2), Palette.Stone, ROCK)
	Kit.block(model, at * CFrame.new(0, 5.2, 0), Vector3.new(7.6, 2.4, 1.8), Palette.StoneDark, ROCK)
	for side = -1, 1, 2 do
		Kit.block(model, at * CFrame.new(side * 2.6, 6.8, 0), Vector3.new(2, 1.2, 2), Palette.Stone, ROCK)
	end
	Kit.block(model, at * CFrame.new(0, 7.45, 0), Vector3.new(7.8, 0.3, 1.9), Palette.Snow, SNOW)
	return model
end

function Buildings.Lantern(parent: Instance, at: CFrame): Model
	local model, root = base(parent, "Lantern", at, Vector3.new(1, 8, 1))
	root.CanCollide = false
	Kit.post(model, at * CFrame.new(0, 3.5, 0), 7, 0.5, Palette.Bark, WOOD)
	Kit.block(model, at * CFrame.new(0.9, 7, 0), Vector3.new(2.2, 0.3, 0.3), Palette.Bark, WOOD)
	local lamp = Kit.glow(model, at * CFrame.new(1.7, 6, 0), Vector3.new(1.2, 1.4, 1.2), Palette.Warm)
	lamp.Name = "Lamp"
	Kit.light(lamp, Palette.Warm, 20, 1.3, true)
	Kit.block(model, at * CFrame.new(1.7, 6.85, 0), Vector3.new(1.5, 0.3, 1.5), Palette.MetalDark, METAL)
	return model
end

function Buildings.EmberTrap(parent: Instance, at: CFrame): Model
	local model, root = base(parent, "EmberTrap", at, Vector3.new(8, 0.6, 8))
	root.CanCollide = false
	Kit.block(model, at * CFrame.new(0, 0.15, 0), Vector3.new(8, 0.3, 8), Palette.Coal, Enum.Material.Basalt)
	for index = 1, 3 do
		local angle = index * 2.1
		local coal = Kit.glow(
			model,
			at * CFrame.new(math.cos(angle) * 2.2, 0.4, math.sin(angle) * 2.2),
			Vector3.new(2, 0.6, 2),
			Palette.Ember,
			true
		)
		coal.Name = "Coal"
	end
	Kit.glow(model, at * CFrame.new(0, 0.35, 0), Vector3.new(2.4, 0.5, 2.4), Palette.Flame, true)
	return model
end

function Buildings.Campfire(parent: Instance, at: CFrame): Model
	local model, root = base(parent, "Campfire", at, Vector3.new(6, 1, 6))
	root.CanCollide = false
	for index = 1, 4 do
		local angle = index / 4 * math.pi * 2
		Kit.block(
			model,
			at * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.5, -2.8),
			Vector3.new(2.6, 1, 1.2),
			Palette.Stone,
			ROCK
		)
	end
	Kit.log(model, at * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0.5, 0), 4, 0.8, Palette.Log, WOOD)
	local flame = Kit.glow(model, at * CFrame.new(0, 1.6, 0), Vector3.new(1.8, 2.4, 1.8), Palette.Ember, true)
	flame.Name = "Flame"
	flame.Transparency = 0.2
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 8
	fire.Color = Palette.Ember
	fire.SecondaryColor = Palette.Flame
	fire.Parent = flame
	Kit.light(flame, Palette.Warm, 26, 1.6, true)
	return model
end

function Buildings.EmberTurret(parent: Instance, at: CFrame): Model
	local model = base(parent, "EmberTurret", at, Vector3.new(4, 7, 4))
	Kit.block(model, at * CFrame.new(0, 1, 0), Vector3.new(4, 2, 4), Palette.Stone, ROCK)
	Kit.post(model, at * CFrame.new(0, 3.5, 0), 3, 1.4, Palette.Bark, WOOD)
	local head = Kit.ball(model, at * CFrame.new(0, 5.6, 0), Vector3.new(3, 2.6, 3), Palette.Rust, METAL)
	head.Name = "Head"
	local barrel = Kit.log(
		model,
		at * CFrame.new(0, 5.6, -1.8) * CFrame.Angles(0, math.pi / 2, 0),
		2.6,
		1,
		Palette.MetalDark,
		METAL
	)
	barrel.Name = "Barrel"
	local muzzle = Kit.glow(model, at * CFrame.new(0, 5.6, -3.2), Vector3.new(0.8, 0.8, 0.8), Palette.Ember, true)
	muzzle.Name = "Muzzle"
	Kit.block(model, at * CFrame.new(0, 2.1, 0), Vector3.new(4.2, 0.3, 4.2), Palette.Snow, SNOW)
	return model
end

function Buildings.BlazeTower(parent: Instance, at: CFrame): Model
	local model = base(parent, "BlazeTower", at, Vector3.new(8, 12, 8))
	Kit.block(model, at * CFrame.new(0, 1.5, 0), Vector3.new(8, 3, 8), Palette.StoneDark, ROCK)
	for side = -1, 1, 2 do
		for end_ = -1, 1, 2 do
			Kit.post(model, at * CFrame.new(side * 2.8, 6, end_ * 2.8), 6, 1.2, Palette.Stone, ROCK)
		end
	end
	Kit.block(model, at * CFrame.new(0, 9.2, 0), Vector3.new(7.6, 1, 7.6), Palette.StoneDark, ROCK)
	local bowl = Kit.ball(model, at * CFrame.new(0, 10.4, 0), Vector3.new(5, 2.6, 5), Palette.Rust, METAL)
	bowl.Name = "Head"
	local muzzle = Kit.glow(model, at * CFrame.new(0, 11.4, 0), Vector3.new(3.2, 2.4, 3.2), Palette.Ember, true)
	muzzle.Name = "Muzzle"
	muzzle.Transparency = 0.15
	Kit.light(muzzle, Palette.Ember, 18, 1.2, true)
	Kit.block(model, at * CFrame.new(0, 3.1, 0), Vector3.new(8.2, 0.3, 8.2), Palette.Snow, SNOW)
	return model
end

return Buildings
