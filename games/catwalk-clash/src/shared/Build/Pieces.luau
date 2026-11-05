--!strict
-- Turns a wardrobe piece (Config/Wardrobe) into Accessory instances made of
-- parts, painted in the colours and finish the player picked. The server
-- puts them on characters with Humanoid:AddAccessory, which hangs each one
-- from the body attachment it names; clients use Pieces.preview for the
-- pictures in the wardrobe.

local Kit = require(script.Parent.Kit)
local Palette = require(script.Parent.Parent.Config.Palette)
local Wardrobe = require(script.Parent.Parent.Config.Wardrobe)

local Pieces = {}

-- The attribute that marks an accessory as one of the game's own pieces.
Pieces.ATTRIBUTE = "StudioPiece"

-- R15 and R6 hands hold things with this turn on their grip attachments.
local GRIP_TURN = CFrame.Angles(math.rad(-90), 0, 0)

type Paints = { Main: Color3, Accent: Color3, Finish: string }

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
})

local function paintColor(paint: string?, paints: Paints): Color3
	if paint == nil or paint == "Main" then
		return paints.Main
	elseif paint == "Accent" then
		return paints.Accent
	end
	return Palette.resolve(paint, paints.Main)
end

local function finishFor(shape: { [any]: any }, paints: Paints): Palette.Finish
	if shape.m then
		return Palette.finish(shape.m)
	end
	if shape.c == nil or shape.c == "Main" then
		return Palette.finish(paints.Finish)
	end
	return Palette.finish("Satin")
end

