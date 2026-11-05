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
		expect(StyleScore.update(settings, settings.Floor + 5, settings.Floor + 5, false, 0, false)).toBe(
			settings.Floor
		)
	end)

	it("gives the highest rank reached", function()
		expect(StyleScore.rank(Ranks, 0).Name).toBe("Newcomer")
		expect(StyleScore.rank(Ranks, settings.Start).Name).toBe("Rising Star")
		expect(StyleScore.rank(Ranks, 99999).Name).toBe(Ranks[#Ranks].Name)
	end)
end)
