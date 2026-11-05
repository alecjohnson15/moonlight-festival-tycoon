-- Builds every cosmetic from parts, using the Look in Config/Items:
--
--   blades and blasters: a model held in the right hand, and the Tool that
--     carries it in a round (its Handle is the grip, so the hand closes
--     round it; a blade points up out of the fist, a blaster points ahead);
--   masks: a model over the eyes, and the Accessory that puts it on the
--     head's FaceFrontAttachment;
--   trails: a Trail behind the character's root part;
--   knockout effects: the little pieces each client flings out of a puff
--     (client/Effects moves them).
--
-- Models are built facing -Z with the grip or the face at the origin, so a
-- preview can show them all the same way. Nothing here runs at runtime on
-- its own, so the tests load it to check every item builds.

local Items = require(script.Parent.Parent.Config.Items)
local Kit = require(script.Parent.Kit)

local Gear = {}

local hex = Kit.color
local PI = math.pi

local function lookOf(itemId: string, kind: string): { [string]: any }
	local item = Items.get(itemId)
	if not item or item.Kind ~= kind then
		item = Items.get(Items.DEFAULTS[kind])
	end
	return (item :: any).Look
end

local function material(look: { [string]: any }): Enum.Material
	if look.Glass then
		return Enum.Material.Glass
	elseif look.Metal then
		return Enum.Material.Metal
	elseif look.Paper then
		return Enum.Material.Fabric
	end
	return Enum.Material.SmoothPlastic
end

local function particles(parent: Instance, texture: string, color: Color3, rate: number, props: { [string]: any }?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.25, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	for key, value in props or {} do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- The extras a look can ask for on its main part: a glow, sparkles, fire or
-- drips.
local function extras(part: BasePart, look: { [string]: any })
	if look.Glow then
		Kit.light(part, hex(look.Glow), 8, 1.4)
	end
	if look.Sparkle then
		particles(part, SPARKLES, hex(look.Sparkle), 6)
	end
	if look.Fire then
		particles(part, FIRE, hex(look.Fire), 18, {
			Speed = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, 3, 0),
			Size = NumberSequence.new(0.45, 0.05),
		})
	end
	if look.Drip then
		particles(part, SPARKLES, hex(look.Drip), 5, {
			Acceleration = Vector3.new(0, -12, 0),
			Speed = NumberRange.new(0, 0.3),
			LightEmission = 0.4,
		})
	end
end

-- Blades -------------------------------------------------------------------

-- The grip, guard and pommel every blade shares except those that make
-- their own. The grip is a short bar round the origin.
local function hilt(model: Model, look: { [string]: any }, guardWidth: number)
	Kit.block(model, CFrame.new(0, 0, 0), Vector3.new(0.32, 1.1, 0.32), hex(look.Hilt), Enum.Material.Fabric).Name =
		"Grip"
	Kit.ball(model, CFrame.new(0, -0.62, 0), Vector3.new(0.42, 0.42, 0.42), hex(look.Guard), Enum.Material.Metal)
	if guardWidth > 0 then
		Kit.block(model, CFrame.new(0, 0.62, 0), Vector3.new(0.3, 0.18, guardWidth), hex(look.Guard), Enum.Material.Metal)
		Kit.ball(model, CFrame.new(0, 0.62, guardWidth / 2), Vector3.new(0.24, 0.24, 0.24), hex(look.Guard))
		Kit.ball(model, CFrame.new(0, 0.62, -guardWidth / 2), Vector3.new(0.24, 0.24, 0.24), hex(look.Guard))
	end
end

local bladeShapes = {}

function bladeShapes.straight(model: Model, look: { [string]: any }): BasePart
	local width = if look.Thin then 0.22 else 0.5
	local length = if look.Thin then 3.6 else 3.1
	hilt(model, look, if look.Thin then 1.1 else 1.3)
	local blade = Kit.block(
		model,
		CFrame.new(0, 0.71 + length / 2, 0),
		Vector3.new(0.1, length, width),
		hex(look.Blade),
		if look.Glow then Enum.Material.Neon else Enum.Material.Metal
	)
	blade.Name = "Blade"
	-- The point: a wedge whose slope runs from the blade's back to its tip.
	Kit.wedge(
		model,
		CFrame.new(0, 0.71 + length + width * 0.45, 0) * CFrame.Angles(PI / 2, 0, 0),
		Vector3.new(0.1, width, width * 0.9),
		hex(look.Blade),
		blade.Material
	)
	-- A bright edge down the front.
	Kit.block(
		model,
		CFrame.new(0, 0.71 + length / 2, -width / 2 - 0.02),
		Vector3.new(0.06, length, 0.06),
		hex(look.Edge),
		Enum.Material.Neon
	)
	-- A fuller groove down the middle.
	Kit.block(
		model,
		CFrame.new(0, 0.71 + length * 0.45, 0),
		Vector3.new(0.12, length * 0.7, width * 0.16),
		hex(look.Guard),
		Enum.Material.Metal
	)
	return blade
end

function bladeShapes.curved(model: Model, look: { [string]: any }): BasePart
	local small = look.Small == true
	hilt(model, look, if small then 0.6 else 1.1)
	local segments = if small then 5 else 7
	local radius = if small then 1.6 else 2.4
	local first: BasePart? = nil
	-- A crescent: segments round an arc that bows forward.
	for i = 1, segments do
		local t = (i - 0.5) / segments
		local angle = t * PI * 0.62
		local x = 0
		local y = 0.7 + math.sin(angle) * radius
		local z = -(1 - math.cos(angle)) * radius * 0.9
		local thickness = 0.5 * (1 - t * 0.6)
		local segment = Kit.block(
			model,
			CFrame.new(x, y, z) * CFrame.Angles(angle * 0.9, 0, 0),
			Vector3.new(0.1, radius * PI * 0.62 / segments + 0.08, thickness),
			hex(look.Blade),
			if look.Glow then Enum.Material.Neon else Enum.Material.Metal
		)
		Kit.block(
			model,
			CFrame.new(x, y, z) * CFrame.Angles(angle * 0.9, 0, 0) * CFrame.new(0, 0, -thickness / 2 - 0.02),
			Vector3.new(0.06, radius * PI * 0.62 / segments + 0.08, 0.05),
			hex(look.Edge),
			Enum.Material.Neon
		)
		if not first then
			first = segment
			segment.Name = "Blade"
		end
	end
	return first :: BasePart
