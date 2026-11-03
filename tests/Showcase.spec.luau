-- The showcase build (showcase.project.json and src/showcase), which dresses
-- the festival for store screenshots in Studio. Its project must be the live
-- game's plus the showcase modules and nothing else, and every plot it
-- shows must be a real route through the tree that unlocks everything on it.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Cosmetics = require("../src/shared/Config/Cosmetics")
local FestivalConfig = require("../src/shared/Config/Festival")
local Layout = require("../src/shared/Config/Layout")
local ParadeConfig = require("../src/shared/Config/Parade")
local Festival = require("../src/shared/Festival")
local Progression = require("../src/shared/Progression")
local Wardrobe = require("../src/shared/Wardrobe")
local Theme = require("../src/shared/Themes/MoonlightFestival")
local Migrations = require("../src/server/Lib/Migrations")
local Plan = require("../src/showcase/Plan")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local plots = { Plan.Player }
for _, neighbour in Plan.Neighbours do
	table.insert(plots, neighbour)
end

local function nobody(_id: string): boolean
	return false
end

local function saveFor(plot): any
	local save = Migrations.new()
	Plan.fill(save, plot, Balance.Upgrades)
	return save
end

local function progressOf(save): Festival.Progress
	return { Owned = save.Owned, ActivityBest = save.Activity.Best, Parades = save.Parade.Joined }
end

describe("showcase build", function()
	it("is the live game's project plus the showcase modules", function()
		local live = serde.decode("json", fs.readFile("default.project.json"))
		local showcase = serde.decode("json", fs.readFile("showcase.project.json"))
		local shared = showcase.tree.ReplicatedStorage.Shared
		local server = showcase.tree.ServerScriptService.Server
		local client = showcase.tree.StarterPlayer.StarterPlayerScripts.Client
		expect(shared.ShowcasePlan["$path"]).toBe("src/showcase/Plan.luau")
		expect(server.Showcase["$path"]).toBe("src/showcase/Server.luau")
		expect(client.Showcase["$path"]).toBe("src/showcase/Client.luau")
		shared.ShowcasePlan = nil
		server.Showcase = nil
		client.Showcase = nil
		showcase.name = live.name
		expect(showcase).toEqual(live)
	end)

	it("puts every plot on a whole route through the tree", function()
		local paths = Progression.paths(Balance.Upgrades)
		for _, plot in plots do
			for building, byPath in paths do
				local path = plot.Paths[building]
				assert(path and byPath[path], `plot {plot.Index} has no path of {building}`)
			end
			for building in plot.Paths do
				assert(paths[building], `plot {plot.Index} names {building}, which has no paths`)
			end
			local owned = Plan.owned(plot.Paths, Balance.Upgrades)
			for id in owned do
				local upgrade = Progression.find(Balance.Upgrades, id)
				assert(upgrade, `plot {plot.Index} owns unknown {id}`)
				assert(
					not upgrade.Requires or owned[upgrade.Requires],
					`plot {plot.Index} owns {id} without {upgrade.Requires}`
				)
				assert(
					not Progression.pathLocked(owned, Balance.Upgrades, upgrade),
					`plot {plot.Index} owns {id} on a locked path`
				)
			end
			for building, path in plot.Paths do
				assert(
					Progression.pathComplete(owned, Balance.Upgrades, building, path),
					`plot {plot.Index} hasn't finished {building} {path}`
				)
			end
			-- Maxed out: nothing left to buy.
			expect(#Progression.available(owned, Balance.Upgrades)).toBe(0)
		end
	end)

	it("shows every path on one plot or another", function()
		for building, byPath in Progression.paths(Balance.Upgrades) do
			for path in byPath do
				local shown = false
				for _, plot in plots do
					shown = shown or plot.Paths[building] == path
				end
				assert(shown, `no plot shows {building} {path}`)
			end
		end
	end)

	it("uses a different plot in the row for everyone, and names each neighbour", function()
		local used = {}
		for _, plot in plots do
			assert(plot.Index >= 1 and plot.Index <= Layout.PlotCount, `no plot {plot.Index}`)
			assert(not used[plot.Index], `plot {plot.Index} is used twice`)
			used[plot.Index] = true
		end
		for _, neighbour in Plan.Neighbours do
			assert(type(neighbour.Owner) == "string" and #neighbour.Owner > 0, `plot {neighbour.Index} has no owner`)
		end
		-- The player's plot is one of the two beside the courtyard.
		expect(math.abs(Layout.plotX(Plan.Player.Index)) < Layout.PlotSpacing).toBe(true)
	end)

	it("gives every plot a festival it has unlocked", function()
		local counts = {}
		for index, words in Theme.FestivalNames do
			counts[index] = #words
		end
		for _, plot in plots do
			local save = saveFor(plot)
			local progress = progressOf(save)
			assert(Festival.validName(save.Festival.Name, counts), `plot {plot.Index} has a bad name`)
			local palettes = Festival.unlocked(FestivalConfig.Palettes, progress, Balance.Upgrades)
			assert(palettes[save.Festival.Palette], `plot {plot.Index} hasn't unlocked {save.Festival.Palette}`)
			local decor = Festival.unlocked(FestivalConfig.Decor, progress, Balance.Upgrades)
			for spot in Layout.Decor do
				local id = save.Festival.Decor[tostring(spot)]
				assert(id, `plot {plot.Index} has nothing in spot {spot}`)
				assert(decor[id], `plot {plot.Index} hasn't unlocked {id}`)
				expect(Festival.decorAt(FestivalConfig, save.Festival, decor, spot)).toBe(id)
			end
			for spot in save.Festival.Decor do
				local number = tonumber(spot)
				assert(number and Layout.Decor[number], `plot {plot.Index} names spot {spot}`)
			end
		end
	end)

	it("unlocks every colour and decoration, so the trophies are full", function()
		local progress = progressOf(saveFor(Plan.Player))
		for _, list in { FestivalConfig.Palettes, FestivalConfig.Decor } do
			for _, choice in list do
				assert(Festival.isUnlocked(choice, progress, Balance.Upgrades), `{choice.Id} is still locked`)
			end
		end
	end)

	it("earns every free item and wears only earned ones", function()
		local save = saveFor(Plan.Player)
		local have = Wardrobe.owned(Cosmetics, save.Owned, Balance.Upgrades, nobody)
		for _, cosmetic in Cosmetics do
			if cosmetic.Line == "Earned" then
				assert(have[cosmetic.Id], `{cosmetic.Id} isn't earned`)
			end
		end
		for _, slot in Wardrobe.SLOTS do
			local id = Plan.Outfit[slot]
			assert(id, `nothing worn in {slot}`)
			expect(Wardrobe.canEquip(Cosmetics, have, slot, id)).toBe(true)
			expect((Wardrobe.find(Cosmetics, id) :: any).Line).toBe("Earned")
		end
		expect(Wardrobe.worn(Cosmetics, save.Equipped, have)).toEqual(Plan.Outfit)
	end)

	it("fills a save without changing its shape", function()
		local save = saveFor(Plan.Player)
		local template = Migrations.new()
		for key, value in template do
			expect(type(save[key])).toBe(type(value))
		end
		for key in save do
			assert(template[key] ~= nil, `the showcase adds {key} to the save`)
		end
		expect(save.Coins).toBe(Plan.Coins)
	end)

	it("brings the Moonlight Parade round early, without overlapping", function()
		expect(Plan.ParadeFirstSeconds < ParadeConfig.FirstSeconds).toBe(true)
		expect(Plan.ParadeIntervalSeconds > ParadeConfig.RunSeconds).toBe(true)
	end)
end)
