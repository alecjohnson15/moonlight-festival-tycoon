-- Helpers for building models out of parts in code, which is how the lobby,
-- the maps and every cosmetic are made. Everything made here is anchored,
-- and unless made solid it can't be walked into or touched, so decoration
-- never blocks a player or trips a pickup. Floors, walls and stairs are made
-- solid by their own helpers below.
--
-- It only creates Instances and does no work at runtime, so the tests can
-- load the builders and check what they make. (Started from the Halloween
-- Tycoon's Kit in this repository.)

local Rng = require(script.Parent.Parent.Rng)

local Kit = {}

-- A repeatable random sequence, so scenery comes out the same every time.
Kit.random = Rng.new

local colors: { [string]: Color3 } = {}

function Kit.color(hex: string): Color3
	local color = colors[hex]
	if not color then
		color = Color3.fromHex(hex)
		colors[hex] = color
	end
	return color
end

-- A copy of a theme palette with every hex string turned into a Color3,
-- including the strings inside lists.
function Kit.palette(source: { [string]: any }): { [string]: any }
	local palette = {}
	for name, value in source do
		if type(value) == "table" then
			local list = {}
			for index, hex in value do
				list[index] = Kit.color(hex)
			end
			palette[name] = list
		else
			palette[name] = Kit.color(value)
		end
	end
	return palette
end

-- Makes an Instance, sets its properties and parents it last.
function Kit.new(className: string, parent: Instance?, properties: { [string]: any }?): any
	local instance = Instance.new(className)
	if properties then
		for name, value in properties do
			(instance :: any)[name] = value
		end
	end
	instance.Parent = parent
	return instance
end

function Kit.model(parent: Instance?, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function decor(
	className: string,
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): any
	local part = Instance.new(className)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

function Kit.block(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	return decor("Part", parent, cframe, size, color, material)
end

-- A wedge's sloped face points along its front (-Z), dropping from its top
-- back edge to its bottom front edge.
function Kit.wedge(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): WedgePart
	return decor("WedgePart", parent, cframe, size, color, material)
end

-- A ball, or an egg shape when the size isn't the same on every side.
function Kit.ball(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = decor("Part", parent, cframe, size, color, material)
	if size.X == size.Y and size.Y == size.Z then
		part.Shape = Enum.PartType.Ball
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	return part
end

-- A cylinder standing upright, centred on cframe.
function Kit.post(
	parent: Instance,
	cframe: CFrame,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local part = decor(
		"Part",
		parent,
		cframe * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A cylinder lying along cframe's X axis, like a log.
function Kit.log(
	parent: Instance,
	cframe: CFrame,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local part = decor("Part", parent, cframe, Vector3.new(length, diameter, diameter), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A CFrame at from, looking at to. A straight up or down look turns about X
-- instead of Y, so it has a direction everywhere, in Roblox and in tests.
function Kit.facing(from: Vector3, to: Vector3): CFrame
	local direction = to - from
	local up = if math.abs(direction.Unit.Y) > 0.999 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(from, to, up)
end

-- A block running from a to b, such as a rail or a hedge.
function Kit.span(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material?
): Part
	local length = (b - a).Magnitude
	return decor("Part", parent, Kit.facing((a + b) / 2, b), Vector3.new(width, height, length), color, material)
end

-- A glowing part. Neon blooms at night, so it reads as a light on its own.
function Kit.glow(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, round: boolean?): Part
	if round then
		return Kit.ball(parent, cframe, size, color, Enum.Material.Neon)
	end
	return decor("Part", parent, cframe, size, color, Enum.Material.Neon)
end

-- Lets players bump into a part, and gives it a shadow.
function Kit.solid<T>(part: T): T
	local base = part :: any
	base.CanCollide = true
	base.CastShadow = true
	return part
end

-- A light on a part. Flickering lights are tagged for the client to animate.
function Kit.light(part: BasePart, color: Color3, range: number, brightness: number, flicker: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	if flicker then
		light:AddTag("Flicker")
	end
	return light
end

-- A coloured spotlight on a small fixture at from, aimed at to, for washing a
-- build in colour the way a stage light would.
function Kit.wash(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	color: Color3,
	range: number,
	brightness: number
): SpotLight
	local fixture = decor("Part", parent, Kit.facing(from, to), Vector3.new(0.5, 0.5, 0.6), Color3.fromRGB(30, 28, 36))
	fixture.Name = "Wash"
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 75
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = fixture
	return light
end

-- Marks a model to bob up and down by height every seconds and, with
-- spinSeconds, turn once every spinSeconds around spinAxis (in the pivot's
-- space, upright by default). The client does the moving; see client/Motion.
function Kit.float(
	model: Model,
	pivot: CFrame,
	height: number,
	seconds: number,
	spinSeconds: number?,
	spinAxis: Vector3?
)
	model.WorldPivot = pivot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("FloatHeight", height)
	model:SetAttribute("FloatSeconds", seconds)
	model:SetAttribute("SpinSeconds", spinSeconds or 0)
	model:SetAttribute("SpinAxis", spinAxis or Vector3.new(0, 1, 0))
	model:AddTag("Float")
end

-- Marks a model to glide offset studs (in the pivot's space) away from its
-- pivot and back, once every seconds, facing the way it's going, like a
-- ghost on patrol. See client/Motion.
function Kit.patrol(model: Model, pivot: CFrame, offset: Vector3, seconds: number)
	model.WorldPivot = pivot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("PatrolOffset", offset)
	model:SetAttribute("PatrolSeconds", seconds)
	model:AddTag("Patrol")
end

-- Marks a model, built hidden, to pop up by height and drop back once every
-- seconds, like a jump scare. See client/Motion.
function Kit.pop(model: Model, pivot: CFrame, height: number, seconds: number)
	model.WorldPivot = pivot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("PopHeight", height)
	model:SetAttribute("PopSeconds", seconds)
	model:AddTag("Pop")
end

-- A solid, anchored block for floors, walls and furniture people bump into.
function Kit.slab(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = decor("Part", parent, cframe, size, color, material)
	part.CanCollide = true
	part.CastShadow = true
	return part
end

export type Opening = {
	-- Distance along the wall from its start to the opening's middle.
	At: number,
	Width: number,
	Height: number,
	-- Height of the opening's bottom above the wall's base (0 for a door).
	Bottom: number?,
}

-- A solid wall from a to b (both at the wall's base), height tall and
-- thickness thick, with holes for doors and windows. Each hole gets a lintel
-- over it and, for windows, a sill under it. Returns the wall's parts.
function Kit.wall(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	height: number,
	thickness: number,
	color: Color3,
	material: Enum.Material?,
	openings: { Opening }?
): { Part }
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt(a, b) -- -Z runs along the wall
	local parts = {}
	local function piece(from: number, to: number, bottom: number, top: number)
		if to - from < 0.05 or top - bottom < 0.05 then
			return
		end
		local middle = (from + to) / 2
		local centre = frame * CFrame.new(0, (bottom + top) / 2, -middle)
		local part = Kit.slab(parent, centre, Vector3.new(thickness, top - bottom, to - from), color, material)
		table.insert(parts, part)
	end
	local holes = table.clone(openings or {})
	table.sort(holes, function(x, y)
		return x.At < y.At
	end)
	local cursor = 0
	for _, hole in holes do
		local from = math.clamp(hole.At - hole.Width / 2, 0, length)
		local to = math.clamp(hole.At + hole.Width / 2, 0, length)
		local bottom = hole.Bottom or 0
		piece(cursor, from, 0, height)
		piece(from, to, 0, bottom)
		piece(from, to, math.min(height, bottom + hole.Height), height)
		cursor = to
	end
	piece(cursor, length, 0, height)
	return parts
end

-- A flight of stairs. bottom is the middle of the first step's front edge
-- on the floor, facing up the flight (its -Z). The steps are for looks; an
-- invisible ramp under them is what players walk on, so climbing is smooth.
function Kit.stairs(
	parent: Instance,
	bottom: CFrame,
	width: number,
	rise: number,
	run: number,
	color: Color3,
	material: Enum.Material?
): Model
	local model = Kit.model(parent, "Stairs")
	local count = math.max(1, math.floor(rise + 0.5))
	local stepRise = rise / count
	local stepRun = run / count
	for i = 1, count do
		local top = stepRise * i
		decor(
			"Part",
			model,
			bottom * CFrame.new(0, top / 2, -(i - 0.5) * stepRun),
			Vector3.new(width, top, stepRun),
			color,
			material
		)
	end
	-- The ramp: a wedge whose slope rises from the first step to the top.
	local ramp = decor(
		"WedgePart",
		model,
		bottom * CFrame.new(0, rise / 2, -run / 2) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(width, rise, run),
		color
	)
	ramp.Name = "Ramp"
	ramp.Transparency = 1
	ramp.CanCollide = true
	return model
end

-- Moves every part of a model built round the origin to sit at cframe
-- instead. (PivotTo does the same in Roblox, but this also runs in the
-- tests.)
function Kit.place(model: Instance, cframe: CFrame)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = cframe * part.CFrame
		end
	end
	if model:IsA("Model") then
		model.WorldPivot = cframe * model.WorldPivot
	end
end

-- An invisible, solid wall, to keep players inside a map's edges.
function Kit.barrier(parent: Instance, cframe: CFrame, size: Vector3): Part
	local part = decor("Part", parent, cframe, size, Color3.new(1, 1, 1))
	part.Name = "Barrier"
	part.Transparency = 1
	part.CanCollide = true
	part.CanQuery = false
	return part
end

-- An invisible marker part, such as a spawn point or a place a coin can
-- appear. The server reads them; nothing collides with them.
function Kit.marker(parent: Instance, name: string, cframe: CFrame): Part
	local part = decor("Part", parent, cframe, Vector3.new(1, 1, 1), Color3.new(1, 1, 1))
	part.Name = name
	part.Transparency = 1
	part.CanQuery = false
	return part
end

-- A sign: a board with words on its front (-Z) face.
function Kit.sign(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	board: Color3,
	text: string,
	textColor: Color3,
	font: Enum.Font?
): Part
	local part = decor("Part", parent, cframe, size, board)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.Parent = gui
	return part
end

-- Marks a model to turn about its pivot's up axis once every seconds (or the
-- other way with a negative number). The client turns it; see client/Motion.
function Kit.spin(model: Model, pivot: CFrame, seconds: number)
	model.WorldPivot = pivot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("SpinSeconds", seconds)
	model:AddTag("Spin")
end

return Kit