end

function bladeShapes.crystal(model: Model, look: { [string]: any }): BasePart
	hilt(model, look, 1.2)
	local mat = if look.Glass then Enum.Material.Glass else Enum.Material.Neon
	local blade = Kit.block(model, CFrame.new(0, 2.1, 0), Vector3.new(0.3, 2.8, 0.5), hex(look.Blade), mat)
	blade.Name = "Blade"
	if look.Glass then
		blade.Transparency = 0.25
	end
	-- Shards jutting from the sides, and a long point.
	for i, spec in { { 1.2, 1 }, { 1.9, -1 }, { 2.6, 1 }, { 3.1, -1 } } do
		local y, side = spec[1], spec[2]
		local shard = Kit.wedge(
			model,
			CFrame.new(0, y, side * 0.35) * CFrame.Angles(side * 0.6, 0, 0),
			Vector3.new(0.24, 0.6 - i * 0.05, 0.35),
			hex(look.Edge),
			mat
		)
		shard.Transparency = if look.Glass then 0.2 else 0
	end
	Kit.wedge(
		model,
		CFrame.new(0, 3.85, 0) * CFrame.Angles(PI / 2, 0, 0),
		Vector3.new(0.3, 0.5, 0.7),
		hex(look.Edge),
		mat
	)
	return blade
end

function bladeShapes.quill(model: Model, look: { [string]: any }): BasePart
	-- No guard: a gold band, the feather's shaft and its vanes.
	Kit.block(model, CFrame.new(0, 0, 0), Vector3.new(0.26, 1.1, 0.26), hex(look.Hilt), Enum.Material.SmoothPlastic).Name =
		"Grip"
	Kit.wedge(
		model,
		CFrame.new(0, -0.75, 0) * CFrame.Angles(PI / 2, 0, PI),
		Vector3.new(0.18, 0.26, 0.45),
		hex(look.Guard),
		Enum.Material.Metal
	)
	Kit.block(model, CFrame.new(0, 0.6, 0), Vector3.new(0.3, 0.14, 0.3), hex(look.Guard), Enum.Material.Metal)
	local shaft = Kit.block(model, CFrame.new(0, 2.3, 0), Vector3.new(0.08, 3.3, 0.08), hex(look.Blade))
	shaft.Name = "Blade"
	for i = 0, 9 do
		local y = 1.0 + i * 0.32
		local spread = 0.55 * math.sin((i + 1) / 11 * PI)
		local color = if i >= 8 then hex(look.Edge) else hex(look.Blade)
		Kit.block(
			model,
			CFrame.new(0, y, -spread / 2) * CFrame.Angles(-0.35, 0, 0),
			Vector3.new(0.05, 0.36, spread),
			color,
			Enum.Material.Fabric
		)
		Kit.block(
			model,
			CFrame.new(0, y, spread / 2) * CFrame.Angles(0.35, 0, 0),
			Vector3.new(0.05, 0.36, spread),
			color,
			Enum.Material.Fabric
		)
	end
	return shaft
end

function bladeShapes.cane(model: Model, look: { [string]: any }): BasePart
	-- A candy cane: a striped staff with its hook at the top.
	local stripe = { hex(look.Blade), hex(look.Edge) }
	local first: BasePart? = nil
	for i = 0, 9 do
		local part = Kit.post(model, CFrame.new(0, -0.5 + i * 0.4, 0), 0.4, 0.34, stripe[i % 2 + 1])
		if not first then
			first = part
		end
	end
	for i = 1, 6 do
		local angle = i / 6 * PI
		local y = 3.5 + math.sin(angle) * 0.55
		local z = -0.55 + math.cos(angle) * 0.55
		Kit.ball(model, CFrame.new(0, y, z), Vector3.new(0.36, 0.36, 0.36), stripe[i % 2 + 1])
	end
	local blade = first :: BasePart
	blade.Name = "Blade"
	return blade
end

function bladeShapes.bone(model: Model, look: { [string]: any }): BasePart
	local bone = Kit.post(model, CFrame.new(0, 1.4, 0), 3.4, 0.38, hex(look.Blade))
	bone.Name = "Blade"
	for _, y in { -0.35, 3.15 } do
		Kit.ball(model, CFrame.new(0, y, -0.18), Vector3.new(0.55, 0.55, 0.55), hex(look.Guard))
		Kit.ball(model, CFrame.new(0, y, 0.18), Vector3.new(0.55, 0.55, 0.55), hex(look.Guard))
	end
	return bone
end

function bladeShapes.umbrella(model: Model, look: { [string]: any }): BasePart
	-- A furled umbrella, its hooked handle in the hand.
	Kit.post(model, CFrame.new(0, 0, 0), 1.2, 0.26, hex(look.Hilt)).Name = "Grip"
	for i = 1, 4 do
		local angle = i / 4 * PI
		Kit.ball(
			model,
			CFrame.new(0, -0.6 - math.sin(angle) * 0.35, -0.35 + math.cos(angle) * 0.35),
			Vector3.new(0.24, 0.24, 0.24),
			hex(look.Hilt)
		)
	end
	local canopy = Kit.post(model, CFrame.new(0, 1.9, 0), 2.6, 0.5, hex(look.Blade), Enum.Material.Fabric)
	canopy.Name = "Blade"
	Kit.post(model, CFrame.new(0, 3.35, 0), 0.4, 0.32, hex(look.Blade), Enum.Material.Fabric)
	Kit.post(model, CFrame.new(0, 3.8, 0), 0.6, 0.12, hex(look.Guard), Enum.Material.Metal)
	Kit.post(model, CFrame.new(0, 1.9, 0), 0.18, 0.56, hex(look.Edge))
	return canopy
end

