-- Writes docs/theme-coverage.md: for every theme, which tags and colours
-- the judges look for, how many wardrobe slots a new player (free pieces
-- only) and a player who has earned Sparkles can fill with fitting pieces,
-- the best judges' theme score each can reach, and the theme it is most
-- like. Run from the game's folder: `lune run tools/theme_matrix`.

local fs = require("@lune/fs")
local RobloxLoader = require("../tests/RobloxLoader")

local Themes = RobloxLoader.require("src/shared/Config/Themes")
local Wardrobe = RobloxLoader.require("src/shared/Config/Wardrobe")
local Palette = RobloxLoader.require("src/shared/Config/Palette")
local Look = RobloxLoader.require("src/shared/Look")
local Judge = RobloxLoader.require("src/shared/Judge")

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function fit(piece, theme): number
	local count = 0
	for _, tag in piece.Tags do
		if table.find(theme.Tags, tag) then
			count += 1
		end
	end
	return count
end

-- The best look from the allowed pieces, painted in the theme's colours,
-- and how many slots hold a piece that fits.
local function best(theme, allowed)
	local look = Look.default()
	local colors = {}
	for _, name in theme.Colors do
		table.insert(colors, Palette.indexOf(name))
	end
	look.Top.C = colors[1]
	look.Bottom.C = colors[2] or colors[1]
	local fitting = 0
	for index, slot in Wardrobe.Slots do
		local chosen, chosenFit = nil, -1
		for _, piece in Wardrobe.inSlot(slot) do
			if allowed(piece) then
				local score = fit(piece, theme)
				if score > chosenFit then
					chosen, chosenFit = piece, score
				end
			end
		end
		if chosen then
			local color = colors[(index - 1) % #colors + 1]
			look.Pieces[slot] = { Id = chosen.Id, C = color, A = color, F = chosen.Finish }
			if chosenFit > 0 then
				fitting += 1
			end
		end
	end
	return math.floor(Judge.themeScore(Look.summary(look), theme, {})), fitting
end

local function isFree(piece)
	return Wardrobe.source(piece) == "Free"
end

local function isEarned(piece)
	local source = Wardrobe.source(piece)
	return source == "Free" or source == "Sparkles"
end

local function overlap(a, b): number
	local shared, union = 0, {}
	for _, tag in a.Tags do
		union[tag] = true
		if table.find(b.Tags, tag) then
			shared += 1
		end
	end
	for _, tag in b.Tags do
		union[tag] = true
	end
	local size = 0
	for _ in union do
		size += 1
	end
	return shared / size
end

local lines = {
	"# Theme coverage",
	"",
	"Made by `lune run tools/theme_matrix` from the theme, wardrobe and judge",
	"code; rerun it after changing any of them. **New player** counts free",
	"pieces only; **Earned** adds pieces bought with Sparkles earned by",
	"playing. **Slots** is how many of the 10 wardrobe slots have a piece that",
	`fits the theme; **Best** is the judges' theme score of the best such look`,
	`(out of 100; {Judge.NAILED} counts as nailing it). **Most like** is the`,
	"theme with the most tags in common, and what share of the two themes'",
	"tags they have in common.",
	"",
	"The judges are rules: they read tags, catalog item names and colours.",
	"Whether a look is actually good is the audience's call, and this table",
	"says nothing about that.",
	"",
	"| Theme | Tags | Colours | Season | New player slots | New player best | Earned slots | Earned best | Most like |",
	"| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
}

local weakest, weakestScore = nil, 101
for _, theme in Themes.List do
	local freeScore, freeSlots = best(theme, isFree)
	local earnedScore, earnedSlots = best(theme, isEarned)
	if freeScore < weakestScore then
		weakest, weakestScore = theme, freeScore
	end
	local closest, closestOverlap = nil, -1
	for _, other in Themes.List do
		if other ~= theme then
			local value = overlap(theme, other)
			if value > closestOverlap then
				closest, closestOverlap = other, value
			end
		end
	end
	local season = if theme.Window
		then `{MONTHS[theme.Window.From[1]]} {theme.Window.From[2]} to {MONTHS[theme.Window.To[1]]} {theme.Window.To[2]}`
		else "All year"
	table.insert(
		lines,
		`| {theme.Name} | {table.concat(theme.Tags, ", ")} | {table.concat(theme.Colors, ", ")} | {season} | {freeSlots} | {freeScore} | {earnedSlots} | {earnedScore} | {closest.Name} ({math.floor(
			closestOverlap * 100
		)}%) |`
	)
end
table.insert(lines, "")
table.insert(
	lines,
	`{#Themes.List} themes. The hardest for a new player is {weakest.Name} ({weakestScore}); every theme can be nailed with free pieces alone (tests/Judge.spec.luau checks this).`
)
table.insert(lines, "")

fs.writeFile("docs/theme-coverage.md", table.concat(lines, "\n"))
print(`wrote docs/theme-coverage.md ({#Themes.List} themes)`)
