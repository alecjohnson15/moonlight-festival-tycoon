-- Things players hold or carry: the weapons (as Roblox Tools), the four radio
-- parts, and the block of ice a frozen player is stuck in. Tools are built
-- with their business end along the Handle's -Z and up along +Y, so with
-- the default Grip they point where the player faces.

local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)

local Gear = {}

local WOOD = Enum.Material.Wood
local METAL = Enum.Material.DiamondPlate

-- Unanchors every part in a model and welds it to root, so the whole thing
-- moves with root (a Tool's Handle, a character's head, a carried part).
function Gear.weld(container: Instance, root: BasePart)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			if descendant ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
end

local function tool(name: string, weaponId: string): (Tool, Part, CFrame)
	local item = Instance.new("Tool")
	item.Name = name
	item.CanBeDropped = false
	item.RequiresHandle = true
	item:SetAttribute("Weapon", weaponId)
	local handle = Kit.block(item, CFrame.new(), Vector3.new(0.5, 0.5, 1.2), Palette.Bark, WOOD)
	handle.Name = "Handle"
	return item, handle, CFrame.new()
end

-- Builds the Tool for a weapon in Config/Weapons, with its display name.
function Gear.weapon(weaponId: string, name: string): Tool
	local item, handle, at = tool(name, weaponId)
	if weaponId == "Torch" then
		handle.Size = Vector3.new(0.5, 0.5, 3)
		handle.CFrame = at * CFrame.new(0, 0, -0.6)
		Kit.post(
			item,
			at * CFrame.new(0, 0, -2.2) * CFrame.Angles(math.pi / 2, 0, 0),
			0.8,
			0.9,
			Palette.MetalDark,
			METAL
		)
		local flame = Kit.glow(item, at * CFrame.new(0, 0.2, -2.9), Vector3.new(0.9, 1.3, 0.9), Palette.Ember, true)
		flame.Name = "Flame"
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = Palette.Ember
		fire.SecondaryColor = Palette.Flame
		fire.Parent = flame
		Kit.light(flame, Palette.Warm, 14, 1)
	elseif weaponId == "EmberSling" then
		Kit.span(item, at * Vector3.new(0, 0, -0.4), at * Vector3.new(-0.7, 1.4, -0.9), 0.3, 0.3, Palette.Log, WOOD)
		Kit.span(item, at * Vector3.new(0, 0, -0.4), at * Vector3.new(0.7, 1.4, -0.9), 0.3, 0.3, Palette.Log, WOOD)
		Kit.span(item, at * Vector3.new(-0.7, 1.4, -0.9), at * Vector3.new(0.7, 1.4, -0.9), 0.08, 0.08, Palette.Rope)
		local ember = Kit.glow(item, at * CFrame.new(0, 1.3, -0.8), Vector3.new(0.5, 0.5, 0.5), Palette.Ember, true)
		ember.Name = "Flame"
	elseif weaponId == "FlarePistol" then
		handle.Size = Vector3.new(0.5, 1.2, 0.6)
		handle.Color = Palette.Cloth
		Kit.log(
			item,
			at * CFrame.new(0, 0.6, -0.9) * CFrame.Angles(0, math.pi / 2, 0),
			2,
			0.7,
			Palette.Cloth,
			Enum.Material.SmoothPlastic
		)
		Kit.log(item, at * CFrame.new(0, 0.6, -1.95) * CFrame.Angles(0, math.pi / 2, 0), 0.2, 0.8, Palette.Gold, METAL)
		local tip =
			Kit.glow(item, at * CFrame.new(0, 0.6, -2.05), Vector3.new(0.4, 0.4, 0.1), Color3.fromRGB(255, 79, 160))
		tip.Name = "Flame"
	elseif weaponId == "BlazeThrower" then
		-- A bellows: two boards and a leather bag, with a brass nozzle.
		Kit.block(
			item,
			at * CFrame.new(0, 0.4, -1) * CFrame.Angles(0.15, 0, 0),
			Vector3.new(1.4, 0.2, 2),
			Palette.Plank,
			WOOD
		)
		Kit.block(
			item,
			at * CFrame.new(0, -0.3, -1) * CFrame.Angles(-0.15, 0, 0),
			Vector3.new(1.4, 0.2, 2),
			Palette.Plank,
			WOOD
		)
		Kit.ball(item, at * CFrame.new(0, 0.05, -1), Vector3.new(1.3, 0.8, 1.8), Palette.Bark, Enum.Material.Leather)
		Kit.log(item, at * CFrame.new(0, 0.05, -2.4) * CFrame.Angles(0, math.pi / 2, 0), 1.2, 0.4, Palette.Gold, METAL)
		local tip = Kit.glow(item, at * CFrame.new(0, 0.05, -3), Vector3.new(0.5, 0.5, 0.2), Palette.Flame, true)
		tip.Name = "Flame"
	elseif weaponId == "SunstoneCannon" then
		handle.Size = Vector3.new(0.6, 0.6, 1.4)
		Kit.log(
			item,
			at * CFrame.new(0, 0.7, -1.2) * CFrame.Angles(0, math.pi / 2, 0),
			3.6,
			1.3,
			Palette.MetalDark,
			METAL
		)
		Kit.log(item, at * CFrame.new(0, 0.7, -3) * CFrame.Angles(0, math.pi / 2, 0), 0.4, 1.6, Palette.Gold, METAL)
		Kit.log(item, at * CFrame.new(0, 0.7, 0.6) * CFrame.Angles(0, math.pi / 2, 0), 0.6, 1.5, Palette.Gold, METAL)
		local sun = Kit.glow(
			item,
			at * CFrame.new(0, 1.7, -0.8),
			Vector3.new(0.9, 0.9, 0.9),
			Color3.fromRGB(255, 228, 92),
			true
		)
		sun.Name = "Flame"
	end
	Gear.weld(item, handle)
	return item
