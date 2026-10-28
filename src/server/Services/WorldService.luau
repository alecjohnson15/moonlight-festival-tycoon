-- The night the game is set in. Applies the theme's lighting, haze, sky and
-- colour grading, paints the terrain, and dresses the plots, the plaza, the
-- arena and the land around them with the theme's scenery. Runs after
-- PlotService and ArenaService, so the plots and the arena's stage exist.
-- Changes made on the server replicate to every client.
--
-- A place that already has a Workspace.Scenery folder keeps its own scenery
-- and terrain, and only gets the lighting.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local WorldService = {}

-- Theme values are plain data; hex strings become colours.
local function convert(value: any): any
	if type(value) == "string" and string.sub(value, 1, 1) == "#" then
		return Color3.fromHex(value)
	end
	return value
end

local function apply(instance: Instance, properties: { [string]: any })
	for name, value in properties do
		(instance :: any)[name] = convert(value)
	end
end

local function applyLook(look)
	apply(Lighting, look.Lighting)
	-- Replaces the sky and effects a template place comes with, including sun
	-- rays and depth of field, which fight the night look.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	for _, className in { "Atmosphere", "Sky", "BloomEffect", "ColorCorrectionEffect" } do
		local properties = look[className]
		if properties then
			local effect = Instance.new(className)
			apply(effect, properties)
			effect.Parent = Lighting
		end
	end
end

local function paintTerrain(look, fills)
	local terrain = Workspace.Terrain
	for name, hex in look.Terrain do
		terrain:SetMaterialColor(Enum.Material[name], Color3.fromHex(hex))
	end
	terrain.WaterColor = Color3.fromHex(look.WaterColor)
	for _, fill in fills do
		local material = Enum.Material[fill.Material]
		if fill.Shape == "Block" then
			terrain:FillBlock(fill.CFrame, fill.Size, material)
		elseif fill.Shape == "Ball" then
			terrain:FillBall(fill.Centre, fill.Radius, material)
		elseif fill.Shape == "Cylinder" then
			terrain:FillCylinder(fill.CFrame, fill.Height, fill.Radius, material)
		end
	end
end

function WorldService.init()
	applyLook(Theme.Look)
	if Workspace:FindFirstChild("Scenery") then
		return
	end

	local plots = {}
	local folder = Workspace:FindFirstChild("Plots")
	if folder then
		for _, plot in folder:GetChildren() do
			if plot:IsA("BasePart") then
				table.insert(plots, plot)
			end
		end
	end
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)
	local spawns = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			table.insert(spawns, descendant)
		end
	end
	local plaza = Workspace:FindFirstChild("Plaza")
	local arena = Workspace:FindFirstChild("Arena")
	local stage = arena and arena:FindFirstChild("Stage")

	-- The terrain replaces the flat baseplate a new place starts with.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end

	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	for index, plot in plots do
		Theme.Scenery.plot(plot, index, scenery)
	end
	local fills = Theme.Scenery.world({
		Plots = plots,
		Plaza = if plaza and plaza:IsA("BasePart") then plaza else nil,
		Spawns = spawns,
		Arena = if stage and stage:IsA("BasePart") then stage else nil,
	}, scenery)
	if stage and stage:IsA("BasePart") then
		Theme.Arena.dress(stage, scenery)
	end
	paintTerrain(Theme.Look, fills)
	scenery.Parent = Workspace
end

return WorldService
