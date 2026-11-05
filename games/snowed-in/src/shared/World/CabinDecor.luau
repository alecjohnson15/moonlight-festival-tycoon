-- The cabin decorations in Config/Decor, built at a cabin's spots (see
-- Landmarks.cabin). CabinDecor.apply puts a player's chosen set on a
-- cabin, replacing what was there; window glows recolour the cabin's
-- windows rather than adding parts.

local Decor = require(script.Parent.Parent.Config.Decor)
local Kit = require(script.Parent.Parent.Kit)
local Palette = require(script.Parent.Palette)

local CabinDecor = {}

local SNOW = Enum.Material.Snow

local builders: { [string]: (Model, CFrame) -> () } = {}

-- Roof: lights run along the front eave, 12 wide.
local function bulbs(m: Model, at: CFrame, colors: { Color3 }, drip: boolean)
	for index = 0, 9 do
		local x = -5.4 + index * 1.2
		local color = colors[index % #colors + 1]
		local size = if drip then Vector3.new(0.25, 0.9, 0.25) else Vector3.new(0.4, 0.5, 0.4)
		Kit.glow(m, at * CFrame.new(x, -4.4 - (if drip then 0.3 else 0), -6.2), size, color, not drip)
	end
end

builders.StringLights = function(m, at)
	bulbs(m, at, { Palette.Warm, Palette.RoofRed, Palette.Gold, Color3.fromRGB(110, 200, 120) }, false)
end

builders.IcicleLights = function(m, at)
	bulbs(m, at, { Palette.IceGlow, Palette.Frost }, true)
end

builders.AuroraLights = function(m, at)
	bulbs(m, at, Palette.Aurora, false)
end

builders.RoofStar = function(m, at)
	local star = Kit.glow(
		m,
		at * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 4),
		Vector3.new(1.6, 1.6, 0.4),
		Palette.Gold
	)
	Kit.glow(m, star.CFrame * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(1.6, 1.6, 0.4), Palette.Gold)
	Kit.light(star, Palette.Gold, 14, 0.8)
end

-- Door: a wreath hung on the door.
local function wreath(m: Model, at: CFrame, ring: Color3, dots: Color3?)
	local base = at * CFrame.new(0, 0.6, 0)
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		Kit.ball(
			m,
			base * CFrame.new(math.cos(angle) * 0.75, math.sin(angle) * 0.75, 0),
			Vector3.new(0.6, 0.6, 0.4),
			ring,
			Enum.Material.Grass
		)
		if dots and index % 2 == 0 then
			Kit.glow(
				m,
				base * CFrame.new(math.cos(angle) * 0.75, math.sin(angle) * 0.75, -0.25),
				Vector3.new(0.25, 0.25, 0.25),
				dots,
				true
			)
		end
	end
	Kit.block(m, base * CFrame.new(0, -0.85, -0.1), Vector3.new(0.6, 0.35, 0.2), Palette.Cloth)
end

builders.PineWreath = function(m, at)
	wreath(m, at, Palette.PineLight, Palette.Cloth)
end

builders.BerryWreath = function(m, at)
	wreath(m, at, Palette.Pine, Palette.Berry)
end

builders.GoldWreath = function(m, at)
	wreath(m, at, Palette.Gold, Palette.Warm)
end

-- Porch: a light on a short post.
local function porchLight(m: Model, at: CFrame, color: Color3, bowl: boolean)
	Kit.post(m, at * CFrame.new(0, 1.6, 0), 3.2, 0.4, Palette.MetalDark)
	local lamp = if bowl
		then Kit.glow(m, at * CFrame.new(0, 3.6, 0), Vector3.new(1.6, 0.8, 1.6), color, true)
		else Kit.glow(m, at * CFrame.new(0, 3.7, 0), Vector3.new(0.9, 1.1, 0.9), color)
	Kit.light(lamp, color, 14, 0.9, bowl)
end

builders.OilLamp = function(m, at)
	porchLight(m, at, Palette.Warm, false)
end