function bladeShapes.rose(model: Model, look: { [string]: any }): BasePart
	local stem = Kit.post(model, CFrame.new(0, 1.5, 0), 3.6, 0.16, hex(look.Blade))
	stem.Name = "Blade"
	for i = 1, 6 do
		local side = if i % 2 == 0 then 1 else -1
		Kit.wedge(
			model,
			CFrame.new(0, 0.2 + i * 0.5, side * 0.12) * CFrame.Angles(side * 0.9, 0, 0),
			Vector3.new(0.06, 0.16, 0.18),
			hex(look.Hilt)
		)
	end
	-- Two leaves and the bloom.
	Kit.ball(
		model,
		CFrame.new(0, 1.2, -0.3) * CFrame.Angles(0.6, 0, 0),
		Vector3.new(0.1, 0.7, 0.35),
		hex(look.Blade)
	)
	Kit.ball(
		model,
		CFrame.new(0, 2.1, 0.3) * CFrame.Angles(-0.6, 0, 0),
		Vector3.new(0.1, 0.7, 0.35),
		hex(look.Blade)
	)
	for i = 0, 5 do
		local angle = i / 6 * PI * 2
		Kit.ball(
			model,
			CFrame.new(math.cos(angle) * 0.22, 3.5, math.sin(angle) * 0.22),
			Vector3.new(0.42, 0.55, 0.42),
			hex(look.Edge),
			Enum.Material.Fabric
		)
	end
	Kit.ball(model, CFrame.new(0, 3.62, 0), Vector3.new(0.4, 0.5, 0.4), hex(look.Guard), Enum.Material.Fabric)
	return stem
end

-- A blade as a still model, grip at the origin, pointing up.
function Gear.bladeModel(itemId: string): Model
	local look = lookOf(itemId, "Blade")
	local model = Kit.model(nil, "Blade")
	local build = bladeShapes[look.Shape] or bladeShapes.straight
	local main = build(model, look)
	extras(main, look)
	model.WorldPivot = CFrame.new()
	return model
end

-- Blasters -----------------------------------------------------------------

-- The grip every blaster shares, under the body.
local function blasterGrip(model: Model, look: { [string]: any })
	Kit.block(
		model,
		CFrame.new(0, 0, 0.15) * CFrame.Angles(-0.25, 0, 0),
		Vector3.new(0.34, 1.05, 0.42),
		hex(look.Trim),
		Enum.Material.SmoothPlastic
	).Name =
		"Grip"
	-- The trigger and its guard.
	Kit.block(model, CFrame.new(0, 0.35, -0.3), Vector3.new(0.1, 0.3, 0.1), hex(look.Trim))
	Kit.block(model, CFrame.new(0, 0.2, -0.35), Vector3.new(0.1, 0.06, 0.4), hex(look.Body))
end

local function muzzle(model: Model, at: CFrame, look: { [string]: any }): BasePart
	local tip = Kit.glow(model, at, Vector3.new(0.3, 0.3, 0.3), hex(look.Beam), true)
	tip.Name = "Tip"
	local attachment = Instance.new("Attachment")
	attachment.Name = "Muzzle"
	attachment.CFrame = CFrame.new(0, 0, -0.15)
	attachment.Parent = tip
	return tip
end

local blasterShapes = {}

function blasterShapes.ray(model: Model, look: { [string]: any }): BasePart
	blasterGrip(model, look)
	local mat = material(look)
	local body = Kit.log(
		model,
		CFrame.new(0, 0.62, -0.45) * CFrame.Angles(0, PI / 2, 0),
		1.6,
		0.6,
		hex(look.Body),
		mat
	)
	body.Name = "Body"
	if look.Paper then
		-- Folded paper: flat faces at angles instead of round ones.
		body.Shape = Enum.PartType.Block
		body.Size = Vector3.new(1.6, 0.55, 0.55)
	end
	Kit.log(model, CFrame.new(0, 0.62, -1.55) * CFrame.Angles(0, PI / 2, 0), 0.8, 0.28, hex(look.Body), mat)
	for i = 0, 2 do
		Kit.log(
			model,
			CFrame.new(0, 0.62, -0.95 - i * 0.28) * CFrame.Angles(0, PI / 2, 0),
			0.1,
			0.62 - i * 0.12,
			hex(look.Trim),
			Enum.Material.Metal
		)
	end
	Kit.ball(model, CFrame.new(0, 0.62, 0.38), Vector3.new(0.55, 0.55, 0.55), hex(look.Trim), mat)
	Kit.block(model, CFrame.new(0, 0.98, -0.3), Vector3.new(0.1, 0.25, 0.7), hex(look.Trim))
	muzzle(model, CFrame.new(0, 0.62, -2.0), look)
	return body
end

function blasterShapes.bulb(model: Model, look: { [string]: any }): BasePart
	blasterGrip(model, look)
	local body = Kit.block(model, CFrame.new(0, 0.55, -0.55), Vector3.new(0.45, 0.4, 1.4), hex(look.Trim))
	body.Name = "Body"
	local tank = Kit.ball(model, CFrame.new(0, 1.05, -0.35), Vector3.new(0.75, 0.75, 0.75), hex(look.Body), material(look))
	if look.Glass then
		tank.Transparency = 0.35
		Kit.glow(model, CFrame.new(0, 1.05, -0.35), Vector3.new(0.35, 0.35, 0.35), hex(look.Beam), true)
	end
	Kit.log(model, CFrame.new(0, 0.55, -1.5) * CFrame.Angles(0, PI / 2, 0), 0.7, 0.24, hex(look.Body))
	muzzle(model, CFrame.new(0, 0.55, -1.9), look)
	return body
end

function blasterShapes.flare(model: Model, look: { [string]: any }): BasePart
	blasterGrip(model, look)
	local body = Kit.log(
		model,
		CFrame.new(0, 0.6, -0.5) * CFrame.Angles(0, PI / 2, 0),
		1.3,
		0.45,
		hex(look.Body),
		material(look)
	)
	body.Name = "Body"
	-- A bell mouth widening ring by ring.
	for i = 0, 3 do
		Kit.log(
			model,
			CFrame.new(0, 0.6, -1.25 - i * 0.18) * CFrame.Angles(0, PI / 2, 0),
			0.2,
			0.45 + i * 0.16,
			if i % 2 == 0 then hex(look.Body) else hex(look.Trim),
			material(look)
		)
	end
	Kit.block(model, CFrame.new(0, 0.95, -0.4), Vector3.new(0.12, 0.2, 0.9), hex(look.Trim), Enum.Material.Metal)
	muzzle(model, CFrame.new(0, 0.6, -1.95), look)
	return body
