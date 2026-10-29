-- Helpers for building models out of parts in code, which is how theme packs
-- make their props and scenery until real art exists. Everything made here is
-- anchored, and unless made solid it can't be walked into or touched, so
-- decoration never blocks a player or sets off a buy button.
--
-- It only creates Instances and does no work at runtime, so the tests can load
-- the theme's builders and check what they make.

local Kit = {}

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

-- Marks a part to be painted in one of its plot owner's festival colours
-- (Config/Festival palettes): 1 or 2, the palette's first or second colour.
-- The server paints it; until then it keeps the colour it was made with.
function Kit.paint<T>(part: T, index: number): T
	(part :: any):SetAttribute("Paint", index)
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

-- The invisible box a built station is measured by. Labels sit on it and the
-- plot's activity walks to its edges.
function Kit.anchor(model: Model, origin: CFrame, size: Vector3): Part
	local anchor = decor("Part", model, origin * CFrame.new(0, size.Y / 2, 0), size, Color3.new(1, 1, 1))
	anchor.Name = "Anchor"
	anchor.Transparency = 1
	anchor.CanQuery = false
	model.PrimaryPart = anchor
	return anchor
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

-- Marks a spot where visitors stop on their way round the plot (see
-- client/PlotActivity): they walk to it, turn the way cframe faces and wait
-- pause seconds. options can give a Pose while they wait ("Sit", "Jump" or
-- "Cheer"), something to Carry away (a name from Crowd.carry) and the Chance
-- that a visitor comes at all (0.6 if not given). The stop hangs off part.
function Kit.stop(part: BasePart, cframe: CFrame, pause: number, options: { [string]: any }?): Attachment
	local stop = Instance.new("Attachment")
	stop.Name = "VisitorStop"
	stop.CFrame = part.CFrame:ToObjectSpace(cframe)
	stop:SetAttribute("Pause", pause)
	for name, value in options or {} do
		stop:SetAttribute(name, value)
	end
	stop:AddTag("VisitorStop")
	stop.Parent = part
	return stop
end

-- A repeatable random sequence, so scenery comes out the same every time.
export type Random = {
	number: (min: number, max: number) -> number,
	integer: (min: number, max: number) -> number,
	pick: <T>(list: { T }) -> T,
}

function Kit.random(seed: number): Random
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local random = {}
	function random.number(min: number, max: number): number
		state = (state * 16807) % 2147483647
		return min + (max - min) * (state - 1) / 2147483646
	end
	function random.integer(min: number, max: number): number
		return math.min(max, math.floor(random.number(min, max + 1)))
	end
	function random.pick<T>(list: { T }): T
		return list[random.integer(1, #list)]
	end
	return random :: Random
end

return Kit