builders.SnowflakeLantern = function(m, at)
	porchLight(m, at, Palette.IceGlow, false)
end

builders.EmberBrazier = function(m, at)
	porchLight(m, at, Palette.Ember, true)
end

-- Yard.
builders.Snowman = function(m, at)
	Kit.ball(m, at * CFrame.new(0, 1.4, 0), Vector3.new(3, 2.8, 3), Palette.Snow, SNOW)
	Kit.ball(m, at * CFrame.new(0, 3.5, 0), Vector3.new(2.2, 2, 2.2), Palette.Snow, SNOW)
	Kit.ball(m, at * CFrame.new(0, 5, 0), Vector3.new(1.6, 1.5, 1.6), Palette.Snow, SNOW)
	Kit.wedge(
		m,
		at * CFrame.new(0, 5, -1) * CFrame.Angles(-math.pi / 2, 0, 0),
		Vector3.new(0.3, 0.9, 0.3),
		Color3.fromRGB(255, 140, 50)
	)
	for side = -1, 1, 2 do
		Kit.ball(m, at * CFrame.new(side * 0.3, 5.3, -0.7), Vector3.new(0.2, 0.2, 0.2), Palette.Coal)
		Kit.span(
			m,
			at * Vector3.new(side * 0.9, 3.6, 0),
			at * Vector3.new(side * 2.2, 4.4, 0),
			0.15,
			0.15,
			Palette.Bark
		)
	end
	Kit.post(m, at * CFrame.new(0, 4.3, 0), 0.3, 1.9, Palette.Cloth)
end

builders.Sled = function(m, at)
	Kit.block(m, at * CFrame.new(0, 0.9, 0), Vector3.new(2.2, 0.25, 4), Palette.Plank)
	for side = -1, 1, 2 do
		Kit.block(m, at * CFrame.new(side * 0.9, 0.35, 0), Vector3.new(0.15, 0.2, 4.4), Palette.RoofRed)
		Kit.block(
			m,
			at * CFrame.new(side * 0.9, 0.6, -2.1) * CFrame.Angles(0.8, 0, 0),
			Vector3.new(0.15, 0.8, 0.2),
			Palette.RoofRed
		)
	end
end

builders.IceSculpture = function(m, at)
	local ice = Palette.Frost
	Kit.block(m, at * CFrame.new(0, 0.6, 0), Vector3.new(2.4, 1.2, 2.4), ice, Enum.Material.Glass).Transparency = 0.3
	Kit.ball(m, at * CFrame.new(0, 2, 0.3), Vector3.new(1.8, 1.4, 2.6), ice, Enum.Material.Glass).Transparency = 0.3
	Kit.span(m, at * Vector3.new(0, 2.2, -0.6), at * Vector3.new(0, 4, -0.9), 0.4, 0.4, ice, Enum.Material.Glass).Transparency =
		0.3
	Kit.ball(m, at * CFrame.new(0, 4.1, -1.1), Vector3.new(0.6, 0.6, 0.9), ice, Enum.Material.Glass).Transparency = 0.3
end

builders.PenguinStatue = function(m, at)
	Kit.block(m, at * CFrame.new(0, 0.5, 0), Vector3.new(2, 1, 2), Palette.Stone, Enum.Material.Slate)
	Kit.ball(m, at * CFrame.new(0, 2.2, 0), Vector3.new(1.4, 2.2, 1.3), Palette.StoneDark, Enum.Material.Slate)
	Kit.ball(m, at * CFrame.new(0, 3.6, 0), Vector3.new(1, 0.9, 1), Palette.StoneDark, Enum.Material.Slate)
	Kit.post(m, at * CFrame.new(0, 3.1, 0), 0.3, 1.2, Palette.Stone, Enum.Material.Slate)
end

