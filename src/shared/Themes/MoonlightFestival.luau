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
		ServeAction = "Serve visitor",
		Coins = "Coins",
		IncomePerSecond = "+%d / sec",
		Free = "Free",
		TooExpensive = "Not enough coins yet",
		TooFast = "One moment...",
		NotLoaded = "Still loading your festival",
	},

	Upgrades = {
		starter_stall = { DisplayName = "Snack Stall", Color = "#E8A33D" },
		stall_counter = { DisplayName = "Bigger Counter", Color = "#C98A2E" },
		grower = { DisplayName = "Pumpkin Patch", Color = "#E07B24" },
		kitchen = { DisplayName = "Pie Kitchen", Color = "#B5651D" },
		grower_boost = { DisplayName = "Moonlit Sprinklers", Color = "#6C8EBF" },
		attraction_1 = { DisplayName = "Lantern Maze", Color = "#F2C94C" },
		attraction_2 = { DisplayName = "Friendly Ghost Train", Color = "#9B8EC4" },
		attraction_3 = { DisplayName = "Starlight Wheel", Color = "#5B7DB1" },
	},
}
