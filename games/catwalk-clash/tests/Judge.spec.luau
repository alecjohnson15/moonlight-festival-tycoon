local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Judge = RobloxLoader.require("src/shared/Judge")
local Look = RobloxLoader.require("src/shared/Look")
local RivalStyle = RobloxLoader.require("src/shared/RivalStyle")
local StyleScore = RobloxLoader.require("src/shared/StyleScore")
local Themes = RobloxLoader.require("src/shared/Config/Themes")
local People = RobloxLoader.require("src/shared/Config/People")
local Wardrobe = RobloxLoader.require("src/shared/Config/Wardrobe")
local Ranks = RobloxLoader.require("src/shared/Config/Ranks")
local Palette = RobloxLoader.require("src/shared/Config/Palette")
local Game = RobloxLoader.require("src/shared/Config/Game")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The best look that can be made from the pieces allowed(piece) accepts: in
-- each slot, the piece that fits the theme best (or any allowed piece, since
-- a complete outfit scores too), all painted in the theme's colours.
local function bestLook(theme, allowed)
	local look = Look.default()
	local colors = {}
	for _, name in theme.Colors do
		table.insert(colors, Palette.indexOf(name))
	end
	look.Top.C = colors[1]
	look.Bottom.C = colors[2] or colors[1]
	for index, slot in Wardrobe.Slots do
		local best, bestFit = nil, -1
		for _, piece in Wardrobe.inSlot(slot) do
			if allowed(piece) then
				local fit = 0
				for _, tag in piece.Tags do
					if table.find(theme.Tags, tag) then
						fit += 1
					end
				end
				if fit > bestFit then
					best, bestFit = piece, fit
				end
			end
		end
		if best then
			local color = colors[(index - 1) % #colors + 1]
			look.Pieces[slot] = { Id = best.Id, C = color, A = color, F = best.Finish }
		end
	end
	return look
end

local function isFree(piece)
	return Wardrobe.source(piece) == "Free"
end

local function freeLookFor(theme)
	return bestLook(theme, isFree)
end

local function offThemeLook(theme)
	local look = Look.default()
	for _, slot in Wardrobe.Slots do
		for _, piece in Wardrobe.inSlot(slot) do
			local fits = false
			for _, tag in piece.Tags do
				fits = fits or table.find(theme.Tags, tag) ~= nil
			end
			if not fits then
				look.Pieces[slot] = { Id = piece.Id, C = 1, A = 1, F = piece.Finish }
				break
			end
		end
	end
	return look
end

-- A small seeded random number generator: numbers from 0 to 1.
local function seeded(seed)
	local state = seed
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function sequence(values)
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

describe("Judge", function()
	it("scores an on-theme look above an off-theme one for every theme", function()
		for _, theme in Themes.List do
			local good = Judge.themeScore(Look.summary(freeLookFor(theme)), theme, {})
			local bad = Judge.themeScore(Look.summary(offThemeLook(theme)), theme, {})
			assert(good > bad, `{theme.Id}: on theme {good}, off theme {bad}`)
		end
	end)

	it("lets free pieces alone nail every theme", function()
		local short = {}
		for _, theme in Themes.List do
			local score = Judge.themeScore(Look.summary(freeLookFor(theme)), theme, {})
			if score < Judge.NAILED then
				table.insert(short, `{theme.Id} {score}`)
			end
		end
		assert(#short == 0, `free pieces fall short for {table.concat(short, ", ")}`)
	end)

	it("gives Robux pieces no edge over pieces earned with Sparkles", function()
		local short = {}
		for _, theme in Themes.List do
			local earned = Judge.themeScore(
				Look.summary(bestLook(theme, function(piece)
					local source = Wardrobe.source(piece)
					return source == "Free" or source == "Sparkles"
				end)),
				theme,
				{}
			)
			local all = Judge.themeScore(
				Look.summary(bestLook(theme, function()
					return true
				end)),
				theme,
				{}
			)
			if earned < all then
				table.insert(short, `{theme.Id} {earned}/{all}`)
			end
		end
		assert(#short == 0, `paid pieces score higher for {table.concat(short, ", ")}`)
	end)

	it("never scores a theme above 100", function()
		local theme = Themes.List[1]
		local colors = {}
		for _ = 1, 10 do
			table.insert(colors, Palette.resolve(theme.Colors[1]))
		end
		local summary = {
			Tags = { [theme.Tags[1]] = 40 },
			PieceCount = 40,
			Colors = colors,
			Glows = true,
			CatalogCount = 40,
		}
		local names = { theme.Words[1], theme.Words[1], theme.Words[1], theme.Words[1] }
		expect(Judge.themeScore(summary, theme, names)).toBe(Judge.MAX_THEME)
	end)

	it("matches catalog item names to theme words, ignoring case", function()
		expect(Judge.wordMatches({ "Sparkly CROWN of Stars", "Plain Hat" }, { "crown", "tiara" })).toBe(1)
		expect(Judge.wordMatches({}, { "crown" })).toBe(0)
	end)

	it("gives every judge one vote, mostly for the better look", function()
		local theme = Themes.List[1]
		local good = Look.summary(freeLookFor(theme))
		local bad = Look.summary(offThemeLook(theme))
		local verdict = Judge.verdict(People.Judges, theme, good, {}, bad, {}, sequence({ 0.5 }))
		expect(#verdict.Sides).toBe(#People.Judges)
		for _, side in verdict.Sides do
			expect(side).toBe("A")
		end
		expect(verdict.ThemeA > verdict.ThemeB).toBe(true)
	end)
end)

describe("Rivals", function()
	it("always wear a look that passes the server's own checks", function()
		local everything = {
			ownsPiece = function()
				return true
			end,
			ownsPose = function()
				return true
			end,
			ownsEntrance = function()
				return true
			end,
			customColors = false,
			maxCatalog = 0,
		}
		local rng = seeded(7)
		for _, rival in People.Rivals do
			for _, theme in Themes.List do
				local look = RivalStyle.dress(rival, theme, rng)
				local clean = Look.sanitize(look, everything)
				assert(Look.same(look, clean), `{rival.Id} wore something invalid for {theme.Id}`)
			end
		end
	end)

	it("fit the theme better the more skilled they are", function()
		local rng = seeded(11)
		local function average(skill)
			local total = 0
			for _ = 1, 20 do
				for _, theme in Themes.List do
					local rival = { Loves = { "retro" }, Skill = skill, Skin = 1, Pose = "wave" }
					local look = RivalStyle.dress(rival, theme, rng)
					total += Judge.themeScore(Look.summary(look), theme, {})
				end
			end
			return total
		end
		expect(average(0.9) > average(0.2)).toBe(true)
	end)
end)

describe("Style Score", function()
	local settings = Game.StyleScore

	it("pays more for beating a stronger walker", function()
		local upset = StyleScore.update(settings, 1000, 1300, true, 50, false)
		local expected = StyleScore.update(settings, 1000, 800, true, 50, false)
		expect(upset > expected).toBe(true)
	end)

	it("moves half as much against a rival", function()
		local player = StyleScore.update(settings, 1000, 1000, true, 50, false) - 1000 - settings.WalkBonus
		local rival = StyleScore.update(settings, 1000, 1000, true, 50, true) - 1000 - settings.WalkBonus
		expect(rival).toBe(math.round(player * settings.RivalScale))
	end)

	it("moves faster while a player is new", function()
		local new = StyleScore.update(settings, 1000, 1000, true, 0, false)
		local settled = StyleScore.update(settings, 1000, 1000, true, 100, false)
		expect(new > settled).toBe(true)
	end)

	it("never drops below the floor", function()
		expect(StyleScore.update(settings, settings.Floor + 5, settings.Floor + 5, false, 50, false)).toBe(
			settings.Floor
		)
	end)

	it("never takes points from a player's first walks", function()
		for walks = 0, settings.ProtectedWalks - 1 do
			local after = StyleScore.update(settings, settings.Start, 1800, false, walks, false)
			expect(after >= settings.Start).toBe(true)
		end
		local settled =
			StyleScore.update(settings, settings.Start, settings.Start, false, settings.ProtectedWalks, false)
		expect(settled < settings.Start).toBe(true)
	end)

	it("keeps a brand-new player's rank after a loss", function()
		local after = StyleScore.update(settings, settings.Start, settings.Start, false, 0, false)
		expect(StyleScore.rank(Ranks, after).Name).toBe(StyleScore.rank(Ranks, settings.Start).Name)
	end)

	it("gives the highest rank reached", function()
		expect(StyleScore.rank(Ranks, 0).Name).toBe("Newcomer")
		expect(StyleScore.rank(Ranks, settings.Start).Name).toBe("Rising Star")
		expect(StyleScore.rank(Ranks, 99999).Name).toBe(Ranks[#Ranks].Name)
	end)
end)

describe("Judge feedback and exploits", function()
	local theme = Themes.List[1]

	it("gives stars and compliments, never the score", function()
		for _, each in Themes.List do
			for _, look in { freeLookFor(each), offThemeLook(each), Look.default() } do
				local notes = Judge.feedback(Look.summary(look), each, {})
				assert(#notes >= 1 and #notes <= 3, "feedback has 1 to 3 notes")
				for _, note in notes do
					assert(not string.find(note, "%d"), `feedback shows a number: {note}`)
				end
			end
		end
		expect(Judge.feedback(Look.summary(freeLookFor(theme)), theme, {})[1]).toBe("Theme ★★★")
	end)

	it("scores an empty look low", function()
		local look = Look.default()
		look.Top.C = 1
		look.Bottom.C = 1
		for _, each in Themes.List do
			assert(Judge.themeScore(Look.summary(look), each, {}) < 20, `an empty look scores well for {each.Id}`)
		end
	end)

	it("can't be nailed with catalog names alone", function()
		for _, each in Themes.List do
			local look = Look.default()
			local names = {}
			for index = 1, 14 do
				look.Catalog[index] = index
				names[index] = `{each.Words[1]} item {index}`
			end
			local score = Judge.themeScore(Look.summary(look), each, names)
			assert(score < Judge.NAILED, `catalog names alone nail {each.Id} ({score})`)
		end
	end)

	it("can't be nailed with one piece, however well it fits", function()
		for _, each in Themes.List do
			local best = bestLook(each, isFree)
			for slot, choice in best.Pieces do
				local look = Look.default()
				look.Pieces[slot] = choice
				look.Top.C = choice.C
				look.Bottom.C = choice.C
				local score = Judge.themeScore(Look.summary(look), each, {})
				assert(score < Judge.NAILED, `one {slot} piece nails {each.Id} ({score})`)
			end
		end
	end)
end)

describe("Theme look (Stylist)", function()
	local Stylist = RobloxLoader.require("src/shared/Stylist")
	local free = function(piece)
		return isFree(piece)
	end
	local ownsFree = {
		ownsPiece = function(id)
			return Wardrobe.source(Wardrobe.get(id)) == "Free"
		end,
		ownsPose = function()
			return true
		end,
		ownsEntrance = function()
			return true
		end,
		customColors = false,
		maxCatalog = 14,
	}

	it("only uses pieces the player owns, and keeps their pose and catalog items", function()
		local rng = seeded(5)
		local base = Look.default()
		base.Catalog = { 123, 456 }
		base.Pose = "wave"
		for _, each in Themes.List do
			local look = Stylist.suggest(each, free, base, rng)
			expect(Look.same(look, Look.sanitize(look, ownsFree))).toBe(true)
			expect(look.Pose).toBe("wave")
			expect(look.Catalog).toEqual({ 123, 456 })
		end
	end)

	it("gives a new player a look that nails the theme, every theme", function()
		local rng = seeded(9)
		local short = {}
		for _, each in Themes.List do
			for _ = 1, 10 do
				local score = Judge.themeScore(Look.summary(Stylist.suggest(each, free, Look.default(), rng)), each, {})
				if score < Judge.NAILED then
					table.insert(short, `{each.Id} {score}`)
					break
				end
			end
		end
		assert(#short == 0, `theme looks fall short for {table.concat(short, ", ")}`)
	end)

	it("gives a different idea when pressed again", function()
		local rng = seeded(3)
		local different = 0
		for _, each in Themes.List do
			local first = Stylist.suggest(each, free, Look.default(), rng)
			local second = Stylist.suggest(each, free, Look.default(), rng)
			if not Look.same(first, second) then
				different += 1
			end
		end
		expect(different > #Themes.List * 0.8).toBe(true)
	end)
end)

describe("Themes", function()
	local ThemePicker = RobloxLoader.require("src/shared/ThemePicker")

	it("each ask for a different mix of tags", function()
		local seen = {}
		for _, each in Themes.List do
			local tags = table.clone(each.Tags)
			table.sort(tags)
			local key = table.concat(tags, "+")
			assert(not seen[key], `{each.Id} has the same tags as {seen[key]}`)
			seen[key] = each.Id
		end
	end)

	it("have real dates, colours and words", function()
		local days = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
		for _, each in Themes.List do
			assert(#each.Words >= 2, `{each.Id} has too few catalog words`)
			for _, name in each.Colors do
				assert(Palette.indexOf(name), `{each.Id} uses unknown colour {name}`)
			end
			if each.Window then
				for _, date in { each.Window.From, each.Window.To } do
					assert(
						date[1] >= 1 and date[1] <= 12 and date[2] >= 1 and date[2] <= days[date[1]],
						`{each.Id} has a bad date`
					)
				end
			end
		end
	end)

	it("offer three themes and a spotlight on every day for years, past the season's end", function()
		local start = os.time({ year = 2026, month = 11, day = 1, hour = 12 })
		local rng = function(n)
			return (n // 2) + 1
		end
		for day = 0, 365 * 3 do
			local time = start + day * 86400
			local options = ThemePicker.options(Themes.List, time, {}, rng, 3)
			assert(#options == 3, `only {#options} themes on day {day}`)
			assert(Themes.get(ThemePicker.spotlight(Themes.List, time)), `no spotlight on day {day}`)
		end
	end)
end)
