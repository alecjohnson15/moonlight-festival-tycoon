--!strict
-- Map geometry: how many plots there are and where each station and
-- attraction is built on a plot, in studs from the plot's centre. Plain
-- numbers so this file loads in tests as well as in Studio.
--
-- The plot's front (+Z) faces the plaza. The production chain runs down the
-- left side towards the stall at the front, and attractions fill the right.

return {
	PlotCount = 6,
	PlotSize = 96,
	PlotSpacing = 120,

	-- Where a player stands after being moved to their plot.
	ArrivalOffset = { X = 0, Z = 40 },

	-- Size is { width, height, depth } for the greybox block drawn when the
	-- theme has no model for that upgrade.
	Slots = {
		starter_stall = { X = -26, Z = 26, Size = { 8, 6, 6 } },
		kitchen = { X = -26, Z = -2, Size = { 12, 8, 10 } },
		grower = { X = -26, Z = -28, Size = { 18, 2, 18 } },
		attraction_1 = { X = 24, Z = 26, Size = { 18, 6, 18 } },
		attraction_2 = { X = 24, Z = -2, Size = { 14, 14, 14 } },
		attraction_3 = { X = 24, Z = -30, Size = { 18, 10, 14 } },
	},
}
