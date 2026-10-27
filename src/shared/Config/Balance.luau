-- Every number that shapes progression. Values are first guesses for
-- playtesting, not a tuned economy. Ids are theme-neutral; player-facing names
-- come from the active theme pack (see Config/Theme).
--
-- Kinds:
--   Producer  earns IncomePerSecond once owned and is built on the plot.
--   Boost     multiplies one producer's income by Multiplier.

return {
	StartingCoins = 0,
	IncomeTickSeconds = 1,

	-- The hands-on task on the starter stall: a small reward with a cooldown
	-- so tapping it helps early on without replacing passive income.
	ServeTask = {
		UpgradeId = "starter_stall",
		Reward = 5,
		CooldownSeconds = 2,
	},

	-- Listed in the order players unlock them. The first paid upgrade should be
	-- affordable within the first minute from the free stall plus serving.
	Upgrades = {
		{ Id = "starter_stall", Kind = "Producer", Cost = 0, IncomePerSecond = 1 },
		{ Id = "stall_counter", Kind = "Boost", Cost = 15, Target = "starter_stall", Multiplier = 2, Requires = "starter_stall" },
		{ Id = "grower", Kind = "Producer", Cost = 60, IncomePerSecond = 4, Requires = "starter_stall" },
		{ Id = "kitchen", Kind = "Producer", Cost = 250, IncomePerSecond = 12, Requires = "grower" },
		{ Id = "grower_boost", Kind = "Boost", Cost = 500, Target = "grower", Multiplier = 2, Requires = "grower" },
		{ Id = "attraction_1", Kind = "Producer", Cost = 1200, IncomePerSecond = 30, Requires = "kitchen" },
		{ Id = "attraction_2", Kind = "Producer", Cost = 4000, IncomePerSecond = 70, Requires = "attraction_1" },
		{ Id = "attraction_3", Kind = "Producer", Cost = 12000, IncomePerSecond = 160, Requires = "attraction_2" },
	},
}
