-- Builds the theme pack's props and scenery with Lune's Roblox library and
-- checks they fit: every model inside its slot, plot dressing clear of the
-- slots, buttons, gate and walkway, and the world clear of the plots. Building
-- them also checks every property they set exists and takes that type.

local TestKit = require("./TestKit")
local Loader = require("./RobloxLoader")
local Map = require("./Map")
local Balance = require("../src/shared/Config/Balance")
local Layout = require("../src/shared/Config/Layout")
local Progression = require("../src/shared/Progression")
local Festival = require("../src/shared/Festival")
local Theme = require("../src/shared/Themes/MoonlightFestival")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local roblox = Loader.roblox
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local Props = Loader.require("src/shared/Themes/MoonlightFestival/Props")
local Scenery = Loader.require("src/shared/Themes/MoonlightFestival/Scenery")
local Crowd = Loader.require("src/shared/Themes/MoonlightFestival/Crowd")
local ActivityLook = Loader.require("src/shared/Themes/MoonlightFestival/Activity")
local FestivalLook = Loader.require("src/shared/Themes/MoonlightFestival/Festival")
local FestivalConfig = require("../src/shared/Config/Festival")
local ParadeLook = Loader.require("src/shared/Themes/MoonlightFestival/Parade")
local ParadeConfig = require("../src/shared/Config/Parade")
local ParadeRules = require("../src/shared/Parade")
local Kit = Loader.require("src/shared/Kit")

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
				local corner =
					frame:PointToObjectSpace(part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
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

-- Whether every number in a part's CFrame is a number. A CFrame turned to
-- look at its own position has none, and the part vanishes in Roblox.
local function finite(part: any): boolean
	for _, value in { part.CFrame:GetComponents() } do
		if value ~= value or math.abs(value) == math.huge then
			return false
		end
	end
	return true
end

local function assertFinite(root: any, label: string)
	for _, part in partsIn(root) do
		assert(finite(part), `{label}: a {part.ClassName} near {part.CFrame.Position} has no proper direction`)
	end
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

-- What each client draws many of, so each must be small and cheap.
local function checkLight(model: any, what: string, maxParts: number)
	local parts = partsIn(model)
	assert(#parts > 0 and #parts <= maxParts, `{what} has {#parts} parts`)
	for _, part in parts do
		assert(part.Anchored, `{what}: {part.Name} is not anchored`)
		assert(not part.CanCollide and not part.CanTouch and not part.CanQuery, `{what}: {part.Name} can be hit`)
		assert(not part.CastShadow, `{what}: {part.Name} casts a shadow`)
	end
	assert(model.WorldPivot == CFrame.new(), `{what} isn't pivoted on its origin`)
end

-- Why a part isn't inside a slot's footprint, on or above the floor and not
-- far above the slot, or nil if it is.
local function outside(part: any, origin: any, size: any): string?
	local lo, hi = boxIn(part, origin)
	if lo[1] < -size.X / 2 - TOLERANCE or hi[1] > size.X / 2 + TOLERANCE then
		return "sticks out sideways"
	elseif lo[3] < -size.Z / 2 - TOLERANCE or hi[3] > size.Z / 2 + TOLERANCE then
		return "sticks out front or back"
	elseif lo[2] < -TOLERANCE then
		return "goes below the floor"
	elseif hi[2] > size.Y + 4 then
		return "is far above its slot"
	end
	return nil
end

local function assertPlaced(part: any, origin: any, problem: string?, label: string)
	assert(part.Anchored, `{label}: {part.Name} is not anchored`)
	if problem then
		local lo, hi = boxIn(part, origin)
		assert(
			false,
			`{label}: a {part.ClassName} reaching ({lo[1]}, {lo[2]}, {lo[3]}) to ({hi[1]}, {hi[2]}, {hi[3]}) {problem}`
		)
	end
end

-- Checks every part of a build stays inside the slot.
local function assertInside(model: any, origin: any, size: any, label: string)
	assertFinite(model, label)
	for _, part in partsIn(model) do
		assertPlaced(part, origin, outside(part, origin, size), label)
	end
end

local plotParts, plotLights = 0, 0

describe("theme props", function()
	it("has a model for every station and attraction that fits its slot", function()
		for _, upgrade in Balance.Upgrades do
			if not upgrade.Building then
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

	it("adds every upgrade to the building it improves, inside its slot or yard", function()
		-- Parts and lights for each building's shared upgrades, and for each of
		-- its paths. A plot only ever has one path per building built, so the
		-- budget counts the heaviest. A path tier's model replaces the tier
		-- before, so only the last tier of a path counts.
		local shared: { [string]: { number } } = {}
		local paths: { [string]: { [string]: { number } } } = {}
		local function tally(totals: { [string]: { number } }, key: string, model: any)
			local counts = totals[key] or { 0, 0 }
			counts[1] += #partsIn(model)
			counts[2] += lightCount(model)
			totals[key] = counts
		end
		local tiers: { [string]: any } = {}

		for _, upgrade in Balance.Upgrades do
			local id, building = upgrade.Id, upgrade.Building
			if building then
				local builder = Props[id]
				assert(builder, `the theme draws nothing for {id}, so buying it changes nothing you can see`)
				local slot = Layout.Slots[building]
				local origin, size = slotOrigin(slot), slotSize(slot)
				local yard = slot.Yard and slotOrigin(slot.Yard)
				local model = builder(origin, size, yard)
				expect(model.ClassName).toBe("Model")
				expect(model.PrimaryPart).toBe(nil)
				assertFinite(model, id)
				for _, part in partsIn(model) do
					local problem = outside(part, origin, size)
					if problem and yard and outside(part, yard, slotSize(slot.Yard)) == nil then
						problem = nil
					end
					assertPlaced(part, origin, problem, id)
				end
				if upgrade.Path then
					local prefix, tier = string.match(id, "^(.*)_(%d+)$")
					local replaces = model:GetAttribute("Replaces")
					if tonumber(tier) == 1 then
						expect(replaces).toBe(nil)
					else
						-- The whole path so far, with more added.
						local before = `{prefix}_{tonumber(tier) - 1}`
						expect(replaces).toBe(before)
						local had = #tiers[before]:GetDescendants()
						assert(#model:GetDescendants() > had, `{id} adds nothing to {before}`)
						-- What it keeps stays put while the rest builds up.
						local kept = 0
						for _, part in partsIn(model) do
							kept += if part:GetAttribute("Kept") then 1 else 0
						end
						assert(kept > 0 and kept <= #partsIn(tiers[before]), `{id} keeps {kept} parts of {before}`)
					end
					tiers[id] = model
					if not Progression.find(Balance.Upgrades, `{prefix}_{tonumber(tier) + 1}`) then
						paths[building] = paths[building] or {}
						tally(paths[building], upgrade.Path, model)
					end
				else
					tally(shared, building, model)
				end
			end
		end
		for id in Props do
			assert(Progression.find(Balance.Upgrades, id), `the theme has a model for unknown upgrade {id}`)
		end

		for _, counts in shared do
			plotParts += counts[1]
			plotLights += counts[2]
		end
		for _, byPath in paths do
			local parts, lights = 0, 0
			for _, counts in byPath do
				parts, lights = math.max(parts, counts[1]), math.max(lights, counts[2])
			end
			plotParts += parts
			plotLights += lights
		end
	end)

	it("builds Ghost Catcher's booth inside its place, and wisps nobody can bump into", function()
		local spec = Layout.Activity
		local origin, size = slotOrigin(spec), slotSize(spec)
		local booth = ActivityLook.booth(origin, size)
		assertInside(booth, origin, size, "the activity booth")
		local status = booth:FindFirstChild("Status", true)
		assert(status and status:FindFirstChildWhichIsA("SurfaceGui"), "the booth has no Status board")
		plotParts += #partsIn(booth)
		plotLights += lightCount(booth)

		local wisp = ActivityLook.wisp()
		assert(wisp.PrimaryPart, "a wisp has no body")
		assertFinite(wisp, "a wisp")
		for _, part in partsIn(wisp) do
			assert(not part.CanCollide and not part.CanTouch and not part.CanQuery, `a wisp's {part.Name} can be hit`)
		end
	end)

	it("builds every festival decoration small enough to fit its spot", function()
		-- Every plot has a decoration in each spot, so the budget counts the
		-- heaviest in all of them.
		local size = Layout.DecorSize
		local heaviest, brightest = 0, 0
		for _, choice in FestivalConfig.Decor do
			assert(FestivalLook.Decor[choice.Id], `the theme has no model for decoration {choice.Id}`)
			for spot, place in Layout.Decor do
				local yaw = math.atan2(-place.X, -place.Z)
				local base = PLOT_CFRAME * CFrame.new(place.X, 0.5, place.Z) * CFrame.Angles(0, yaw, 0)
				local model = FestivalLook.decor(choice.Id, base, spot)
				expect(model.Name).toBe(choice.Id)
				assertFinite(model, choice.Id)
				for _, part in partsIn(model) do
					assertPlaced(
						part,
						base,
						outside(part, base, Vector3.new(size, Layout.DecorHeight - 4, size)),
						choice.Id
					)
				end
				local parts, lights = #partsIn(model), lightCount(model)
				assert(parts <= FestivalLook.MaxDecorParts, `{choice.Id} has {parts} parts`)
				assert(lights <= FestivalLook.MaxDecorLights, `{choice.Id} has {lights} lights`)
				heaviest, brightest = math.max(heaviest, parts), math.max(brightest, lights)
			end
		end
		for id in FestivalLook.Decor do
			assert(Festival.find(FestivalConfig.Decor, id), `the theme has a model for unknown decoration {id}`)
		end
		plotParts += heaviest * #Layout.Decor
		plotLights += brightest * #Layout.Decor
	end)

	it("builds the festival board, the trophy shelf and the name sign in their places", function()
		local board = FestivalLook.board(slotOrigin(Layout.Board), slotSize(Layout.Board))
		assert(board.PrimaryPart, "the board has no Anchor for its prompt")
		assertInside(board, slotOrigin(Layout.Board), slotSize(Layout.Board), "the festival board")

		-- The fullest the shelf gets: a cup for every building's path and a
		-- plaque for every count.
		local cups = {}
		for _ in Layout.Slots do
			table.insert(cups, roblox.Color3.new(1, 0.8, 0.2))
		end
		local shelf = FestivalLook.shelf(slotOrigin(Layout.Shelf), slotSize(Layout.Shelf), {
			Paths = cups,
			Best = 12,
			KOs = 40,
			Parades = 9,
		})
		assertInside(shelf, slotOrigin(Layout.Shelf), slotSize(Layout.Shelf), "the trophy shelf")

		local floor = PLOT_CFRAME * CFrame.new(0, 0.5, 0)
		local holder = Instance.new("Folder")
		local sign = FestivalLook.nameSign(holder, floor, "The Whispering Broomstick Spooktacular")
		local lo, hi = boxIn(sign, floor)
		local gate = Layout.Gate
		assert(lo[2] > gate.Size[2], "the name sign hangs in the gateway")
		assert(
			math.abs(lo[1]) < gate.Size[1] and math.abs(hi[1]) < gate.Size[1],
			"the name sign is wider than the arch"
		)

		for _, model in { board, shelf, holder } do
			plotParts += #partsIn(model)
			plotLights += lightCount(model)
		end
	end)

	it("gives every path stops visitors can use, and moving parts the client can drive", function()
		local poses = { Sit = true, Jump = true, Cheer = true }
		local carries = {}
		for _, name in Crowd.Carries do
			carries[name] = true
		end
		local half = Layout.PlotSize / 2
		local stationTrain =
			Props.attraction_3(slotOrigin(Layout.Slots.attraction_3), slotSize(Layout.Slots.attraction_3))
				:FindFirstChild("Train")
		for _, upgrade in Balance.Upgrades do
			if upgrade.Path then
				local slot = Layout.Slots[upgrade.Building]
				local model = Props[upgrade.Id](slotOrigin(slot), slotSize(slot), slot.Yard and slotOrigin(slot.Yard))
				for _, descendant in model:GetDescendants() do
					local where = `{upgrade.Id}: {descendant.Name}`
					if descendant:HasTag("VisitorStop") then
						assert(
							descendant:IsA("Attachment") and descendant.Parent:IsA("BasePart"),
							`{where} isn't on a part`
						)
						assert((descendant:GetAttribute("Pause") or 0) > 0, `{where} has no pause`)
						local pose, carry = descendant:GetAttribute("Pose"), descendant:GetAttribute("Carry")
						assert(pose == nil or poses[pose], `{where} has an unknown pose {pose}`)
						assert(carry == nil or carries[carry], `{where} gives an unknown {carry}`)
						local chance = descendant:GetAttribute("Chance") or 0.6
						assert(chance > 0 and chance <= 1, `{where} has a chance of {chance}`)
						-- On the plot, on the floor or on something low.
						local at = PLOT_CFRAME:PointToObjectSpace(descendant.Parent.CFrame * descendant.CFrame.Position)
						assert(math.abs(at.X) < half and math.abs(at.Z) < half, `{where} is off the plot`)
						assert(at.Y >= 0.4 and at.Y <= 2, `{where} is {at.Y} studs up`)
					elseif descendant:HasTag("Patrol") then
						assert(
							descendant:GetAttribute("PatrolOffset") and descendant:GetAttribute("PatrolSeconds"),
							`{where} can't patrol`
						)
					elseif descendant:HasTag("Pop") then
						assert(
							descendant:GetAttribute("PopHeight") and descendant:GetAttribute("PopSeconds"),
							`{where} can't pop`
						)
					elseif descendant:HasTag("Train") then
						-- Extra cars run on the station's own track, after its cars.
						for _, name in { "TrackCentre", "RadiusX", "RadiusZ", "LapSeconds", "Gap" } do
							local mine, station = descendant:GetAttribute(name), stationTrain:GetAttribute(name)
							local same = if typeof(mine) == "CFrame"
								then (mine.Position - station.Position).Magnitude < 0.01
								else mine == station
							assert(same, `{where}'s {name} doesn't match the ghost train's`)
						end
						for _, car in descendant:GetChildren() do
							assert((car:GetAttribute("Order") or 0) > 3, `{where} has a car out of order`)
						end
					end
				end
			end
		end
		for _, name in Crowd.Carries do
			local model = Crowd.carry(name)
			checkLight(model, `carried {name}`, 3)
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
	it("dresses a plot without touching its slots, buttons, gate or walkway", function()
		local plot = Map.plot(PLOT_CFRAME)
		local model = Scenery.plot(plot, 1, Instance.new("Folder"))
		local floor = PLOT_CFRAME * CFrame.new(0, 0.5, 0)
		assertFinite(model, "plot dressing")

		local keepOut: { { any } } = {}
		for id, slot in Layout.Slots do
			for _, box in { slot, slot.Yard } do
				local w, h, d = box.Size[1], box.Size[2], box.Size[3]
				table.insert(
					keepOut,
					{ `slot {id}`, { box.X - w / 2, 0, box.Z - d / 2, box.X + w / 2, h, box.Z + d / 2 } }
				)
			end
		end
		local half = Layout.ButtonSize / 2
		for building, spots in Layout.Buttons do
			local list = { Build = spots.Build, Upgrades = spots.Upgrades }
			for path, spot in spots.Paths or {} do
				list[path] = spot
			end
			for name, spot in list do
				local zone = { spot.X - half, 0, spot.Z - half, spot.X + half, 6, spot.Z + half }
				table.insert(keepOut, { `button {building} {name}`, zone })
			end
		end
		local gate = Layout.Gate
		local gw, gh, gd = gate.Size[1] / 2, gate.Size[2], gate.Size[3] / 2
		table.insert(keepOut, { "gate", { gate.X - gw, 0, gate.Z - gd, gate.X + gw, gh, gate.Z + gd } })
		local booth = Layout.Activity
		local bw, bh, bd = booth.Size[1] / 2, booth.Size[2], booth.Size[3] / 2
		table.insert(keepOut, { "activity booth", { booth.X - bw, 0, booth.Z - bd, booth.X + bw, bh, booth.Z + bd } })
		for name, place in { ["festival board"] = Layout.Board, ["trophy shelf"] = Layout.Shelf } do
			local w, h, d = place.Size[1] / 2, place.Size[2], place.Size[3] / 2
			table.insert(keepOut, { name, { place.X - w, 0, place.Z - d, place.X + w, h, place.Z + d } })
		end
		local decorHalf = Layout.DecorSize / 2
		for spot, place in Layout.Decor do
			table.insert(keepOut, {
				`decoration spot {spot}`,
				{
					place.X - decorHalf,
					0,
					place.Z - decorHalf,
					place.X + decorHalf,
					Layout.DecorHeight,
					place.Z + decorHalf,
				},
			})
		end
		local start = booth.Pad
		-- It stands on the walkway, so only what's over the walkway counts.
		table.insert(
			keepOut,
			{ "activity pad", { start.X - half, 0.1, start.Z - half, start.X + half, 6, start.Z + half } }
		)

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
		-- Every plot can be fully built at once, on its heaviest paths, so this
		-- is the most each costs.
		print(`  a fully built plot has {plotParts} parts and {plotLights} lights`)
		assert(plotParts < 1500, `a fully built plot has {plotParts} parts`)
		assert(plotLights < 60, `a fully built plot has {plotLights} lights`)
	end)

	it("dresses the world around the plots without building on them", function()
		-- The same map PlotService generates.
		local map = Map.build()
		local plots, plaza, spawn = map.Plots, map.Plaza, map.Spawn

		local folder = Instance.new("Folder")
		local fills = Scenery.world({ Plots = plots, Plaza = plaza, Spawns = { spawn } }, folder)
		local parts = partsIn(folder)
		print(`  the world has {#parts} parts and {lightCount(folder)} lights`)
		assertFinite(folder, "the world")
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
			assert(
				fill.Shape == "Block" or fill.Shape == "Ball" or fill.Shape == "Cylinder",
				`unknown fill {fill.Shape}`
			)
		end

		-- Terrain left under a floor shows through it and buries its buttons,
		-- so the last fills clear the ground under every plot and the plaza.
		local floors = table.clone(plots)
		table.insert(floors, plaza)
		local courtyardFloor = folder:FindFirstChild("CourtyardFloor", true)
		assert(courtyardFloor, "the courtyard has no floor")
		table.insert(floors, courtyardFloor)
		for _, floor in floors do
			local cleared = false
			for index, fill in fills do
				if fill.Shape == "Block" and fill.Material == "Air" then
					local lo, hi = boxIn({ CFrame = fill.CFrame, Size = fill.Size }, CFrame.new())
					local at, half = floor.CFrame.Position, floor.Size / 2
					cleared = cleared
						or (
							lo[1] <= at.X - half.X + TOLERANCE
							and hi[1] >= at.X + half.X - TOLERANCE
							and lo[3] <= at.Z - half.Z + TOLERANCE
							and hi[3] >= at.Z + half.Z - TOLERANCE
							and lo[2] <= -16
							and hi[2] >= at.Y + half.Y + 2
						)
					-- Nothing fills the ground back in afterwards.
					for later = index + 1, #fills do
						assert(fills[later].Material == "Air", "terrain is filled after the floors are cleared")
					end
				end
			end
			assert(cleared, `the ground under {floor.Name} is not cleared`)
		end
	end)

	-- Whether the segment from a to b passes through a part's box.
	local function crosses(part: any, a: any, b: any): boolean
		local half = part.Size / 2
		local from, to = part.CFrame:PointToObjectSpace(a), part.CFrame:PointToObjectSpace(b)
		local enter, leave = 0, 1
		for _, axis in { "X", "Y", "Z" } do
			local start, delta, extent = from[axis], to[axis] - from[axis], half[axis]
			if math.abs(delta) < 1e-9 then
				if math.abs(start) > extent then
					return false
				end
			else
				local near, far = (-extent - start) / delta, (extent - start) / delta
				if near > far then
					near, far = far, near
				end
				enter, leave = math.max(enter, near), math.min(leave, far)
				if enter > leave then
					return false
				end
			end
		end
		return true
	end

	it("shows the landmark and the nearest gates from the spawn", function()
		local map = Map.build()
		local folder = Instance.new("Folder")
		Scenery.world({ Plots = map.Plots, Plaza = map.Plaza, Spawns = { map.Spawn } }, folder)
		local wheel = folder:FindFirstChild("MoonlightWheel", true)
		assert(wheel and wheel:HasTag("Wheel"), "the courtyard has no tagged wheel")
		local centre = wheel:GetAttribute("Centre")
		assert(centre and wheel:GetAttribute("Radius") and wheel:GetAttribute("LapSeconds"), "the wheel can't turn")
		local rim = wheel:FindFirstChild("Rim")
		assert(rim and (rim.WorldPivot.Position - centre.Position).Magnitude < 0.01, "the rim doesn't turn on the hub")
		local seats = 0
		for _, child in wheel:GetChildren() do
			if child:GetAttribute("Seat") ~= nil then
				seats += 1
			end
		end
		expect(seats).toBe(8)

		-- The wheel stands in the gap between the middle two plots.
		local half = Layout.PlotSize / 2
		local left, right = Layout.plotX(Layout.PlotCount / 2) + half, Layout.plotX(Layout.PlotCount / 2 + 1) - half
		for _, part in partsIn(wheel) do
			local lo, hi = boxIn(part, CFrame.new())
			assert(lo[1] > left and hi[1] < right, `the wheel reaches over a plot at x = {lo[1]} to {hi[1]}`)
		end

		-- A player's eyes on the spawn see the hub and the two nearest gates,
		-- past anything solid to look at. The gates stand where PlotService
		-- puts them.
		local spawnTop = map.Spawn.CFrame.Position + Vector3.new(0, map.Spawn.Size.Y / 2, 0)
		local eye = spawnTop + Vector3.new(0, 5, 0)
		local targets = { { "the wheel's hub", centre.Position, wheel } }
		for _, index in { Layout.PlotCount / 2, Layout.PlotCount / 2 + 1 } do
			local gate = map.Plots[index].CFrame
				* CFrame.new(Layout.Gate.X, 0.5 + Layout.Gate.Size[2] / 2, Layout.Gate.Z)
			table.insert(targets, { `the gate of Plot{index}`, gate.Position, nil })
		end
		for _, target in targets do
			for _, part in partsIn(folder) do
				local skip = part.Transparency > 0.5 or (target[3] and part:IsDescendantOf(target[3]))
				if not skip and crosses(part, eye, target[2]) then
					local at = part.CFrame.Position
					error(`a {part.ClassName} at ({at.X}, {at.Y}, {at.Z}) hides {target[1]} from the spawn`)
				end
			end
		end
	end)
end)

describe("theme crowd", function()
	it("dresses every kind of visitor in a small costume that faces forward", function()
		local random = Kit.random(7)
		for kind = 1, Crowd.KindCount do
			for _ = 1, 4 do
				local model = Crowd.visitor(random, kind)
				local what = `visitor kind {kind}`
				checkLight(model, what, 20)
				local gait = model:GetAttribute("Gait")
				assert(gait == "Hop" or gait == "Float", `{what} has gait {gait}`)
				local faceZ = math.huge
				for _, part in partsIn(model) do
					local lo, hi = boxIn(part, CFrame.new())
					assert(lo[1] >= -1.6 and hi[1] <= 1.6 and lo[3] >= -1.6 and hi[3] <= 1.6, `{what} is too wide`)
					assert(lo[2] >= -TOLERANCE and hi[2] <= 4.5, `{what} is too tall or below its feet`)
					if part.Color == Crowd.FaceColor or part.Material == roblox.Enum.Material.Neon then
						faceZ = math.min(faceZ, (lo[3] + hi[3]) / 2)
					end
				end
				-- Its face (eyes, or glowing features) is on the front, -Z.
				assert(faceZ < -0.3, `{what} doesn't face forward`)
			end
		end
	end)

	it("makes a small model for every good", function()
		for item in Balance.Items do
			local model = Crowd.good(item)
			checkLight(model, item, 6)
			for _, part in partsIn(model) do
				local lo, hi = boxIn(part, CFrame.new())
				for axis = 1, 3 do
					assert(lo[axis] >= -1 and hi[axis] <= 1, `{item} is too big`)
				end
			end
		end
	end)
end)

describe("theme parade", function()
	-- How far the floats reach from their middle across the ground, and how
	-- tall they stand.
	local floatReach, floatHeight = 0, 0

	it("builds small floats, marchers and lanterns nobody can bump into", function()
		for index = 1, ParadeLook.FloatCount do
			local model = ParadeLook.float(index)
			local what = `float {index}`
			checkLight(model, what, 40)
			expect(lightCount(model)).toBe(0)
			for _, part in partsIn(model) do
				local lo, hi = boxIn(part, CFrame.new())
				assert(lo[2] >= -TOLERANCE, `{what} goes below the ground`)
				for _, x in { lo[1], hi[1] } do
					for _, z in { lo[3], hi[3] } do
						floatReach = math.max(floatReach, math.sqrt(x * x + z * z))
					end
				end
				floatHeight = math.max(floatHeight, hi[2])
			end
		end
		print(
			`  floats reach {math.floor(floatReach * 10 + 0.5) / 10} studs and stand {math.floor(floatHeight * 10 + 0.5) / 10} tall`
		)
		assert(floatReach <= 4.5, `a float reaches {floatReach} studs from its middle`)
		assert(floatHeight <= 9, `a float stands {floatHeight} studs tall`)

		local marcher = ParadeLook.marcher()
		checkLight(marcher, "a marcher", 16)
		expect(lightCount(marcher)).toBe(0)

		-- One light each, since a few are out at a time.
		local lantern = ParadeLook.lantern()
		local parts = partsIn(lantern)
		assert(#parts <= 6, `a lantern has {#parts} parts`)
		expect(lightCount(lantern)).toBe(1)
		assert(lantern.PrimaryPart, "a lantern has no body")
		for _, part in parts do
			assert(
				not part.CanCollide and not part.CanTouch and not part.CanQuery,
				`a lantern's {part.Name} can be hit`
			)
			local lo, hi = boxIn(part, CFrame.new())
			for axis = 1, 3 do
				assert(lo[axis] >= -2 and hi[axis] <= 2, "a lantern is too big")
			end
		end
	end)

	it("leaves the parade a clear loop round the wheel, on the courtyard floor", function()
		local map = Map.build()
		local folder = Instance.new("Folder")
		Scenery.world({ Plots = map.Plots, Plaza = map.Plaza, Spawns = { map.Spawn } }, folder)
		local courtyard = folder:FindFirstChild("Courtyard", true)
		assert(courtyard and courtyard:HasTag("ParadeRoute"), "the courtyard has no parade route")
		local centre = courtyard:GetAttribute("RouteCentre")
		local route =
			{ RadiusX = courtyard:GetAttribute("RouteRadiusX"), RadiusZ = courtyard:GetAttribute("RouteRadiusZ") }
		assert(centre and route.RadiusX and route.RadiusZ, "the parade route is missing a size")
		local floor = courtyard:FindFirstChild("CourtyardFloor")
		local floorLo, floorHi = boxIn(floor, centre)

		-- Where the floats go, and the lanterns either side of them.
		local points = {}
		for step = 0, 359 do
			local angle = math.rad(step)
			for _, offset in { -ParadeConfig.Spread, 0, ParadeConfig.Spread } do
				local x, _, z = ParadeRules.point(route, angle, offset, 0)
				table.insert(points, { x, z, offset == 0 })
				local reach = if offset == 0 then floatReach else 1
				assert(
					x - reach >= floorLo[1]
						and x + reach <= floorHi[1]
						and z - reach >= floorLo[3]
						and z + reach <= floorHi[3],
					`the parade leaves the courtyard floor at ({x}, {z})`
				)
			end
		end

		-- How far a point is from a box, across the ground.
		local function away(lo: { number }, hi: { number }, x: number, z: number): number
			local dx = math.max(lo[1] - x, 0, x - hi[1])
			local dz = math.max(lo[3] - z, 0, z - hi[3])
			return math.sqrt(dx * dx + dz * dz)
		end

		local lanternLo, lanternHi = ParadeConfig.Height - 1.2, ParadeConfig.Height + 1.6
		for _, part in partsIn(courtyard) do
			if part ~= floor and part.Transparency < 1 then
				local lo, hi = boxIn(part, centre)
				-- Floats pass nothing they'd go through, and lanterns hang
				-- clear of anything at their height so they can be reached.
				local underFloats = lo[2] < floatHeight and hi[2] > 0.2
				local byLanterns = lo[2] < lanternHi and hi[2] > lanternLo
				for _, point in points do
					local distance = away(lo, hi, point[1], point[2])
					if point[3] and underFloats then
						assert(
							distance >= floatReach,
							`a {part.ClassName} at ({lo[1]}, {lo[3]}) is in the parade's way at ({point[1]}, {point[2]})`
						)
					end
					if byLanterns then
						assert(
							distance >= 1,
							`a {part.ClassName} at ({lo[1]}, {lo[3]}) is in the way of lanterns at ({point[1]}, {point[2]})`
						)
					end
				end
			end
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
		for _, name in { "Music", "Music2", "Ambience", "Claim", "Purchase", "Build", "Payout", "Deny" } do
			assert(Theme.Sounds[name], `the theme has no {name} sound`)
		end
		for name, sound in Theme.Sounds do
			assert(
				sound.Id == "" or string.match(sound.Id, "^rbxassetid://%d+$"),
				`{name} must be rbxassetid://<number> or ""`
			)
			assert(sound.Volume >= 0 and sound.Volume <= 1, `{name} volume must be 0 to 1`)
			assert(
				sound.Fallback == nil or string.match(sound.Fallback, "^rbxasset://sounds/[%w_]+%.%w+$"),
				`{name} falls back to rbxasset://sounds/<file>, one of Roblox's own sounds`
			)
		end
	end)
end)

return nil
