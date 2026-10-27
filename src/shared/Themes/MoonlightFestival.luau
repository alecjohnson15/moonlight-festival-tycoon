--!strict
-- Theme pack for the working concept. Every player-facing name, colour and
-- model choice lives here, so switching to a different 2027 theme means adding
-- a file in this folder and pointing Config/Theme at it. Colours are hex
-- strings so the file stays plain data.
--
-- Model is the name of a model under ReplicatedStorage.Assets. Until art
-- exists, upgrades without a model are drawn as greybox blocks.

return {
	Name = "Moonlight Festival",

	Strings = {
		PlotOwner = "%s's Festival",
		ClaimGate = "Touch to claim",
		ClaimHint = "Walk into a free gate to claim your festival",
		Coins = "Coins",
		IncomePerSecond = "+%d / sec",
		VisitorsPerSecond = "%s visitors / sec",
		UpgradeGain = "+%s / sec",
		Free = "Free",

		-- Labels over the stations and attractions on a plot.
		StallSelling = "Selling %s / sec",
		StationMaking = "%s %s / sec",
		KitchenFull = "%s (full)",
		WalkthroughVisitors = "%s visitors / sec",
		ShowpieceDraw = "Draws %s visitors / sec",
		RideRound = "%s riders every %s sec",
		RideNext = "Next ride in %s",
		Payout = "+%s",
	},

	-- The goods in the production chain, named as a plural for rate labels.
	Items = {
		handmade = { DisplayName = "Toffee Apples", Color = "#C0392B" },
		raw = { DisplayName = "Pumpkins", Color = "#E67E22" },
		cooked = { DisplayName = "Pumpkin Pies", Color = "#D9A35B" },
	},

	-- Clothes colours for the visitors walking around plots.
	VisitorColors = { "#5B7DB1", "#9B8EC4", "#4FA37A", "#D9644A", "#E8C547", "#3E8E9E" },

	Upgrades = {
		starter_stall = { DisplayName = "Snack Stall", Color = "#E8A33D" },
		stall_counter = { DisplayName = "Bigger Counter", Color = "#C98A2E" },
		grower = { DisplayName = "Pumpkin Patch", Color = "#E07B24" },
		kitchen = { DisplayName = "Pie Kitchen", Color = "#B5651D" },
		grower_boost = { DisplayName = "Moonlit Sprinklers", Color = "#6C8EBF" },
		kitchen_boost = { DisplayName = "Second Oven", Color = "#A0522D" },
		attraction_1 = { DisplayName = "Lantern Maze", Color = "#F2C94C" },
		attraction_2 = { DisplayName = "Great Glowing Pumpkin", Color = "#FF9F43" },
		attraction_3 = { DisplayName = "Friendly Ghost Train", Color = "#9B8EC4" },
	},
}
