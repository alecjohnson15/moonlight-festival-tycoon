--!strict
-- Small helpers for building things out of parts. Used by the wardrobe
-- pieces and the world; loads in Lune too, so tests build everything.

local Kit = {}

function Kit.make(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- An anchored world part.
function Kit.part(parent: Instance, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

function Kit.model(name: string, parent: Instance?): Model
	return Kit.make("Model", { Name = name }, parent)
end

function Kit.folder(name: string, parent: Instance?): Folder
	return Kit.make("Folder", { Name = name }, parent)
end

-- CFrame from a position and rotation in degrees.
function Kit.cf(position: { number }, rotation: { number }?): CFrame
	local r = rotation or { 0, 0, 0 }
	return CFrame.new(position[1], position[2], position[3])
		* CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
end

function Kit.v3(list: { number }): Vector3
	return Vector3.new(list[1], list[2], list[3])
end

-- A sign with text on its front face (-Z).
function Kit.sign(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	text: string,
	colors: { Back: Color3, Text: Color3, Stroke: Color3? },
	font: Enum.Font?
): BasePart
	local board = Kit.part(parent, {
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = colors.Back,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local gui = Kit.make("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
	}, board)
	local label = Kit.make("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = font or Enum.Font.FredokaOne,
		TextColor3 = colors.Text,
	}, gui)
	if colors.Stroke then
		Kit.make("UIStroke", { Color = colors.Stroke, Thickness = 3 }, label)
	end
	Kit.make("UIPadding", {
		PaddingLeft = UDim.new(0.04, 0),
		PaddingRight = UDim.new(0.04, 0),
		PaddingTop = UDim.new(0.08, 0),
		PaddingBottom = UDim.new(0.08, 0),
	}, label)
	return board
end

-- A light in a small glowing housing, pointing along the CFrame's look
-- vector.
function Kit.spot(
	parent: Instance,
	cframe: CFrame,
	color: Color3,
	range: number,
	angle: number,
	brightness: number
): BasePart
	local housing = Kit.part(parent, {
		Name = "Spot",
		Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Kit.make("SpotLight", {
		Face = Enum.NormalId.Front,
		Range = range,
		Angle = angle,
		Brightness = brightness,
		Color = color,
		Shadows = false,
	}, housing)
	return housing
end

return Kit