end

function blasterShapes.lantern(model: Model, look: { [string]: any }): BasePart
	blasterGrip(model, look)
	local body = Kit.log(
		model,
		CFrame.new(0, 0.6, -0.4) * CFrame.Angles(0, PI / 2, 0),
		1.1,
		0.4,
		hex(look.Body),
		Enum.Material.Metal
	)
	body.Name = "Body"
	-- A little lantern at the front: a cage of posts round a glowing core.
	local centre = CFrame.new(0, 0.7, -1.3)
	Kit.block(model, centre * CFrame.new(0, -0.38, 0), Vector3.new(0.6, 0.1, 0.6), hex(look.Body), Enum.Material.Metal)
	Kit.block(model, centre * CFrame.new(0, 0.38, 0), Vector3.new(0.6, 0.1, 0.6), hex(look.Body), Enum.Material.Metal)
	Kit.wedge(model, centre * CFrame.new(0, 0.55, 0), Vector3.new(0.5, 0.25, 0.5), hex(look.Body), Enum.Material.Metal)
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		Kit.block(
			model,
			centre * CFrame.new(corner[1] * 0.25, 0, corner[2] * 0.25),
			Vector3.new(0.08, 0.7, 0.08),
			hex(look.Trim),
			Enum.Material.Metal
		)
	end
	local core = Kit.glow(model, centre, Vector3.new(0.34, 0.5, 0.34), hex(look.Beam))
	if look.Glass then
		local pane = Kit.block(model, centre, Vector3.new(0.48, 0.66, 0.48), hex(look.Trim), Enum.Material.Glass)
		pane.Transparency = 0.6
	end
	Kit.light(core, hex(look.Beam), 6, 1.2)
	muzzle(model, CFrame.new(0, 0.7, -1.75), look)
	return body
end

