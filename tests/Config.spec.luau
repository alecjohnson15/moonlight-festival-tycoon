-- Keeps the balance, layout, theme and catalog files in step with each other,
-- so a theme swap or a new upgrade can't ship half-configured.

local fs = require("@lune/fs")

local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Catalog = require("../src/shared/Config/Catalog")
local Layout = require("../src/shared/Config/Layout")
local Theme = require("../src/shared/Themes/MoonlightFestival")
local Progression = require("../src/shared/Progression")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("theme pack", function()
	it("names every upgrade, and only real upgrades", function()
		for _, upgrade in Balance.Upgrades do
			local entry = Theme.Upgrades[upgrade.Id]
			assert(entry and entry.DisplayName, `theme has no entry for {upgrade.Id}`)
			assert(string.match(entry.Color, "^#%x%x%x%x%x%x$"), `{upgrade.Id} colour must be #RRGGBB`)
		end
		for id in Theme.Upgrades do
			assert(Progression.find(Balance.Upgrades, id), `theme names unknown upgrade {id}`)
		end
	end)

	it("names every path of every building, and only real ones", function()
		local paths = Progression.paths(Balance.Upgrades)
		for building, byPath in paths do
			for path in byPath do
				local entry = Theme.Paths[building] and Theme.Paths[building][path]
				assert(entry and entry.DisplayName and entry.Blurb, `theme has no entry for {building} path {path}`)
				assert(string.match(entry.Color, "^#%x%x%x%x%x%x$"), `{building} path {path} colour must be #RRGGBB`)
			end
		end
		for building, byPath in Theme.Paths do
			for path in byPath do
				assert(paths[building] and paths[building][path], `theme names unknown path {building} {path}`)
			end
		end
	end)

	it("names every good in the production chain, and only real ones", function()
		for item in Balance.Items do
			local entry = Theme.Items[item]
			assert(entry and entry.DisplayName, `theme has no entry for item {item}`)
			assert(string.match(entry.Color, "^#%x%x%x%x%x%x$"), `item {item} colour must be #RRGGBB`)
		end
		for item in Theme.Items do
			assert(Balance.Items[item], `theme names unknown item {item}`)
		end
	end)

	it("gives visitors at least one colour", function()
		assert(#Theme.VisitorColors > 0, "no visitor colours")
		for _, color in Theme.VisitorColors do
			assert(string.match(color, "^#%x%x%x%x%x%x$"), `visitor colour {color} must be #RRGGBB`)
		end
	end)

	it("has every string the code asks for", function()
		-- Scans the source for Theme.Strings.<Name> so a new string can't be
		-- forgotten in a theme pack.
		local function scan(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					scan(path)
				elseif string.match(name, "%.luau$") then
					for key in string.gmatch(fs.readFile(path), "[Ss]trings%.(%u%w*)") do
						assert(Theme.Strings[key], `{path} uses Strings.{key}, which the theme lacks`)
					end
				end
			end
		end
		scan("src")
	end)
end)

-- Where an upgrade's buy button goes: a building's own spot, its shared
-- upgrades' spot, or its path's spot. PlotService looks them up the same way.
local function spotFor(upgrade): { X: number, Z: number }?
	local spots = Layout.Buttons[upgrade.Building or upgrade.Id]
	if not spots then
		return nil
	elseif not upgrade.Building then
		return spots.Build
	elseif upgrade.Path then
		return spots.Paths and spots.Paths[upgrade.Path]
	end
	return spots.Upgrades
end

-- Every buy button spot as { name, spot }.
local function allSpots(): { { any } }
	local result = {}
	for building, spots in Layout.Buttons do
		table.insert(result, { `{building} build`, spots.Build })
		table.insert(result, { `{building} upgrades`, spots.Upgrades })
		for path, spot in spots.Paths or {} do
			table.insert(result, { `{building} path {path}`, spot })
		end
	end
	return result
end

describe("layout", function()
	it("has a slot for every building, and none for anything else", function()
		for _, upgrade in Balance.Upgrades do
			if not upgrade.Building then
				assert(Layout.Slots[upgrade.Id], `no layout slot for {upgrade.Id}`)
			end
		end
		for id in Layout.Slots do
			local upgrade = Progression.find(Balance.Upgrades, id)
			assert(upgrade and not upgrade.Building, `layout slot {id} is not a building`)
		end
	end)

	it("keeps every slot inside the plot", function()
		local half = Layout.PlotSize / 2
		for id, slot in Layout.Slots do
			local width, depth = slot.Size[1], slot.Size[3]
			assert(math.abs(slot.X) + width / 2 <= half, `{id} sticks out of the plot sideways`)
			assert(math.abs(slot.Z) + depth / 2 <= half, `{id} sticks out of the plot front or back`)
		end
	end)

	it("has a buy button for every upgrade, and no spot nothing uses", function()
		local used = {}
		for _, upgrade in Balance.Upgrades do
			local spot = spotFor(upgrade)
			assert(spot, `no buy button for {upgrade.Id}`)
			used[spot] = true
		end
		for _, entry in allSpots() do
			assert(entry[2] and used[entry[2]], `buy button spot {entry[1]} is not used by any upgrade`)
		end
	end)

	it("keeps buttons, the gate and every slot on the plot and clear of each other", function()
		-- Footprints as { name, x, z, width, depth }.
		local footprints = {}
		for id, slot in Layout.Slots do
			table.insert(footprints, { `slot {id}`, slot.X, slot.Z, slot.Size[1], slot.Size[3] })
		end
		local gate = Layout.Gate
		table.insert(footprints, { "gate", gate.X, gate.Z, gate.Size[1], gate.Size[3] })
		for _, entry in allSpots() do
			local spot = entry[2]
			table.insert(footprints, { `button {entry[1]}`, spot.X, spot.Z, Layout.ButtonSize, Layout.ButtonSize })
		end

		local half = Layout.PlotSize / 2
		for i, a in footprints do
			assert(math.abs(a[2]) + a[4] / 2 <= half and math.abs(a[3]) + a[5] / 2 <= half, `{a[1]} is off the plot`)
			for j = i + 1, #footprints do
				local b = footprints[j]
				local apartX = math.abs(a[2] - b[2]) >= (a[4] + b[4]) / 2
				local apartZ = math.abs(a[3] - b[3]) >= (a[5] + b[5]) / 2
				assert(apartX or apartZ, `{a[1]} overlaps {b[1]}`)
			end
		end
	end)

	it("keeps a path's pads apart, so picking one can't step on another", function()
		for building, spots in Layout.Buttons do
			for path, a in spots.Paths or {} do
				for other, b in spots.Paths do
					if path < other then
						local apart = math.max(math.abs(a.X - b.X), math.abs(a.Z - b.Z)) - Layout.ButtonSize
						assert(apart >= 2, `{building}'s {path} and {other} pads are only {apart} studs apart`)
					end
				end
			end
		end
	end)

	it("leaves a gap between plots", function()
		expect(Layout.PlotSpacing > Layout.PlotSize).toBe(true)
	end)
end)

describe("catalog", function()
	it("has unique ids, known kinds and a stated description for each item", function()
		local seen = {}
		for _, item in Catalog do
			assert(not seen[item.Id], `duplicate catalog id {item.Id}`)
			seen[item.Id] = true
			assert(item.Kind == "GamePass" or item.Kind == "DeveloperProduct", `{item.Id} has unknown kind`)
			local idField = if item.Kind == "GamePass" then item.PassId else item.ProductId
			assert(type(idField) == "number", `{item.Id} needs a numeric id (0 until set up)`)
			assert(type(item.Includes) == "string" and #item.Includes > 0, `{item.Id} must say what it includes`)
		end
	end)
end)

return nil
