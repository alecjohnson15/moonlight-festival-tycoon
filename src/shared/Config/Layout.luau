--!strict
-- Map geometry: how many plots there are and where each producer is built on
-- a plot, in studs from the plot's centre. Plain numbers so this file loads in
-- tests as well as in Studio.

return {
	PlotCount = 6,
	PlotSize = 96,
	PlotSpacing = 120,

	-- Where a player stands after being moved to their plot.
	ArrivalOffset = { X = 0, Z = 40 },

	-- Size is { width, height, depth } for the greybox block drawn when the
	-- theme has no model for that upgrade.
	Slots = {
		starter_stall = { X = -24, Z = 24, Size = { 8, 6, 6 } },
		grower = { X = 24, Z = 24, Size = { 16, 2, 16 } },
		kitchen = { X = -24, Z = -8, Size = { 12, 8, 10 } },
		attraction_1 = { X = 24, Z = -8, Size = { 16, 6, 16 } },
		attraction_2 = { X = -24, Z = -36, Size = { 16, 10, 12 } },
		attraction_3 = { X = 24, Z = -36, Size = { 14, 20, 4 } },
	},
}
