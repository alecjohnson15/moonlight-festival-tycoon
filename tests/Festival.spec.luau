-- Each player's own festival (Config/Festival): what unlocks each choice,
-- the name a new festival starts with, which choices the server accepts, and
-- that the theme names everything the config lists.

local TestKit = require("./TestKit")
local ActivityConfig = require("../src/shared/Config/Activity")
local Balance = require("../src/shared/Config/Balance")
local Config = require("../src/shared/Config/Festival")
local Layout = require("../src/shared/Config/Layout")
local Festival = require("../src/shared/Festival")
local Theme = require("../src/shared/Themes/MoonlightFestival")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local COUNTS = {}
for index, list in Theme.FestivalNames do
	COUNTS[index] = #list
end

local function progress(owned: { [string]: boolean }?, best: number?, parades: number?): Festival.Progress
	return { Owned = owned or {}, ActivityBest = best or 0, Parades = parades or 0 }
end

-- Every upgrade on a path of building, all tiers.
local function finish(owned: { [string]: boolean }, building: string, path: string)
	for _, upgrade in Balance.Upgrades do
		if upgrade.Building == building and upgrade.Path == path then
			owned[upgrade.Id] = true
		end
	end
end

describe("festival config", function()
	it("passes validation", function()
		local problems = Festival.validate(Config, #Layout.Decor, Balance.Upgrades, ActivityConfig.Wisps)
		expect(#problems).toBe(0)
	end)

	it("finds problems in a broken config", function()
		local broken = {
			NameWords = 3,
			Palettes = { { Id = "a", Unlock = { Parades = 1 } }, { Id = "a" } },
			Decor = { { Id = "x", Unlock = { Owns = "nope" } }, { Id = "y", Unlock = { ActivityBest = 99 } } },
			DefaultDecor = { "x" },
		}
		local problems = Festival.validate(broken, 2, Balance.Upgrades, ActivityConfig.Wisps)
		expect(#problems).toBe(6)
	end)

	it("only unlocks with things every route through the tree gets", function()
		-- A player takes one path per building, so an unlock that needs one
		-- particular path could never come on the others.
		for _, list in { Config.Palettes, Config.Decor } do
			for _, choice in list do
				local unlock = choice.Unlock
				assert(not (unlock and (unlock.Path or unlock.Tier)), `{choice.Id} needs one path or tier`)
				if unlock and unlock.Owns then
					local upgrade = assert(
						(function()
							for _, upgrade in Balance.Upgrades do
								if upgrade.Id == unlock.Owns then
									return upgrade
								end
							end
							return nil
						end)(),
						`{choice.Id} needs an unknown upgrade`
					)
					assert(upgrade.Path == nil, `{choice.Id} needs an upgrade on one path`)
				end
			end
		end
	end)

	it("gives every festival a choice from the start", function()
		local start = progress()
		local palettes = Festival.unlocked(Config.Palettes, start, Balance.Upgrades)
		local decor = Festival.unlocked(Config.Decor, start, Balance.Upgrades)
		local palettesFree, decorFree = 0, 0
		for _ in palettes do
			palettesFree += 1
		end
		for _ in decor do
			decorFree += 1
		end
		assert(palettesFree >= 2, "a new festival has only one palette")
		assert(decorFree >= 3, "a new festival has fewer than three decorations")
	end)
end)

describe("festival rules", function()
	it("unlocks each kind of choice by its own rule", function()
		local owns = { Id = "o", Unlock = { Owns = "kitchen" } }
		expect(Festival.isUnlocked(owns, progress(), Balance.Upgrades)).toBe(false)
		expect(Festival.isUnlocked(owns, progress({ kitchen = true }), Balance.Upgrades)).toBe(true)

		local path = { Id = "p", Unlock = { Building = "attraction_1" } }
		local owned = {}
		expect(Festival.isUnlocked(path, progress(owned), Balance.Upgrades)).toBe(false)
		finish(owned, "attraction_1", "ticket")
		expect(Festival.isUnlocked(path, progress(owned), Balance.Upgrades)).toBe(true)

		local best = { Id = "b", Unlock = { ActivityBest = 8 } }
		expect(Festival.isUnlocked(best, progress(nil, 7), Balance.Upgrades)).toBe(false)
		expect(Festival.isUnlocked(best, progress(nil, 8), Balance.Upgrades)).toBe(true)

		local parades = { Id = "m", Unlock = { Parades = 3 } }
		expect(Festival.isUnlocked(parades, progress(nil, 0, 2), Balance.Upgrades)).toBe(false)
		expect(Festival.isUnlocked(parades, progress(nil, 0, 3), Balance.Upgrades)).toBe(true)
	end)

	it("lists finished paths in tree order", function()
		local owned = {}
		finish(owned, "attraction_3", "draw")
		finish(owned, "starter_stall", "markup")
		local finished = Festival.finishedPaths(owned, Balance.Upgrades)
		expect(#finished).toBe(2)
		expect(finished[1].Building).toBe("starter_stall")
		expect(finished[1].Path).toBe("markup")
		expect(finished[2].Path).toBe("draw")
	end)

	it("lists what's newly unlocked in config order", function()
		local before = { classic = true }
		local after = { classic = true, midnight = true, toxic = true }
		expect(Festival.newlyUnlocked(Config.Palettes, before, after)).toEqual({ "toxic", "midnight" })
	end)

	it("names a new festival from the player's id, the same every time", function()
		for _, seed in { 1, 42, 123456789, 2 ^ 40 } do
			local name = Festival.defaultName(seed, COUNTS)
			assert(Festival.validName(name, COUNTS), `seed {seed} gives an invalid name`)
			expect(Festival.defaultName(seed, COUNTS)).toEqual(name)
		end
		-- Different players mostly get different names.
		local seen, distinct = {}, 0
		for seed = 1, 200 do
			local key = table.concat(Festival.defaultName(seed * 7919, COUNTS), ",")
			if not seen[key] then
				seen[key] = true
				distinct += 1
			end
		end
		assert(distinct > 150, `only {distinct} names for 200 players`)
	end)

	it("only accepts a whole word from each list", function()
		expect(Festival.validName({ 1, 2, 3 }, COUNTS)).toBe(true)
		expect(Festival.validName({ 1, 2 }, COUNTS)).toBe(false)
		expect(Festival.validName({ 1, 2, 0 }, COUNTS)).toBe(false)
		expect(Festival.validName({ 1, 2, COUNTS[3] + 1 }, COUNTS)).toBe(false)
		expect(Festival.validName({ 1, 2.5, 3 }, COUNTS)).toBe(false)
		expect(Festival.validName({ 1, "2", 3 }, COUNTS)).toBe(false)
		expect(Festival.validName("1,2,3", COUNTS)).toBe(false)
	end)

	it("shows a spot's default until the owner picks something unlocked", function()
		local choices = { Name = {}, Palette = "", Decor = { ["2"] = "ghost_statue", ["3"] = "nonsense" } }
		expect(Festival.decorAt(Config, nil, nil, 1)).toBe(Config.DefaultDecor[1])
		expect(Festival.decorAt(Config, choices, { ghost_statue = true }, 2)).toBe("ghost_statue")
		-- Something no longer unlocked, or unknown, falls back.
		expect(Festival.decorAt(Config, choices, {}, 2)).toBe(Config.DefaultDecor[2])
		expect(Festival.decorAt(Config, choices, nil, 3)).toBe(Config.DefaultDecor[3])
	end)

	it("falls back to the first palette", function()
		expect(Festival.paletteOf(Config, nil, nil)).toBe(Config.Palettes[1].Id)
		local choices = { Name = {}, Palette = "midnight", Decor = {} }
		expect(Festival.paletteOf(Config, choices, { midnight = true })).toBe("midnight")
		expect(Festival.paletteOf(Config, choices, { classic = true })).toBe(Config.Palettes[1].Id)
	end)

	it("turns a set into text and back", function()
		local set = { b = true, a = true, c = true }
		expect(Festival.encode(set)).toBe("a,b,c")
		expect(Festival.decode("a,b,c")).toEqual(set)
		expect(Festival.decode(nil)).toEqual({})
	end)
end)

describe("theme festival", function()
	it("names every palette, decoration, spot and word list", function()
		expect(#Theme.FestivalNames).toBe(Config.NameWords)
		local _, slots = string.gsub(Theme.Strings.FestivalName, "%%s", "")
		expect(slots).toBe(Config.NameWords)
		for index, list in Theme.FestivalNames do
			assert(#list >= 8, `name list {index} has only {#list} words`)
			local seen = {}
			for _, word in list do
				assert(not seen[word], `"{word}" is in name list {index} twice`)
				seen[word] = true
			end
		end
		for _, choice in Config.Palettes do
			local themed = Theme.Palettes[choice.Id]
			assert(themed and themed.DisplayName, `the theme has no palette {choice.Id}`)
			expect(#themed.Colors).toBe(2)
			for _, hex in themed.Colors do
				assert(string.match(hex, "^#%x%x%x%x%x%x$"), `{choice.Id} colour {hex} must be #RRGGBB`)
			end
		end
		for _, choice in Config.Decor do
			assert(Theme.Decor[choice.Id], `the theme has no name for decoration {choice.Id}`)
		end
		expect(#Theme.DecorSpots).toBe(#Layout.Decor)
	end)

	it("starts with the stall's own colours", function()
		local first = Theme.Palettes[Config.Palettes[1].Id].Colors
		expect(first).toEqual(Theme.Palette.AwningStripes)
	end)
end)

describe("festival layout", function()
	-- Boxes on the plot floor, { name, minX, minZ, maxX, maxZ }, that a
	-- decoration spot, the board or the shelf must stay clear of.
	local function busy(): { { any } }
		local boxes = {}
		local function add(name: string, x: number, z: number, width: number, depth: number)
			table.insert(boxes, { name, x - width / 2, z - depth / 2, x + width / 2, z + depth / 2 })
		end
		for id, slot in Layout.Slots do
			add(`slot {id}`, slot.X, slot.Z, slot.Size[1], slot.Size[3])
			if slot.Yard then
				add(`{id}'s yard`, slot.Yard.X, slot.Yard.Z, slot.Yard.Size[1], slot.Yard.Size[3])
			end
		end
		for building, spots in Layout.Buttons do
			local list = { spots.Build, spots.Upgrades }
			for _, spot in spots.Paths or {} do
				table.insert(list, spot)
			end
			for _, spot in list do
				add(`a pad of {building}`, spot.X, spot.Z, Layout.ButtonSize, Layout.ButtonSize)
			end
		end
		local booth = Layout.Activity
		add("Ghost Catcher's booth", booth.X, booth.Z, booth.Size[1], booth.Size[3])
		add("Ghost Catcher's pad", booth.Pad.X, booth.Pad.Z, Layout.ButtonSize, Layout.ButtonSize)
		local area = ActivityConfig.Area
		local reach = ActivityConfig.CatchRadius * 2
		add("the wisps' strip", area.X, area.Z, area.Width + reach, area.Depth + reach)
		local gate = Layout.Gate
		add("the gate", gate.X, gate.Z, gate.Size[1] + 6, gate.Size[3] + 4)
		return boxes
	end

	local function overlaps(box: { any }, x: number, z: number, width: number, depth: number): boolean
		return x + width / 2 > box[2] and x - width / 2 < box[4] and z + depth / 2 > box[3] and z - depth / 2 < box[5]
	end

	it("keeps decoration spots, the board and the shelf clear of everything else", function()
		local places = {}
		for spot, place in Layout.Decor do
			table.insert(places, { `decoration spot {spot}`, place.X, place.Z, Layout.DecorSize, Layout.DecorSize })
		end
		for name, place in { board = Layout.Board, shelf = Layout.Shelf } do
			table.insert(places, { name, place.X, place.Z, place.Size[1], place.Size[3] })
		end
		local edge = Layout.PlotSize / 2 - 2
		for index, place in places do
			local name, x, z, width, depth = place[1], place[2], place[3], place[4], place[5]
			assert(math.abs(x) + width / 2 <= edge and math.abs(z) + depth / 2 <= edge, `{name} is off the plot`)
			for _, box in busy() do
				assert(not overlaps(box, x, z, width, depth), `{name} is in the way of {box[1]}`)
			end
			for other = index + 1, #places do
				local them = places[other]
				local box = {
					them[1],
					them[2] - them[4] / 2,
					them[3] - them[5] / 2,
					them[2] + them[4] / 2,
					them[3] + them[5] / 2,
				}
				assert(not overlaps(box, x, z, width, depth), `{name} overlaps {them[1]}`)
			end
		end
	end)
end)

return nil