builders.YetiTrophy = function(m, at)
	local ice = Palette.Ice
	Kit.block(m, at * CFrame.new(0, 0.3, 0), Vector3.new(3.4, 0.6, 4.4), ice, Enum.Material.Ice).Transparency = 0.2
	for index = -2, 2 do
		Kit.ball(
			m,
			at * CFrame.new(index * 0.6, 0.65, -1.7 + math.abs(index) * 0.2),
			Vector3.new(0.5, 0.2, 0.7),
			Palette.StoneDark
		)
	end
	Kit.ball(m, at * CFrame.new(0, 0.65, 0.4), Vector3.new(2.4, 0.2, 2.6), Palette.StoneDark)
end

builders.SnowGlobe = function(m, at)
	Kit.post(m, at * CFrame.new(0, 0.5, 0), 1, 3, Palette.Gold)
	local glass =
		Kit.ball(m, at * CFrame.new(0, 2.7, 0), Vector3.new(3.6, 3.6, 3.6), Palette.Frost, Enum.Material.Glass)
	glass.Transparency = 0.6
	Kit.block(m, at * CFrame.new(0, 1.6, 0), Vector3.new(1.2, 0.9, 1), Palette.Log)
	Kit.wedge(m, at * CFrame.new(0, 2.3, 0), Vector3.new(1.3, 0.5, 1.1), Palette.Snow)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(1.5)
	sparkle.Speed = NumberRange.new(0.3)
	sparkle.Size = NumberSequence.new(0.15)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = glass
end

-- Flag: a pole with a flag in the decoration's colours.
local function flag(m: Model, at: CFrame, colors: { Color3 })
	Kit.post(m, at * CFrame.new(0, 4.5, 0), 9, 0.3, Palette.Metal)
	Kit.ball(m, at * CFrame.new(0, 9.1, 0), Vector3.new(0.5, 0.5, 0.5), Palette.Gold)
	local stripe = 2.2 / #colors
	for index, color in colors do
		Kit.block(
			m,
			at * CFrame.new(0, 8.4 - (index - 1) * stripe - stripe / 2 + 1.1 - 0.9, 1.7),
			Vector3.new(0.1, stripe, 3.2),
			color,
			Enum.Material.Fabric
		)
	end
end

builders.BlueFlag = function(m, at)
	flag(m, at, { Color3.fromRGB(61, 123, 255) })
end

builders.RedFlag = function(m, at)
	flag(m, at, { Color3.fromRGB(229, 72, 77) })
end

builders.AuroraFlag = function(m, at)
	flag(m, at, { Palette.Aurora[1], Palette.Aurora[2], Palette.Aurora[3] })
end

builders.RescueFlag = function(m, at)
	flag(m, at, { Palette.Gold, Palette.White, Palette.Gold })
end

-- The cabin's spot attachments are on its Body part.
local function spotCFrame(cabin: Model, spot: string): CFrame?
	local body = cabin:FindFirstChild("Body") :: BasePart?
	local attachment = body and body:FindFirstChild(spot) :: Attachment?
	if not body or not attachment then
		return nil
	end
	return body.CFrame * attachment.CFrame
end

-- Puts a set of decorations (spot -> decor id) on a cabin, replacing any
-- already there. Unknown ids leave their spot plain.
function CabinDecor.apply(cabin: Model, chosen: { [string]: string })
	local old = cabin:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local folder = Kit.model(cabin, "Decor")
	for _, spot in Decor.Spots do
		local id = chosen[spot] or Decor.Default[spot]
		local item = Decor.ById[id]
		if spot == "Window" then
			local color = if item then Kit.color(item.Color) else Palette.Warm
			for _, child in cabin:GetChildren() do
				if child:IsA("BasePart") and child.Name == "Window" then
					child.Color = color
					child:SetAttribute("Rainbow", id == "RainbowGlow")
				end
			end
		else
			local at = spotCFrame(cabin, spot)
			local builder = builders[id]
			if at and builder then
				local m = Kit.model(folder, id)
				builder(m, at)
			end
		end
	end
end

-- Whether every decoration in Config/Decor can be built (or is a window
-- glow or a plain default), for the tests.
function CabinDecor.has(id: string): boolean
	local item = Decor.ById[id]
	return builders[id] ~= nil or (item ~= nil and (item.Spot == "Window" or item.Source == "Starter"))
end

return CabinDecor