end

-- A radio part (Generator, Battery, Lamp or Antenna), centred on its own
-- origin. The server freezes it in an ice block at its landmark, then hangs
-- it on the back of whoever carries it, then fits it into the radio.
function Gear.radioPart(parent: Instance, partId: string): Model
	local model = Kit.model(parent, partId)
	local core: BasePart
	if partId == "Generator" then
		core = Kit.block(model, CFrame.new(), Vector3.new(2.4, 2, 1.8), Palette.RoofTeal, METAL)
		Kit.log(model, CFrame.new(0, 0, -1.1) * CFrame.Angles(0, math.pi / 2, 0), 0.4, 1.4, Palette.MetalDark, METAL)
		Kit.glow(model, CFrame.new(0.8, 0.6, -0.95), Vector3.new(0.3, 0.3, 0.1), Palette.FrostEye, true)
	elseif partId == "Battery" then
		core = Kit.block(model, CFrame.new(), Vector3.new(1.6, 2.4, 1.6), Palette.Gold, METAL)
		Kit.post(model, CFrame.new(-0.4, 1.4, 0), 0.4, 0.4, Palette.RoofRed, METAL)
		Kit.post(model, CFrame.new(0.4, 1.4, 0), 0.4, 0.4, Palette.Black, METAL)
		Kit.glow(model, CFrame.new(0, 0, -0.82), Vector3.new(0.9, 0.3, 0.05), Color3.fromRGB(124, 224, 124))
	elseif partId == "Lamp" then
		core = Kit.post(model, CFrame.new(0, -0.5, 0), 1, 1.8, Palette.MetalDark, METAL)
		local glass = Kit.glow(model, CFrame.new(0, 0.6, 0), Vector3.new(1.5, 1.5, 1.5), Palette.Flame, true)
		glass.Transparency = 0.2
	else
		core = Kit.post(model, CFrame.new(0, -0.6, 0), 0.6, 1.4, Palette.MetalDark, METAL)
		Kit.post(model, CFrame.new(0, 1, 0), 2.6, 0.25, Palette.Metal, METAL)
		Kit.block(model, CFrame.new(0, 1.6, 0), Vector3.new(1.8, 0.15, 0.15), Palette.Metal, METAL)
		Kit.glow(model, CFrame.new(0, 2.4, 0), Vector3.new(0.4, 0.4, 0.4), Palette.RoofRed, true)
	end
	core.Name = "Core"
	model.PrimaryPart = core
	return model
end

-- The block of clear ice a frozen player is stuck in until thawed.
function Gear.iceBlock(parent: Instance, at: CFrame): Part
	local block = Kit.block(parent, at, Vector3.new(4.6, 6.4, 4.6), Palette.Ice, Enum.Material.Ice)
	block.Name = "IceBlock"
	block.Transparency = 0.45
	block.Reflectance = 0.2
	return block
end

return Gear
