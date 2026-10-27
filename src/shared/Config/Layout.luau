--!strict
-- Map geometry: how many plots there are and where each plot's gate, buy
-- buttons, stations and attractions go, in studs from the plot's centre. Plain
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

	-- The gate across the front of each plot. Touching an unowned gate claims
	-- the plot; once claimed it turns see-through and lets anyone walk in.
	-- Size is { width, height, depth }.
	Gate = { X = 0, Z = 46, Size = { 14, 8, 1 } },

	-- Buy buttons on the plot floor, one per upgrade. A button shows once its
	-- requirement is owned, and stepping on it buys the upgrade. Each sits
	-- beside what it builds, along a walkway down the middle of the plot.
	ButtonSize = 5,
	Buttons = {
		starter_stall = { X = -12, Z = 26 },
		stall_counter = { X = -12, Z = 18 },
		kitchen_boost = { X = -12, Z = 6 },
		kitchen = { X = -12, Z = -2 },
		grower_boost = { X = -12, Z = -20 },
		grower = { X = -12, Z = -28 },
		attraction_1 = { X = 10, Z = 26 },
		attraction_2 = { X = 10, Z = -2 },
		attraction_3 = { X = 10, Z = -30 },
	},

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
