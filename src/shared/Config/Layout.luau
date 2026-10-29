--!strict
-- Map geometry: how many plots there are and where each plot's gate, buy
-- buttons, stations and attractions go, in studs from the plot's centre. Plain
-- numbers so this file loads in tests as well as in Studio.
--
-- The plot's front (+Z) faces the plaza. The production chain runs down the
-- left side towards the stall at the front, and attractions fill the right.

local PLOT_COUNT = 6
local PLOT_SPACING = 120
-- Extra room between the middle two plots for the arrival courtyard, which
-- players see straight ahead when they spawn on the plaza.
local COURTYARD_GAP = 36

-- The X of plot index's centre. The plots stand in a row along the plaza,
-- centred on X = 0, with the courtyard's extra room in the middle of the row.
local function plotX(index: number): number
	local x = (index - (PLOT_COUNT + 1) / 2) * PLOT_SPACING
	return x + math.sign(x) * COURTYARD_GAP / 2
end

return {
	PlotCount = PLOT_COUNT,
	PlotSize = 96,
	PlotSpacing = PLOT_SPACING,
	CourtyardGap = COURTYARD_GAP,
	plotX = plotX,
	-- The plaza runs along the front of the row, end to end.
	PlazaWidth = PLOT_COUNT * PLOT_SPACING + COURTYARD_GAP,
	PlazaDepth = 40,

	-- Where a player stands after being moved to their plot.
	ArrivalOffset = { X = 0, Z = 40 },

	-- The gate across the front of each plot. Touching an unowned gate claims
	-- the plot; once claimed it turns see-through and lets anyone walk in.
	-- Size is { width, height, depth }.
	Gate = { X = 0, Z = 46, Size = { 14, 8, 1 } },

	-- Buy buttons on the plot floor. A button shows once its requirement is
	-- owned, and stepping on it buys the upgrade. Each building has three
	-- kinds of spot, in plot-local studs: Build buys the building itself;
	-- Upgrades holds its shared upgrades, one after another; and each of its
	-- Paths has a spot that holds that path's tiers, one after another. The
	-- path spots sit in a row in front of the building, so the choice shows
	-- as two or three pads side by side. After a pad is bought, the next one
	-- on the same spot only works once the owner has stepped off. The first
	-- step on a path's first pad only previews the path, and a second step
	-- within ConfirmSeconds picks it.
	ButtonSize = 5,
	ConfirmSeconds = 12,
	Buttons = {
		starter_stall = {
			Build = { X = -12, Z = 26 },
			Upgrades = { X = -12, Z = 18 },
			Paths = {
				output = { X = -30, Z = 36 },
				vendor = { X = -22, Z = 36 },
				markup = { X = -14, Z = 36 },
			},
		},
		kitchen = {
			Build = { X = -12, Z = -2 },
			Upgrades = { X = -12, Z = 6 },
			Paths = {
				value = { X = -29, Z = 12 },
				vendor = { X = -21, Z = 12 },
			},
		},
		grower = {
			Build = { X = -12, Z = -28 },
			Upgrades = { X = -12, Z = -20 },
			Paths = {
				output = { X = -29, Z = -13 },
				vendor = { X = -21, Z = -13 },
			},
		},
		attraction_1 = {
			Build = { X = 10, Z = 26 },
			Upgrades = { X = 10, Z = 18 },
			Paths = {
				capacity = { X = 20, Z = 40 },
				ticket = { X = 28, Z = 40 },
			},
		},
		attraction_2 = {
			Build = { X = 10, Z = -2 },
			Upgrades = { X = 10, Z = 6 },
			Paths = {
				draw = { X = 20, Z = 11 },
				ticket = { X = 28, Z = 11 },
			},
		},
		attraction_3 = {
			Build = { X = 10, Z = -30 },
			Upgrades = { X = 10, Z = -22 },
			Paths = {
				seats = { X = 16, Z = -16 },
				ticket = { X = 24, Z = -16 },
				draw = { X = 32, Z = -16 },
			},
		},
	},

	-- Ghost Catcher's booth (Config/Activity), at the back of the walkway and
	-- facing the gate, and the pad in front of it that starts a round. Size
	-- is { width, height, depth }, as for Slots.
	Activity = { X = -1, Z = -40, Size = { 12, 8, 6 }, Pad = { X = -1, Z = -33 } },

	-- The owner's own festival (Config/Festival). Decor holds the spots
	-- round the edge of the plot for decorations, each DecorSize studs
	-- square and up to DecorHeight tall, facing into the plot; Board is
	-- where the owner picks the festival's name, colours and decorations,
	-- and Shelf is where their trophies go, either side of Ghost Catcher's
	-- booth and facing the gate. Sizes are { width, height, depth }.
	Decor = {
		{ X = -40, Z = 40 },
		{ X = 40, Z = 40 },
		{ X = -40, Z = -41.5 },
		{ X = 40, Z = -41.5 },
		{ X = -40, Z = 4 },
		{ X = 40, Z = -12 },
	},
	DecorSize = 7,
	DecorHeight = 10,
	Board = { X = -11, Z = -41, Size = { 4, 6, 2 } },
	Shelf = { X = 10, Z = -41, Size = { 6, 6, 2.5 } },

	-- Where each station and attraction is built. Size is { width, height,
	-- depth }: the theme's model fits inside it, and it is the size of the
	-- greybox block drawn when the theme has no model for that upgrade. A
	-- Yard beside a building is open ground for the things its upgrades add.
	Slots = {
		starter_stall = {
			X = -26,
			Z = 26,
			Size = { 12, 8, 8 },
			Yard = { X = -36, Z = 26, Size = { 8, 8, 8 } },
		},
		kitchen = { X = -26, Z = -2, Size = { 14, 10, 12 } },
		grower = {
			X = -26,
			Z = -28,
			Size = { 18, 3, 18 },
			Yard = { X = -39, Z = -28, Size = { 8, 3, 18 } },
		},
		attraction_1 = { X = 24, Z = 26, Size = { 18, 6, 18 } },
		attraction_2 = { X = 24, Z = -2, Size = { 14, 14, 14 } },
		attraction_3 = { X = 24, Z = -30, Size = { 20, 10, 16 } },
	},
}