function blasterShapes.popper(model: Model, look: { [string]: any }): BasePart
	blasterGrip(model, look)
	local body = Kit.block(model, CFrame.new(0, 0.85, -0.5), Vector3.new(0.7, 0.8, 1.1), hex(look.Body))
	body.Name = "Body"
	for i = -1, 1 do
		Kit.block(model, CFrame.new(i * 0.24, 0.85, -0.5), Vector3.new(0.08, 0.82, 1.12), hex(look.Trim))
	end
	-- Popcorn heaped on top.
	for i = 0, 6 do
		Kit.ball(
			model,
			CFrame.new(((i % 3) - 1) * 0.2, 1.3 + (i // 3) * 0.08, -0.3 - (i % 2) * 0.35),
			Vector3.new(0.24, 0.22, 0.24),
			hex("#FFF4C2")
		)
	end
	Kit.log(model, CFrame.new(0, 0.7, -1.3) * CFrame.Angles(0, PI / 2, 0), 0.6, 0.26, hex(look.Trim))
	muzzle(model, CFrame.new(0, 0.7, -1.65), look)
	return body
end

-- A blaster as a still model, grip at the origin, pointing ahead (-Z).
function Gear.blasterModel(itemId: string): Model
	local look = lookOf(itemId, "Blaster")
	local model = Kit.model(nil, "Blaster")
	local build = blasterShapes[look.Shape] or blasterShapes.ray
	local main = build(model, look)
	extras(main, look)
	model.WorldPivot = CFrame.new()
	return model
end

-- Masks --------------------------------------------------------------------

-- Masks are built round the face's front, the origin, with the eyes at
-- EYE_Y and the mask standing just proud of the face.
local EYE_Y = 0.12
local Z = -0.06

-- A band across the eyes with two holes to see through.
local function eyeBand(model: Model, color: Color3, mat: Enum.Material?, width: number?, height: number?)
	local w = width or 1.3
	local h = height or 0.42
	local holeW, holeH = 0.3, 0.2
	local y = EYE_Y
	-- Top and bottom strips, the bridge and the outer sides.
	Kit.block(model, CFrame.new(0, y + h / 2 - (h - holeH) / 4, Z), Vector3.new(w, (h - holeH) / 2, 0.08), color, mat)
	Kit.block(model, CFrame.new(0, y - h / 2 + (h - holeH) / 4, Z), Vector3.new(w, (h - holeH) / 2, 0.08), color, mat)
	Kit.block(model, CFrame.new(0, y, Z), Vector3.new(0.6 - holeW * 2 + 0.2, holeH, 0.08), color, mat)
	local sideW = (w - 0.8 - holeW) / 2 + holeW / 2
	for _, side in { -1, 1 } do
		Kit.block(
			model,
			CFrame.new(side * (w / 2 - sideW / 2), y, Z),
			Vector3.new(sideW - holeW / 2 + 0.05, holeH, 0.08),
			color,
			mat
		)
	end
end

local function trimLine(model: Model, color: Color3, width: number, y: number)
	Kit.block(model, CFrame.new(0, y, Z - 0.03), Vector3.new(width, 0.05, 0.04), color, Enum.Material.Metal)
end

-- A plate covering the face from top to bottom, with eye holes.
local function facePlate(model: Model, color: Color3, mat: Enum.Material?, top: number, bottom: number)
	eyeBand(model, color, mat, 1.25, 0.42)
	local bandTop = EYE_Y + 0.21
	local bandBottom = EYE_Y - 0.21
	if top > bandTop then
		Kit.block(model, CFrame.new(0, (top + bandTop) / 2, Z), Vector3.new(1.25, top - bandTop, 0.08), color, mat)
	end
	if bottom < bandBottom then
		Kit.block(
			model,
			CFrame.new(0, (bottom + bandBottom) / 2, Z),
			Vector3.new(1.2, bandBottom - bottom, 0.08),
			color,
			mat
		)
	end
end

local maskShapes = {}

function maskShapes.domino(model: Model, look: { [string]: any })
	eyeBand(model, hex(look.Base), Enum.Material.Fabric)
	trimLine(model, hex(look.Trim), 1.3, EYE_Y + 0.2)
	for _, side in { -1, 1 } do
		Kit.wedge(
			model,
			CFrame.new(side * 0.72, EYE_Y + 0.22, Z) * CFrame.Angles(0, PI / 2 * side, 0),
			Vector3.new(0.08, 0.3, 0.22),
			hex(look.Base),
			Enum.Material.Fabric
		)
	end
end

function maskShapes.half(model: Model, look: { [string]: any })
	-- The right half of the face, eye hole and all.
	local base = hex(look.Base)
	Kit.block(model, CFrame.new(0.42, EYE_Y + 0.32, Z), Vector3.new(0.46, 0.24, 0.08), base)
	Kit.block(model, CFrame.new(0.42, EYE_Y - 0.36, Z), Vector3.new(0.46, 0.52, 0.08), base)
	Kit.block(model, CFrame.new(0.1, EYE_Y, Z), Vector3.new(0.12, 0.4, 0.08), base)
	Kit.block(model, CFrame.new(0.6, EYE_Y, Z), Vector3.new(0.1, 0.4, 0.08), base)
	Kit.block(model, CFrame.new(0.07, EYE_Y - 0.3, Z), Vector3.new(0.06, 1.1, 0.1), hex(look.Trim), Enum.Material.Metal)
end

function maskShapes.feather(model: Model, look: { [string]: any })
	maskShapes.domino(model, look)
	for i = 0, 4 do
		local angle = -0.5 + i * 0.25
		local feather = Kit.ball(
			model,
			CFrame.new(0.55, EYE_Y + 0.25, Z + 0.02) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.45, 0),
			Vector3.new(0.16, 0.85, 0.04),
			if i % 2 == 0 then hex(look.Feather) else hex(look.Base),
			Enum.Material.Fabric
		)
		if look.Glow and i == 2 then
			Kit.glow(model, feather.CFrame * CFrame.new(0, 0.28, -0.02), Vector3.new(0.12, 0.12, 0.04), hex(look.Glow), true)
		end
	end
	Kit.ball(model, CFrame.new(0.55, EYE_Y + 0.25, Z - 0.03), Vector3.new(0.2, 0.2, 0.1), hex(look.Trim), Enum.Material.Metal)
end

function maskShapes.cat(model: Model, look: { [string]: any })
	eyeBand(model, hex(look.Base), Enum.Material.Fabric, 1.25, 0.46)
	for _, side in { -1, 1 } do
		Kit.wedge(
			model,
			CFrame.new(side * 0.42, EYE_Y + 0.4, Z) * CFrame.Angles(0, PI, side * -0.35),
			Vector3.new(0.3, 0.38, 0.08),
			hex(look.Base),
			Enum.Material.Fabric
		)
		-- A glowing rim round each eye.
		Kit.glow(model, CFrame.new(side * 0.3, EYE_Y - 0.12, Z - 0.04), Vector3.new(0.3, 0.04, 0.03), hex(look.Glow))
		for w = -1, 1 do
			Kit.block(
				model,
				CFrame.new(side * 0.68, EYE_Y - 0.1 + w * 0.06, Z - 0.02) * CFrame.Angles(0, 0, w * 0.2),
				Vector3.new(0.3, 0.025, 0.02),
				hex(look.Trim)
			)
		end
	end
end

function maskShapes.fox(model: Model, look: { [string]: any })
	facePlate(model, hex(look.Base), Enum.Material.SmoothPlastic, EYE_Y + 0.45, EYE_Y - 0.3)
	-- The snout.
	Kit.wedge(
		model,
		CFrame.new(0, EYE_Y - 0.42, Z - 0.18) * CFrame.Angles(0, 0, 0),
		Vector3.new(0.5, 0.3, 0.35),
		hex(look.Base)
	)
	Kit.ball(model, CFrame.new(0, EYE_Y - 0.38, Z - 0.36), Vector3.new(0.14, 0.1, 0.1), hex("#1A1A1A"))
	for _, side in { -1, 1 } do
		Kit.wedge(
			model,
			CFrame.new(side * 0.4, EYE_Y + 0.62, Z) * CFrame.Angles(0, PI, side * -0.3),
			Vector3.new(0.34, 0.45, 0.1),
			hex(look.Base)
		)
		Kit.wedge(
			model,
			CFrame.new(side * 0.4, EYE_Y + 0.6, Z - 0.05) * CFrame.Angles(0, PI, side * -0.3),
			Vector3.new(0.18, 0.28, 0.04),
			hex(look.Trim)
		)
		-- Red markings sweeping up from the eyes.
		Kit.block(
			model,
			CFrame.new(side * 0.32, EYE_Y + 0.22, Z - 0.05) * CFrame.Angles(0, 0, side * 0.5),
			Vector3.new(0.3, 0.05, 0.03),
			hex(look.Glow),
			Enum.Material.Neon
		)
	end
	Kit.ball(model, CFrame.new(0, EYE_Y + 0.33, Z - 0.05), Vector3.new(0.1, 0.1, 0.03), hex(look.Trim))
end

function maskShapes.moon(model: Model, look: { [string]: any })
	eyeBand(model, hex(look.Base), Enum.Material.Metal)
	-- A crescent curling round the left eye.
	for i = 0, 6 do
		local angle = PI * 0.6 + i / 6 * PI * 0.9
		local size = 0.16 - math.abs(i - 3) * 0.025
		Kit.ball(
			model,
			CFrame.new(-0.3 + math.cos(angle) * 0.42, EYE_Y + math.sin(angle) * 0.42, Z - 0.02),
			Vector3.new(size, size, 0.06),
			hex(look.Glow),
			Enum.Material.Neon
		)
	end
	trimLine(model, hex(look.Trim), 1.3, EYE_Y - 0.2)
end

function maskShapes.skull(model: Model, look: { [string]: any })
	facePlate(model, hex(look.Base), Enum.Material.SmoothPlastic, EYE_Y + 0.42, EYE_Y - 0.62)
	for _, side in { -1, 1 } do
		Kit.ball(model, CFrame.new(side * 0.3, EYE_Y, Z - 0.03), Vector3.new(0.4, 0.34, 0.03), hex(look.Trim))
		Kit.glow(model, CFrame.new(side * 0.3, EYE_Y + 0.25, Z - 0.05), Vector3.new(0.1, 0.1, 0.03), hex(look.Glow), true)
	end
	Kit.wedge(model, CFrame.new(0, EYE_Y - 0.26, Z - 0.04), Vector3.new(0.14, 0.14, 0.03), hex("#2A2A2A"))
	for i = -2, 2 do
		Kit.block(model, CFrame.new(i * 0.1, EYE_Y - 0.5, Z - 0.04), Vector3.new(0.025, 0.12, 0.03), hex("#2A2A2A"))
	end
	Kit.block(model, CFrame.new(0, EYE_Y - 0.5, Z - 0.035), Vector3.new(0.5, 0.025, 0.03), hex("#2A2A2A"))
	-- A crown of candy flowers.
	for i = -2, 2 do
		local flower = if i % 2 == 0 then hex(look.Flower) else hex(look.Trim)
		Kit.ball(model, CFrame.new(i * 0.22, EYE_Y + 0.38, Z - 0.06), Vector3.new(0.18, 0.18, 0.06), flower)
		Kit.ball(model, CFrame.new(i * 0.22, EYE_Y + 0.38, Z - 0.09), Vector3.new(0.07, 0.07, 0.03), hex("#FFFFFF"))
	end
end

function maskShapes.butterfly(model: Model, look: { [string]: any })
	eyeBand(model, hex(look.Trim), Enum.Material.Fabric, 0.9, 0.36)
	for _, side in { -1, 1 } do
		for _, wing in { { 0.25, 0.75, 0.55 }, { -0.12, 0.5, 0.38 } } do
			local y, height, width = wing[1], wing[2], wing[3]
			Kit.ball(
				model,
				CFrame.new(side * (0.45 + width / 2), EYE_Y + y, Z) * CFrame.Angles(0, 0, side * -0.4),
				Vector3.new(width, height, 0.05),
				hex(look.Base),
				Enum.Material.Fabric
			)
			Kit.ball(
				model,
				CFrame.new(side * (0.45 + width / 2), EYE_Y + y, Z - 0.03) * CFrame.Angles(0, 0, side * -0.4),
				Vector3.new(width * 0.5, height * 0.5, 0.03),
				hex(look.Glow)
			)
		end
	end
end

function maskShapes.jester(model: Model, look: { [string]: any })
	maskShapes.domino(model, { Base = look.Base, Trim = look.Trim })
	-- Two tall, curling points in two colours, with a bell on each tip.
	for _, side in { -1, 1 } do
		local color = if side < 0 then hex(look.Trim) else hex(look.Second)
		for i = 0, 3 do
			local t = i / 3
			Kit.ball(
				model,
				CFrame.new(side * (0.35 + t * 0.4), EYE_Y + 0.35 + t * 0.55, Z + 0.05),
				Vector3.new(0.3 - t * 0.12, 0.34, 0.08),
				color,
				Enum.Material.Fabric
			)
		end
		Kit.ball(model, CFrame.new(side * 0.8, EYE_Y + 0.98, Z + 0.05), Vector3.new(0.16, 0.16, 0.16), hex(look.Bells), Enum.Material.Metal)
	end
	-- A painted grin under the mask.
	Kit.block(model, CFrame.new(0, EYE_Y - 0.48, Z - 0.02), Vector3.new(0.5, 0.05, 0.03), hex(look.Trim))
end

function maskShapes.ghost(model: Model, look: { [string]: any })
	-- A pale veil over the whole head, with dark eye holes.
	local veil = Kit.ball(model, CFrame.new(0, EYE_Y + 0.05, Z + 0.62), Vector3.new(1.45, 1.55, 1.45), hex(look.Base), Enum.Material.Fabric)
	veil.Transparency = 0.15
	for _, side in { -1, 1 } do
		Kit.ball(model, CFrame.new(side * 0.25, EYE_Y, Z - 0.1), Vector3.new(0.26, 0.36, 0.05), hex("#1C1C28"))
	end
	Kit.ball(model, CFrame.new(0, EYE_Y - 0.35, Z - 0.1), Vector3.new(0.18, 0.24, 0.05), hex("#1C1C28"))
	local glow = Kit.block(model, CFrame.new(0, EYE_Y + 0.7, Z + 0.62), Vector3.new(0.1, 0.1, 0.1), hex(look.Glow))
	glow.Transparency = 1
	Kit.light(glow, hex(look.Glow), 6, 0.8)
end

function maskShapes.sun(model: Model, look: { [string]: any })
	eyeBand(model, hex(look.Base), Enum.Material.Metal, 1.2, 0.44)
	for i = 0, 11 do
		local angle = i / 12 * PI * 2
		local ray = Kit.wedge(
			model,
			CFrame.new(math.cos(angle) * 0.8, EYE_Y + math.sin(angle) * 0.8, Z + 0.04)
				* CFrame.Angles(0, 0, angle - PI / 2)
				* CFrame.Angles(PI / 2, 0, 0),
			Vector3.new(0.05, 0.22, 0.38),
			if i % 2 == 0 then hex(look.Base) else hex(look.Trim),
			Enum.Material.Metal
		)
		if i % 3 == 0 then
			ray.Material = Enum.Material.Neon
			ray.Color = hex(look.Glow)
		end
	end
end

function maskShapes.visor(model: Model, look: { [string]: any })
	local band = Kit.block(model, CFrame.new(0, EYE_Y, Z - 0.02), Vector3.new(1.35, 0.34, 0.1), hex(look.Base), Enum.Material.Glass)
	band.Transparency = 0.15
	Kit.glow(model, CFrame.new(0, EYE_Y, Z - 0.08), Vector3.new(1.1, 0.06, 0.02), hex(look.Glow))
	trimLine(model, hex(look.Trim), 1.4, EYE_Y + 0.18)
	trimLine(model, hex(look.Trim), 1.4, EYE_Y - 0.18)
	for i = -2, 2 do
		Kit.glow(model, CFrame.new(i * 0.24, EYE_Y + 0.08 * ((i % 2) * 2 - 1), Z - 0.09), Vector3.new(0.05, 0.05, 0.02), hex(look.Sparkle), true)
	end
end

function maskShapes.sack(model: Model, look: { [string]: any })
	-- A burlap sack over the head, tied at the top, with a stitched smile.
	local sack = Kit.ball(model, CFrame.new(0, EYE_Y, Z + 0.6), Vector3.new(1.4, 1.45, 1.4), hex(look.Base), Enum.Material.Fabric)
	sack.Name = "Sack"
	for _, side in { -1, 1 } do
		Kit.ball(model, CFrame.new(side * 0.26, EYE_Y + 0.05, Z - 0.05), Vector3.new(0.2, 0.2, 0.05), hex(look.Trim))
	end
	for i = -3, 3 do
		Kit.block(
			model,
			CFrame.new(i * 0.09, EYE_Y - 0.33 + math.abs(i) * 0.025, Z - 0.06) * CFrame.Angles(0, 0, i * 0.12),
			Vector3.new(0.025, 0.1, 0.02),
			hex(look.Trim)
		)
	end
	Kit.block(model, CFrame.new(0, EYE_Y + 0.68, Z + 0.6), Vector3.new(0.5, 0.12, 0.5), hex(look.Trim), Enum.Material.Fabric)
	for i = 0, 5 do
		local angle = i / 6 * PI * 2
		Kit.wedge(
			model,
			CFrame.new(math.cos(angle) * 0.15, EYE_Y + 0.88, Z + 0.6 + math.sin(angle) * 0.15) * CFrame.Angles(0, angle, 0),
			Vector3.new(0.06, 0.32, 0.12),
			hex(look.Straw),
			Enum.Material.Fabric
		)
	end
end

function maskShapes.lantern(model: Model, look: { [string]: any })
	-- A carved pumpkin over the head, glowing from inside.
	local pumpkin =
		Kit.ball(model, CFrame.new(0, EYE_Y, Z + 0.6), Vector3.new(1.6, 1.4, 1.5), hex(look.Base), Enum.Material.SmoothPlastic)
	pumpkin.Name = "Pumpkin"
	for i = -1, 1, 2 do
		Kit.ball(model, CFrame.new(i * 0.45, EYE_Y, Z + 0.6), Vector3.new(0.75, 1.42, 1.3), hex(look.Base))
	end
	for _, side in { -1, 1 } do
		Kit.wedge(
			model,
			CFrame.new(side * 0.3, EYE_Y + 0.12, Z - 0.1) * CFrame.Angles(-PI / 2, 0, 0),
			Vector3.new(0.3, 0.05, 0.24),
			hex(look.Glow),
			Enum.Material.Neon
		)
	end
	for i = -2, 2 do
		Kit.block(
			model,
			CFrame.new(i * 0.13, EYE_Y - 0.3 + (if i % 2 == 0 then 0 else 0.05), Z - 0.1),
			Vector3.new(0.12, 0.12, 0.05),
			hex(look.Glow),
			Enum.Material.Neon
		)
	end
	Kit.post(model, CFrame.new(0, EYE_Y + 0.78, Z + 0.6), 0.3, 0.16, hex(look.Trim))
	Kit.light(pumpkin, hex(look.Glow), 7, 1)
end

function maskShapes.paper(model: Model, look: { [string]: any })
	facePlate(model, hex(look.Base), Enum.Material.Fabric, EYE_Y + 0.4, EYE_Y - 0.55)
	for _, y in { EYE_Y + 0.38, EYE_Y - 0.53 } do
		Kit.block(model, CFrame.new(0, y, Z - 0.03), Vector3.new(1.3, 0.08, 0.05), hex(look.Trim))
	end
	for i = -2, 2 do
		Kit.block(model, CFrame.new(i * 0.28, EYE_Y - 0.08, Z - 0.03), Vector3.new(0.03, 0.9, 0.03), hex(look.Trim))
	end
	local glow = Kit.glow(model, CFrame.new(0, EYE_Y - 0.4, Z - 0.05), Vector3.new(0.3, 0.06, 0.02), hex(look.Glow))
	Kit.light(glow, hex(look.Glow), 5, 0.7)
end

-- A mask as a still model, the face's front at the origin, facing -Z.
function Gear.maskModel(itemId: string): Model
	local look = lookOf(itemId, "Mask")
	local model = Kit.model(nil, "Mask")
	local build = maskShapes[look.Shape] or maskShapes.domino
	build(model, look)
	if look.Sparkle and model:FindFirstChildWhichIsA("BasePart") then
		extras(model:FindFirstChildWhichIsA("BasePart") :: BasePart, { Sparkle = look.Sparkle })
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Worn and held ----------------------------------------------------------

-- Turns a still model into something a character can carry: every part
-- loose, weightless and welded to handle, which nothing else touches.
local function rig(model: Model, handle: BasePart)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end

-- A tool around a still model: its Handle is an invisible grip at the
-- origin and everything else is welded to it.
local function toolFrom(model: Model, name: string, tip: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = tip
	local handle = Kit.block(tool, CFrame.new(), Vector3.new(0.3, 0.6, 0.3), Color3.new(1, 1, 1))
	handle.Name = "Handle"
	handle.Transparency = 1
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	rig(tool :: any, handle)
	-- Held upright in the fist for a blade, level and pointing ahead for a
	-- blaster: the grip is the handle's middle, and the handle's axes match
	-- the hand's.
	tool.Grip = CFrame.new()
	return tool
end

function Gear.blade(itemId: string): Tool
	local tool = toolFrom(Gear.bladeModel(itemId), "Blade", "Click to tag. Press E to throw.")
	tool:SetAttribute("Skin", itemId)
	return tool
end

function Gear.blaster(itemId: string): Tool
	local tool = toolFrom(Gear.blasterModel(itemId), "Blaster", "Click to zap.")
	tool:SetAttribute("Skin", itemId)
	return tool
end

-- The mask as an Accessory for Humanoid:AddAccessory.
function Gear.mask(itemId: string): Accessory
	local accessory = Instance.new("Accessory")
	accessory.Name = "PartyMask"
	local handle = Kit.block(accessory, CFrame.new(), Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1))
	handle.Name = "Handle"
	handle.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Name = "FaceFrontAttachment"
	attachment.Parent = handle
	local model = Gear.maskModel(itemId)
	for _, child in model:GetChildren() do
		child.Parent = accessory
	end
	model:Destroy()
	rig(accessory :: any, handle)
	accessory:SetAttribute("Skin", itemId)
	return accessory
end

-- A trail behind root. Returns what it made, or nothing for No Trail.
function Gear.trail(itemId: string, root: BasePart): { Instance }
	local look = lookOf(itemId, "Trail")
	local colors = look.Colors
	if #colors == 0 then
		return {}
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.9, 0.4)
	bottom.Parent = root
	local keypoints = {}
	for index, color in colors do
		local at = if #colors == 1 then 0 else (index - 1) / (#colors - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(at, hex(color)))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, hex(colors[1])))
	end
	local trail = Instance.new("Trail")
	trail.Name = "PartyTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.LightEmission = look.Light or 0
	trail.Lifetime = 0.55
	trail.MinLength = 0.2
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail:SetAttribute("Skin", itemId)
	trail.Parent = root
	local made: { Instance } = { top, bottom, trail }
	if look.Sparkle then
		table.insert(made, particles(root, SPARKLES, hex(look.Sparkle), 4))
	end
	return made