local function newPart(className: string, size: Vector3, cframe: CFrame, color: Color3, finish: Palette.Finish, transparency: number?): BasePart
	local part = Instance.new(className) :: BasePart
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = finish.Material
	part.Reflectance = finish.Reflectance
	part.Transparency = transparency or (if finish.Material == Enum.Material.Glass then 0.25 else 0)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function ellipsoid(size: Vector3, cframe: CFrame, color: Color3, finish: Palette.Finish, transparency: number?): BasePart
	local part = newPart("Part", size, cframe, color, finish, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function ball(diameter: number, cframe: CFrame, color: Color3, finish: Palette.Finish, transparency: number?): BasePart
	local part = newPart("Part", Vector3.new(diameter, diameter, diameter), cframe, color, finish, transparency)
	;(part :: Part).Shape = Enum.PartType.Ball
	return part
end

local function cylinder(size: Vector3, cframe: CFrame, color: Color3, finish: Palette.Finish, transparency: number?): BasePart
	local part = newPart("Part", size, cframe, color, finish, transparency)
	;(part :: Part).Shape = Enum.PartType.Cylinder
	return part
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- The parts for one shape, placed relative to the piece's origin.
local function buildShape(shape: { [any]: any }, paints: Paints, mirror: boolean): { BasePart }
	local kind = shape[1]
	local color = paintColor(shape.c, paints)
	local finish = finishFor(shape, paints)
	local p = shape.p or { 0, 0, 0 }
	local r = shape.r or { 0, 0, 0 }
	if mirror then
		p = { -p[1], p[2], p[3] }
		r = { r[1], -r[2], -r[3] }
	end
	local origin = Kit.cf(p, r)
	local t = shape.t
	local parts = {}

	if kind == "Block" then
		table.insert(parts, newPart("Part", Kit.v3(shape.s), origin, color, finish, t))
	elseif kind == "Wedge" then
		table.insert(parts, newPart("WedgePart", Kit.v3(shape.s), origin, color, finish, t))
	elseif kind == "Egg" then
		table.insert(parts, ellipsoid(Kit.v3(shape.s), origin, color, finish, t))
	elseif kind == "Ball" then
		table.insert(parts, ball(shape.s[1], origin, color, finish, t))
	elseif kind == "Cyl" then
		table.insert(parts, cylinder(Kit.v3(shape.s), origin, color, finish, t))
	elseif kind == "Disc" then
		local size = Vector3.new(shape.h, shape.rad * 2, shape.rad * 2)
		table.insert(parts, cylinder(size, origin * UPRIGHT, color, finish, t))
	elseif kind == "Cone" then
		local steps = shape.n or 4
		local height = shape.h / steps
		for step = 1, steps do
			local along = (step - 0.5) / steps
			local radius = shape.rad + (shape.top - shape.rad) * along
			local y = -shape.h / 2 + (step - 0.5) * height
			local size = Vector3.new(height * 1.02, radius * 2, radius * 2)
			table.insert(parts, cylinder(size, origin * CFrame.new(0, y, 0) * UPRIGHT, color, finish, t))
		end
	elseif kind == "Ring" then
		local count = shape.n
		local from, to = 0, 360
		local closed = true
		if shape.arc then
			from, to = shape.arc[1], shape.arc[2]
			closed = to - from >= 360
		end
		local step = if closed then (to - from) / count else (to - from) / math.max(1, count - 1)
		local size = Kit.v3(shape.s)
		local uniform = size.X == size.Y and size.Y == size.Z
		for index = 0, count - 1 do
			local angle = math.rad(from + step * index)
			local local_ = CFrame.new(shape.rad * math.sin(angle), 0, -shape.rad * math.cos(angle))
				* CFrame.Angles(0, -angle, 0)
			local cframe = origin * local_
			local bead = shape.bead
			if bead == "Block" then
				table.insert(parts, newPart("Part", size, cframe, color, finish, t))
			elseif uniform and bead ~= "Egg" then
				table.insert(parts, ball(size.X, cframe, color, finish, t))
			else
				table.insert(parts, ellipsoid(size, cframe, color, finish, t))
			end
		end
	else
		error(`Unknown shape kind {tostring(kind)}`)
	end
	return parts
end

local function emitter(parent: Instance, effect: { [string]: any }, paints: Paints)
	local texture = Wardrobe.Textures[effect.Texture or "Sparkle"] or Wardrobe.Textures.Sparkle
	local colorName = effect.Color or "Main"
	local color = if colorName == "Rainbow"
		then RAINBOW
		else ColorSequence.new(paintColor(colorName, paints))
	local kind = effect.Kind
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = texture
	particles.Color = color
	particles.LightEmission = 0.8
	particles.Rate = effect.Rate or 10
	particles.Lifetime = NumberRange.new(0.8, 1.6)
	particles.Speed = NumberRange.new(0.5, 1.5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, if effect.Big then 0.5 else 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new(0.1)
	if kind == "Fall" then
		particles.Acceleration = Vector3.new(0, -3, 0)
		particles.Lifetime = NumberRange.new(1.5, 2.5)
		particles.Speed = NumberRange.new(0.2, 0.6)
	elseif kind == "Rise" then
		particles.Acceleration = Vector3.new(0, 3, 0)
		particles.Lifetime = NumberRange.new(1.2, 2)
	elseif kind == "Haze" then
		particles.Lifetime = NumberRange.new(2, 3)
		particles.Speed = NumberRange.new(0.1, 0.4)
		particles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		particles.Size = NumberSequence.new(2.5)
		particles.LightEmission = 0.4
	elseif kind == "Thrust" then
		particles.Acceleration = Vector3.new(0, -6, 0)
		particles.Lifetime = NumberRange.new(0.3, 0.5)
		particles.SpreadAngle = Vector2.new(12, 12)
		particles.Speed = NumberRange.new(3, 5)
		particles.EmissionDirection = Enum.NormalId.Bottom
		particles.Rate = 40
	elseif effect.Slow then
		particles.Lifetime = NumberRange.new(2, 3)
		particles.Speed = NumberRange.new(0.1, 0.3)
	end
	particles.Parent = parent
end

local function weld(handle: BasePart, part: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = handle
	constraint.Part1 = part
	constraint.Parent = part
end

-- Builds one accessory for a piece. mirror flips it left to right, for the
-- right shoe of a pair.
local function buildAccessory(piece: Wardrobe.Piece, paints: Paints, attachName: string, mirror: boolean): Accessory
	local accessory = Instance.new("Accessory")
	accessory.Name = `Studio_{piece.Id}`
	accessory:SetAttribute(Pieces.ATTRIBUTE, piece.Id)
	accessory:SetAttribute("Slot", piece.Slot)

	local handle = newPart("Part", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), paints.Main, Palette.finish("Satin"), 1)
	handle.Name = "Handle"
	handle.Parent = accessory
	local attachment = Instance.new("Attachment")
	attachment.Name = attachName
	if string.find(attachName, "Grip") then
		attachment.CFrame = GRIP_TURN
	end
	attachment.Parent = handle

	local first: BasePart? = nil
	for _, shape in piece.Shapes do
		for _, part in buildShape(shape, paints, mirror) do
			part.Name = "Piece"
			part.Parent = accessory
			weld(handle, part)
			first = first or part
		end
	end

	-- Auras glow and sparkle from a box around the body.
	local effects = piece.Effects or {}
	if #effects > 0 then
		local volume = handle
		if piece.Slot == "Aura" then
			volume = newPart("Part", Vector3.new(2.6, 5, 1.8), CFrame.new(0, -1.2, 0.5), paints.Main, Palette.finish("Satin"), 1)
			volume.Name = "AuraVolume"
			volume.Parent = accessory
			weld(handle, volume)
		end
		for _, effect in effects do
			local host: Instance = volume
			if effect.At then
				local at = Instance.new("Attachment")
				at.Name = "EffectAt"
				at.Position = Kit.v3(effect.At)
				at.Parent = handle
				host = at
			end
			emitter(host, effect, paints)
		end
	end

	if piece.Light then
		local light = Instance.new("PointLight")
		light.Color = paintColor(piece.Light.Color, paints)
		light.Range = piece.Light.Range
		light.Brightness = piece.Light.Brightness
		light.Shadows = false
		light.Parent = handle
	end

	if piece.Label and first then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = first
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = piece.Label
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = paints.Accent
		label.Parent = gui
	end
	return accessory
end

-- The accessories for a piece: one, or a left and right for a pair.
function Pieces.build(piece: Wardrobe.Piece, main: Color3, accent: Color3, finish: string): { Accessory }
	local paints = { Main = main, Accent = accent, Finish = finish }
	local attachName = Wardrobe.attachmentFor(piece)
	local list = { buildAccessory(piece, paints, attachName, false) }
	if piece.Pair then
		table.insert(list, buildAccessory(piece, paints, "RightFootAttachment", true))
	end
	return list
end

-- A piece as a loose model at the origin, for pictures: the accessory's
-- parts are already in place, so nothing needs to run.
function Pieces.preview(piece: Wardrobe.Piece, main: Color3, accent: Color3, finish: string): Model
	local model = Instance.new("Model")
	model.Name = piece.Id
	local accessory = Pieces.build(piece, main, accent, finish)[1]
	for _, child in accessory:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = model
		end
	end
	accessory:Destroy()
	return model
end

-- The default-coloured accessories for a piece.
function Pieces.buildDefault(piece: Wardrobe.Piece): { Accessory }
	return Pieces.build(piece, Palette.resolve(piece.Main), Palette.resolve(piece.Accent), piece.Finish)
end

return Pieces
