-- Builds the theme pack's props and scenery with Lune's Roblox library and
-- checks they fit: every model inside its slot, plot dressing clear of the
-- slots, buttons, gate and walkway, and the world clear of the plots. Building
-- them also checks every property they set exists and takes that type.

local TestKit = require("./TestKit")
local Loader = require("./RobloxLoader")
local Balance = require("../src/shared/Config/Balance")
local Layout = require("../src/shared/Config/Layout")
local Progression = require("../src/shared/Progression")
local Theme = require("../src/shared/Themes/MoonlightFestival")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local roblox = Loader.roblox
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local Props = Loader.require("src/shared/Themes/MoonlightFestival/Props")
local Scenery = Loader.require("src/shared/Themes/MoonlightFestival/Scenery")

local TOLERANCE = 0.06

-- A plot and slot somewhere off the origin and turned, so a builder that
-- ignores its origin shows up.
local PLOT_CFRAME = CFrame.new(60, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)

local function partsIn(root: any): { any }
	local parts = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- The box around a part, in the space of frame, as min and max corners.
local function boxIn(part: any, frame: any): (any, any)
	local half = part.Size / 2
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = frame:PointToObjectSpace(part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				local values = { corner.X, corner.Y, corner.Z }
				for axis = 1, 3 do
					lo[axis] = math.min(lo[axis], values[axis])
					hi[axis] = math.max(hi[axis], values[axis])
				end
			end
		end
	end
	return lo, hi
end

-- Whether a box overlaps a region given as { minX, minY, minZ, maxX, maxY, maxZ }.
local function overlaps(lo: { number }, hi: { number }, region: { number }): boolean
	for axis = 1, 3 do
		if hi[axis] <= region[axis] + TOLERANCE or lo[axis] >= region[axis + 3] - TOLERANCE then
			return false
		end
	end
	return true
end

local function slotOrigin(slot): any
	return PLOT_CFRAME * CFrame.new(slot.X, 0.5, slot.Z)
end

local function slotSize(slot): any
	return Vector3.new(slot.Size[1], slot.Size[2], slot.Size[3])
end

local function lightCount(root: any): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Light") then
			count += 1
		end
	end
	return count
end

-- Checks every visible part of a build stays inside the slot's footprint, on
-- or above the floor and not far above the slot.
local function assertInside(model: any, origin: any, size: any, label: string)
	for _, part in partsIn(model) do
		assert(part.Anchored, `{label}: {part.Name} is not anchored`)
		local lo, hi = boxIn(part, origin)
		local where = `{label}: a {part.ClassName} reaching ({lo[1]}, {lo[2]}, {lo[3]}) to ({hi[1]}, {hi[2]}, {hi[3]})`
		assert(lo[1] >= -size.X / 2 - TOLERANCE and hi[1] <= size.X / 2 + TOLERANCE, `{where} sticks out sideways`)
		assert(lo[3] >= -size.Z / 2 - TOLERANCE and hi[3] <= size.Z / 2 + TOLERANCE, `{where} sticks out front or back`)
		assert(lo[2] >= -TOLERANCE, `{where} goes below the floor`)
		assert(hi[2] <= size.Y + 4, `{where} is far above its slot`)
	end
end

local plotParts, plotLights = 0, 0

describe("theme props", function()
	it("has a model for every station and attraction that fits its slot", function()
		for _, upgrade in Balance.Upgrades do
			if upgrade.Kind ~= "Boost" then
				local builder = Props[upgrade.Id]
				assert(builder, `the theme has no model for {upgrade.Id}`)
				local slot = Layout.Slots[upgrade.Id]
				local origin, size = slotOrigin(slot), slotSize(slot)
				local model = builder(origin, size)
				expect(model.ClassName).toBe("Model")
				local anchor = model.PrimaryPart
				assert(anchor and anchor.Name == "Anchor", `{upgrade.Id} has no Anchor as its primary part`)
				assert(anchor.Size == size, `{upgrade.Id}'s Anchor is not the size of its slot`)
				local offset = origin:PointToObjectSpace(anchor.CFrame.Position) - Vector3.new(0, size.Y / 2, 0)
				assert(offset.Magnitude < 0.01, `{upgrade.Id}'s Anchor is not centred on its slot`)
				assertInside(model, origin, size, upgrade.Id)
				plotParts += #partsIn(model)
				plotLights += lightCount(model)
			end
		end
	end)

	it("adds each drawn boost inside the slot of the station it boosts", function()
		for id, builder in Props do
			local upgrade = Progression.find(Balance.Upgrades, id)
			assert(upgrade, `the theme has a model for unknown upgrade {id}`)
			if upgrade.Kind == "Boost" then
				local slot = Layout.Slots[upgrade.Target]
				local origin, size = slotOrigin(slot), slotSize(slot)
				local model = builder(origin, size)
				expect(model.PrimaryPart).toBe(nil)
				assertInside(model, origin, size, id)
				plotParts += #partsIn(model)
				plotLights += lightCount(model)
			end
		end
	end)

	it("sets up every moving part for the client", function()
		local slot = Layout.Slots.attraction_3
		local model = Props.attraction_3(slotOrigin(slot), slotSize(slot))
		local train = model:FindFirstChild("Train")
		assert(train and train:HasTag("Train"), "the ghost train has no tagged Train")
		for _, name in { "TrackCentre", "RadiusX", "RadiusZ", "LapSeconds", "Gap" } do
			assert(train:GetAttribute(name) ~= nil, `the train has no {name}`)
		end
		local cars = 0
		for _, car in train:GetChildren() do
			assert(car:IsA("Model") and car:GetAttribute("Order"), `{car.Name} is not a numbered car`)
			cars += 1
		end
		expect(cars).toBe(3)

		local floats = 0
		for _, descendant in model:GetDescendants() do
			if descendant:HasTag("Float") then
				floats += 1
				for _, name in { "FloatHeight", "FloatSeconds", "SpinSeconds", "SpinAxis" } do
					assert(descendant:GetAttribute(name) ~= nil, `{descendant.Name} has no {name}`)
				end
			end
		end
		assert(floats > 0, "nothing floats on the ghost train")
	end)
end)

describe("theme scenery", function()
	local function makePlot(cframe: any): any
		local plot = Instance.new("Part")
		plot.Name = "Plot1"
		plot.Size = Vector3.new(Layout.PlotSize, 1, Layout.PlotSize)
		plot.CFrame = cframe
		return plot
	end

	it("dresses a plot without touching its slots, buttons, gate or walkway", function()
		local plot = makePlot(PLOT_CFRAME)
		local model = Scenery.plot(plot, 1, Instance.new("Folder"))
		local floor = PLOT_CFRAME * CFrame.new(0, 0.5, 0)

		local keepOut: { { any } } = {}
		for id, slot in Layout.Slots do
			local w, h, d = slot.Size[1], slot.Size[2], slot.Size[3]
			table.insert(keepOut, { `slot {id}`, { slot.X - w / 2, 0, slot.Z - d / 2, slot.X + w / 2, h, slot.Z + d / 2 } })
		end
		local half = Layout.ButtonSize / 2
		for id, spot in Layout.Buttons do
			table.insert(keepOut, { `button {id}`, { spot.X - half, 0, spot.Z - half, spot.X + half, 6, spot.Z + half } })
		end
		local gate = Layout.Gate
		local gw, gh, gd = gate.Size[1] / 2, gate.Size[2], gate.Size[3] / 2
		table.insert(keepOut, { "gate", { gate.X - gw, 0, gate.Z - gd, gate.X + gw, gh, gate.Z + gd } })

		local edge = Layout.PlotSize / 2
		for _, part in partsIn(model) do
			assert(part.Anchored, `{part.Name} is not anchored`)
			-- Invisible parts only hold mist and wisps.
			if part.Transparency < 1 then
				local lo, hi = boxIn(part, floor)
				local where = `a {part.ClassName} at ({lo[1]}, {lo[3]})`
				assert(lo[1] >= -edge and hi[1] <= edge and lo[3] >= -edge and hi[3] <= edge, `{where} is off the plot`)
				for _, zone in keepOut do
					assert(not overlaps(lo, hi, zone[2]), `{where} is in the way of {zone[1]}`)
				end
				if part.CanCollide then
					assert(not overlaps(lo, hi, { -9, 0, -44, 7, 8, 44 }), `{where} blocks the walkway`)
				end
			end
		end
		plotParts += #partsIn(model)
		plotLights += lightCount(model)
		expect(plot.Material).toBe(roblox.Enum.Material.Grass)
	end)

	it("keeps a fully built plot within a part and light budget", function()
		-- Every plot can be fully built at once, so this is what each costs.
		print(`  a fully built plot has {plotParts} parts and {plotLights} lights`)
		assert(plotParts < 1500, `a fully built plot has {plotParts} parts`)
		assert(plotLights < 60, `a fully built plot has {plotLights} lights`)
	end)

	it("dresses the world around the plots without building on them", function()
		-- The same map PlotService generates.
		local plots = {}
		local count, spacing = Layout.PlotCount, Layout.PlotSpacing
		for i = 1, count do
			table.insert(plots, makePlot(CFrame.new((i - (count + 1) / 2) * spacing, 0, 0)))
		end
		local plaza = Instance.new("Part")
		plaza.Size = Vector3.new(count * spacing, 1, 40)
		plaza.CFrame = CFrame.new(0, 0, Layout.PlotSize / 2 + 20)
		local spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.CFrame = CFrame.new(0, 1, Layout.PlotSize / 2 + 20)

		local folder = Instance.new("Folder")
		local fills = Scenery.world({ Plots = plots, Plaza = plaza, Spawns = { spawn } }, folder)
		local parts = partsIn(folder)
		print(`  the world has {#parts} parts and {lightCount(folder)} lights`)
		assert(#parts < 9000, `the world has {#parts} parts`)

		local half = Layout.PlotSize / 2
		local spawnAt = spawn.CFrame.Position
		for _, part in parts do
			assert(part.Anchored, `{part.Name} is not anchored`)
			local lo, hi = boxIn(part, CFrame.new())
			if part.Transparency < 1 and lo[2] < 20 then
				for _, plot in plots do
					local at = plot.CFrame.Position
					local zone = { at.X - half, -100, at.Z - half, at.X + half, 100, at.Z + half }
					assert(not overlaps(lo, hi, zone), `a {part.ClassName} at ({lo[1]}, {lo[3]}) is on {plot.Name}`)
				end
				local zone = { spawnAt.X - 6, -100, spawnAt.Z - 6, spawnAt.X + 6, 100, spawnAt.Z + 6 }
				assert(not overlaps(lo, hi, zone), `a {part.ClassName} at ({lo[1]}, {lo[3]}) is on the spawn`)
			end
		end

		assert(#fills > 0, "no terrain to fill")
		for _, fill in fills do
			assert(roblox.Enum.Material[fill.Material], `unknown terrain material {fill.Material}`)
			assert(fill.Shape == "Block" or fill.Shape == "Ball" or fill.Shape == "Cylinder", `unknown fill {fill.Shape}`)
		end
	end)
end)

describe("theme look", function()
	local function convert(value: any): any
		if type(value) == "string" and string.sub(value, 1, 1) == "#" then
			return roblox.Color3.fromHex(value)
		end
		return value
	end

	it("only sets lighting and effect properties that exist", function()
		local lighting = Instance.new("Lighting")
		for name, value in Theme.Look.Lighting do
			lighting[name] = convert(value)
		end
		for _, className in { "Atmosphere", "Sky", "BloomEffect", "ColorCorrectionEffect" } do
			local effect = Instance.new(className)
			for name, value in Theme.Look[className] do
				effect[name] = convert(value)
			end
		end
		for name, hex in Theme.Look.Terrain do
			assert(roblox.Enum.Material[name], `unknown terrain material {name}`)
			assert(string.match(hex, "^#%x%x%x%x%x%x$"), `terrain colour {name} must be #RRGGBB`)
		end
	end)

	it("gives every sound an asset id or nothing, and a volume", function()
		for _, name in { "Music", "Ambience", "Claim", "Purchase", "Build", "Payout" } do
			local sound = Theme.Sounds[name]
			assert(sound, `the theme has no {name} sound`)
			assert(sound.Id == "" or string.match(sound.Id, "^rbxassetid://%d+$"), `{name} must be rbxassetid://<number> or ""`)
			assert(sound.Volume >= 0 and sound.Volume <= 1, `{name} volume must be 0 to 1`)
		end
	end)
end)

return nil
