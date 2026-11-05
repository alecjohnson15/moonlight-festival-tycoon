--!strict
-- The judges' scoring. The judges are rules, not AI: they read the theme
-- tags of the pieces worn, the names of catalog items and the colours, and
-- can't see how a look actually looks; the audience judges that. A look scores for fitting the theme (wardrobe pieces
-- whose tags match it, catalog items whose names contain its words, colours
-- close to its colours), for being complete, and a little for each judge's
-- own taste and for flair (a small random amount, so judges don't always
-- agree). Paid pieces are tagged like free ones, so money can't buy points.
-- Pure logic, tested in tests/Judge.spec.

local Palette = require(script.Parent.Config.Palette)

export type Summary = {
	Tags: { [string]: number },
	PieceCount: number,
	Colors: { Color3 },
	Glows: boolean,
	CatalogCount: number,
}

export type Theme = { Tags: { string }, Colors: { string }, Words: { string } }

export type JudgeInfo = { Loves: { string }, Colors: { string } }

local Judge = {}

Judge.MAX_THEME = 100
-- A colour this close to a theme colour counts as matching it.
Judge.COLOR_MATCH = 0.12
-- A theme score at least this high counts as nailing the theme.
Judge.NAILED = 55

local function countTags(summary: Summary, tags: { string }): number
	local count = 0
	for _, tag in tags do
		count += summary.Tags[tag] or 0
	end
	return count
end

local function colorMatches(colors: { Color3 }, names: { string }): number
	local matches = 0
	for _, color in colors do
		for _, name in names do
			if Palette.distance(color, Palette.resolve(name)) <= Judge.COLOR_MATCH then
				matches += 1
				break
			end
		end
	end
	return matches
end

-- How many of the catalog names contain one of the theme's words.
function Judge.wordMatches(names: { string }, words: { string }): number
	local matches = 0
	for _, name in names do
		local lower = string.lower(name)
		for _, word in words do
			if string.find(lower, string.lower(word), 1, true) then
				matches += 1
				break
			end
		end
	end
	return matches
end

-- How well a look fits the theme, from 0 to 100.
function Judge.themeScore(summary: Summary, theme: Theme, catalogNames: { string }): number
	local tagPoints = math.min(countTags(summary, theme.Tags) * 9, 54)
	local wordPoints = math.min(Judge.wordMatches(catalogNames, theme.Words) * 8, 24)
	local colorPoints = math.min(colorMatches(summary.Colors, theme.Colors) * 4, 16)
	local completePoints = math.min(summary.PieceCount + summary.CatalogCount, 8) * 2
	return math.min(Judge.MAX_THEME, tagPoints + wordPoints + colorPoints + completePoints)
end

-- One judge's score for a look: the theme score, their taste, and flair
-- (flair is a number from 0 to 1).
function Judge.score(judge: JudgeInfo, summary: Summary, theme: Theme, catalogNames: { string }, flair: number): number
	local taste = math.min(countTags(summary, judge.Loves) * 3, 9)
	local colorTaste = math.min(colorMatches(summary.Colors, judge.Colors) * 2, 6)
	return Judge.themeScore(summary, theme, catalogNames) + taste + colorTaste + flair * 10
end

-- A few words for a walker on their look, never the score itself, so the
-- formula can't be read off and gamed: how well it fits the theme (one to
-- three stars) and up to two compliments.
function Judge.feedback(summary: Summary, theme: Theme, catalogNames: { string }): { string }
	local score = Judge.themeScore(summary, theme, catalogNames)
	local stars = if score >= Judge.NAILED then "★★★" elseif score >= 35 then "★★☆" else "★☆☆"
	local notes = { `Theme {stars}` }
	local distinctTags = 0
	for _ in summary.Tags do
		distinctTags += 1
	end
	local compliments = {}
	if colorMatches(summary.Colors, theme.Colors) >= 2 then
		table.insert(compliments, "Colour match")
	end
	if Judge.wordMatches(catalogNames, theme.Words) >= 1 then
		table.insert(compliments, "Great catalog find")
	end
	if summary.PieceCount + summary.CatalogCount >= 6 then
		table.insert(compliments, "Head-to-toe look")
	end
	if distinctTags >= 5 then
		table.insert(compliments, "Creative mix")
	end
	if summary.Glows then
		table.insert(compliments, "Glow factor")
	end
	if #compliments == 0 then
		table.insert(compliments, if summary.PieceCount == 0 then "Try adding pieces" else "Bold choice")
	end
	for index = 1, math.min(2, #compliments) do
		table.insert(notes, compliments[index])
	end
	return notes
end

export type Verdict = {
	Sides: { string },
	Scores: { A: number, B: number },
	ThemeA: number,
	ThemeB: number,
}

-- Every judge's vote in a matchup. rng() returns a number from 0 to 1.
function Judge.verdict(
	judges: { JudgeInfo },
	theme: Theme,
	a: Summary,
	namesA: { string },
	b: Summary,
	namesB: { string },
	rng: () -> number
): Verdict
	local verdict: Verdict = {
		Sides = {},
		Scores = { A = 0, B = 0 },
		ThemeA = Judge.themeScore(a, theme, namesA),
		ThemeB = Judge.themeScore(b, theme, namesB),
	}
	for _, judge in judges do
		local scoreA = Judge.score(judge, a, theme, namesA, rng())
		local scoreB = Judge.score(judge, b, theme, namesB, rng())
		verdict.Scores.A += scoreA
		verdict.Scores.B += scoreB
		local forA = scoreA > scoreB or (scoreA == scoreB and rng() < 0.5)
		table.insert(verdict.Sides, if forA then "A" else "B")
	end
	return verdict
end

return Judge