end

-- Knockout effects -------------------------------------------------------

-- One of the pieces a knockout flings out, for the client to move: number
-- picks the colour from the effect's list. Built at the origin.
function Gear.burstPiece(style: string, colors: { string }, number: number): Model
	local model = Kit.model(nil, "Piece")
	local color = hex(colors[(number - 1) % #colors + 1])
	if style == "confetti" then
		Kit.block(model, CFrame.new(), Vector3.new(0.3, 0.05, 0.2), color, Enum.Material.Neon)
	elseif style == "bubbles" then
		local bubble = Kit.ball(model, CFrame.new(), Vector3.new(0.6, 0.6, 0.6), color, Enum.Material.Glass)
		bubble.Transparency = 0.5
	elseif style == "bats" then
		Kit.ball(model, CFrame.new(), Vector3.new(0.3, 0.3, 0.4), hex(colors[1]))
		for _, side in { -1, 1 } do
			Kit.wedge(
				model,
				CFrame.new(side * 0.35, 0.05, 0) * CFrame.Angles(0, side * PI / 2, 0),
				Vector3.new(0.05, 0.25, 0.5),
				hex(colors[1])
			)
		end
		Kit.glow(model, CFrame.new(0.07, 0.05, -0.18), Vector3.new(0.06, 0.06, 0.04), hex(colors[2] or colors[1]), true)
		Kit.glow(model, CFrame.new(-0.07, 0.05, -0.18), Vector3.new(0.06, 0.06, 0.04), hex(colors[2] or colors[1]), true)
	elseif style == "stars" or style == "sparkle" then
		Kit.glow(model, CFrame.new(), Vector3.new(0.12, 0.5, 0.12), color)
		Kit.glow(model, CFrame.new(), Vector3.new(0.5, 0.12, 0.12), color)
	elseif style == "ghosts" then
		Kit.ball(model, CFrame.new(0, 0.2, 0), Vector3.new(0.6, 0.6, 0.6), color, Enum.Material.Neon).Transparency = 0.3
		Kit.wedge(model, CFrame.new(0, -0.25, 0) * CFrame.Angles(0, 0, PI), Vector3.new(0.55, 0.4, 0.5), color, Enum.Material.Neon).Transparency =
			0.3
		Kit.ball(model, CFrame.new(0.12, 0.3, -0.28), Vector3.new(0.1, 0.14, 0.05), hex("#1C1C28"))
		Kit.ball(model, CFrame.new(-0.12, 0.3, -0.28), Vector3.new(0.1, 0.14, 0.05), hex("#1C1C28"))
	elseif style == "leaves" or style == "petals" then
		Kit.ball(model, CFrame.new(), Vector3.new(0.4, 0.05, 0.25), color, Enum.Material.Fabric)
	elseif style == "supernova" then
		Kit.glow(model, CFrame.new(), Vector3.new(0.35, 0.35, 0.35), color, true)
	else
		-- smoke
		local puff = Kit.ball(model, CFrame.new(), Vector3.new(1.2, 1.2, 1.2), color, Enum.Material.SmoothPlastic)
		puff.Transparency = 0.35
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- A still picture of a knockout effect or trail for the shop: a cluster of
-- its pieces, or a ribbon of the trail's colours.
local function effectPreview(itemId: string): Model
	local look = lookOf(itemId, "Effect")
	local model = Kit.model(nil, "Effect")
	for i = 1, 9 do
		local angle = i / 9 * PI * 2
		local piece = Gear.burstPiece(look.Style, look.Colors, i)
		Kit.place(piece, CFrame.new(math.cos(angle) * 1.1, math.sin(angle) * 1.1, 0) * CFrame.Angles(angle, angle * 2, 0))
		for _, child in piece:GetChildren() do
			child.Parent = model
		end
		piece:Destroy()
	end
	Kit.glow(model, CFrame.new(), Vector3.new(0.5, 0.5, 0.5), hex(look.Colors[1]), true)
	model.WorldPivot = CFrame.new()
	return model
end

local function trailPreview(itemId: string): Model
	local look = lookOf(itemId, "Trail")
	local model = Kit.model(nil, "Trail")
	local colors = look.Colors
	if #colors == 0 then
		Kit.block(model, CFrame.new(), Vector3.new(2.5, 0.1, 0.1), hex("#555566"))
		model.WorldPivot = CFrame.new()
		return model
	end
	for i = 0, 7 do
		local color = hex(colors[i % #colors + 1])
		local part = Kit.block(
			model,
			CFrame.new(-1.6 + i * 0.45, math.sin(i * 0.8) * 0.3, 0),
			Vector3.new(0.47, 1.4 - i * 0.12, 0.05),
			color,
			if (look.Light or 0) > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
		part.Transparency = i * 0.08
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- A model of any item, for the shop, the inventory and the crate reveal.
function Gear.preview(itemId: string): Model
	local item = Items.get(itemId)
	local kind = if item then item.Kind else "Mask"
	if kind == "Blade" then
		return Gear.bladeModel(itemId)
	elseif kind == "Blaster" then
		return Gear.blasterModel(itemId)
	elseif kind == "Effect" then
		return effectPreview(itemId)
	elseif kind == "Trail" then
		return trailPreview(itemId)
	end
	return Gear.maskModel(itemId)
end

return Gear
