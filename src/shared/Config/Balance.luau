-- Every number that shapes progression. Values are first guesses for
-- playtesting, not a tuned economy. Ids are theme-neutral; player-facing names
-- come from the active theme pack (see Config/Theme).
--
-- The production chain: growers make raw goods, kitchens turn raw goods into
-- cooked ones, and the stall sells everything that reaches it, plus what it
-- makes itself. Attractions earn from visitors instead (see Earnings).
--
-- Kinds:
--   Stall       sells the chain's goods and makes PerSecond of Makes itself.
--   Grower      makes PerSecond of Makes and sends them to the stall.
--   Kitchen     turns up to PerSecond of Takes into Makes, one for one. Goods
--               it has no room for go to the stall as they are.
--   Boost       multiplies a Stall, Grower or Kitchen's PerSecond by Multiplier.
--   Attraction  earns from visitors. Every attraction adds Draw visitors per
--               second to the plot. By Type:
--                 Walkthrough  lets in up to Capacity visitors per second,
--                              each paying Ticket.
--                 Ride         every RoundSeconds, seats up to Seats of the
--                              visitors who arrived and pays Ticket per rider.
--                 Showpiece    free to visit; its Draw is how it earns.

return {
	StartingCoins = 0,
	IncomeTickSeconds = 1,

	-- What each good sells for at the stall.
	Items = {
		handmade = { Value = 1 },
		raw = { Value = 1 },
		cooked = { Value = 4 },
	},

	-- Visitors a plot gets before it has any attractions.
	BaseVisitorsPerSecond = 1,

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
		{ Id = "starter_stall", Kind = "Stall", Cost = 0, Makes = "handmade", PerSecond = 1 },
		{ Id = "stall_counter", Kind = "Boost", Cost = 15, Target = "starter_stall", Multiplier = 2, Requires = "starter_stall" },
		{ Id = "grower", Kind = "Grower", Cost = 60, Makes = "raw", PerSecond = 4, Requires = "starter_stall" },
		{ Id = "kitchen", Kind = "Kitchen", Cost = 250, Takes = "raw", Makes = "cooked", PerSecond = 4, Requires = "grower" },
		{ Id = "grower_boost", Kind = "Boost", Cost = 300, Target = "grower", Multiplier = 2, Requires = "kitchen" },
		{ Id = "kitchen_boost", Kind = "Boost", Cost = 600, Target = "kitchen", Multiplier = 2, Requires = "grower_boost" },
		{
			Id = "attraction_1",
			Kind = "Attraction",
			Type = "Walkthrough",
			Cost = 1200,
			Draw = 1,
			Capacity = 10,
			Ticket = 15,
			Requires = "kitchen",
		},
		{ Id = "attraction_2", Kind = "Attraction", Type = "Showpiece", Cost = 4000, Draw = 4, Requires = "attraction_1" },
		{
			Id = "attraction_3",
			Kind = "Attraction",
			Type = "Ride",
			Cost = 12000,
			Draw = 2,
			Seats = 40,
			RoundSeconds = 10,
			Ticket = 30,
			Requires = "attraction_2",
		},
	},
}
