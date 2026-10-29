-- Every number that shapes progression. Ids are theme-neutral; player-facing
-- names come from the active theme pack (see Config/Theme). docs/progression.md
-- explains the tree and the pacing, and tests/Earnings.spec.luau holds every
-- route through it to that pacing.
--
-- The production chain: growers make raw goods, kitchens turn raw goods into
-- cooked ones, and the stall sells everything that reaches it, plus what it
-- makes itself. Attractions and vendors earn from visitors instead.
--
-- Kinds:
--   Stall       sells the chain's goods and makes PerSecond of Makes itself.
--   Grower      makes PerSecond of Makes and sends them to the stall.
--   Kitchen     turns up to PerSecond of Takes into Makes, one for one. Goods
--               it has no room for go to the stall as they are.
--   Attraction  earns from visitors. Every attraction adds Draw visitors per
--               second to the plot, and every visitor visits each one. By Type:
--                 Walkthrough  lets in up to Capacity visitors per second,
--                              each paying Ticket.
--                 Ride         every RoundSeconds, seats up to Seats of the
--                              visitors who arrived and pays Ticket per rider.
--                 Showpiece    every visitor pays Ticket to see it, however
--                              many there are.
--   Vendor      sells to every visitor: earns Spend per visitor. It trades
--               from its Target building, where it is drawn.
--   Boost       multiplies stats of its Target by Multipliers. What each kind
--               can have boosted:
--                 Stall        PerSecond, and Markup: the price of everything
--                              sold on the plot, goods and vendor sales alike.
--                 Grower       PerSecond.
--                 Kitchen      PerSecond, and Value: the price of what it cooks.
--                 Vendor       Spend.
--                 Walkthrough  Draw, Capacity, Ticket.
--                 Ride         Draw, Seats (by whole numbers), Ticket.
--                 Showpiece    Draw, Ticket.
--
-- The tree: each building is followed by two shared upgrades everyone buys,
-- then forks into two or three paths of four tiers. Every upgrade except a
-- building names its Building, and path tiers name their Path. Buying the
-- first tier of one path locks the building's other paths for good.

local Upgrades = {}

-- A building and its two shared upgrades, which are Boosts on it, each
-- requiring the one before.
local function building(spec, shared)
	table.insert(Upgrades, spec)
	local requires = spec.Id
	for _, upgrade in shared do
		upgrade.Kind = "Boost"
		upgrade.Target = spec.Id
		upgrade.Building = spec.Id
		upgrade.Requires = requires
		table.insert(Upgrades, upgrade)
		requires = upgrade.Id
	end
end

-- One path of a building: its tiers in the order they're bought, the first
-- after the upgrade named by after. Ids are prefix_name_tier. A tier with
-- Spend is a Vendor trading from the building, and the tiers after it boost
-- that vendor; every other tier is a Boost on the building.
local function path(buildingId: string, prefix: string, name: string, after: string, tiers)
	local target, requires = buildingId, after
	for index, tier in tiers do
		local id = prefix .. "_" .. name .. "_" .. index
		tier.Id = id
		tier.Building = buildingId
		tier.Path = name
		tier.Requires = requires
		if tier.Spend then
			tier.Kind = "Vendor"
			tier.Target = buildingId
			target = id
		else
			tier.Kind = "Boost"
			tier.Target = target
		end
		table.insert(Upgrades, tier)
		requires = id
	end
end

-- The stall: free, and the first paid upgrade is affordable within a minute.
building({ Id = "starter_stall", Kind = "Stall", Cost = 0, Makes = "handmade", PerSecond = 1 }, {
	{ Id = "stall_counter", Cost = 15, Multipliers = { PerSecond = 2 } },
	{ Id = "stall_boost_2", Cost = 150, Multipliers = { PerSecond = 2.5 } },
})
-- Makes far more of its own goods.
path("starter_stall", "stall", "output", "stall_boost_2", {
	{ Cost = 620, Multipliers = { PerSecond = 5 } },
	{ Cost = 10_000, Multipliers = { PerSecond = 6 } },
	{ Cost = 100_000, Multipliers = { PerSecond = 5 } },
	{ Cost = 1_100_000, Multipliers = { PerSecond = 6 } },
})
-- Sells snacks to every visitor.
path("starter_stall", "stall", "vendor", "stall_boost_2", {
	{ Cost = 620, Spend = 8 },
	{ Cost = 10_000, Multipliers = { Spend = 8 } },
	{ Cost = 100_000, Multipliers = { Spend = 3 } },
	{ Cost = 1_100_000, Multipliers = { Spend = 2 } },
})
-- Raises the price of everything sold on the plot.
path("starter_stall", "stall", "markup", "stall_boost_2", {
	{ Cost = 620, Multipliers = { PerSecond = 1.2, Markup = 1.2 } },
	{ Cost = 10_000, Multipliers = { PerSecond = 1.2, Markup = 1.2 } },
	{ Cost = 100_000, Multipliers = { PerSecond = 1.2, Markup = 1.2 } },
	{ Cost = 1_100_000, Multipliers = { PerSecond = 1.2, Markup = 1.2 } },
})

building({ Id = "grower", Kind = "Grower", Cost = 53, Makes = "raw", PerSecond = 2, Requires = "starter_stall" }, {
	{ Id = "grower_boost", Cost = 330, Multipliers = { PerSecond = 3 } },
	{ Id = "grower_boost_2", Cost = 2_500, Multipliers = { PerSecond = 4 } },
})
-- Grows far more, for the kitchen and the stall.
path("grower", "grower", "output", "grower_boost_2", {
	{ Cost = 6_500, Multipliers = { PerSecond = 3 } },
	{ Cost = 73_000, Multipliers = { PerSecond = 4 } },
	{ Cost = 850_000, Multipliers = { PerSecond = 6 } },
	{ Cost = 6_400_000, Multipliers = { PerSecond = 6 } },
})
-- Visitors pay to pick their own.
path("grower", "grower", "vendor", "grower_boost_2", {
	{ Cost = 6_500, Spend = 20 },
	{ Cost = 73_000, Multipliers = { Spend = 4 } },
	{ Cost = 850_000, Multipliers = { Spend = 2 } },
	{ Cost = 6_400_000, Multipliers = { Spend = 3 } },
})

building({
	Id = "kitchen",
	Kind = "Kitchen",
	Cost = 1_300,
	Takes = "raw",
	Makes = "cooked",
	PerSecond = 6,
	Requires = "grower",
}, {
	{ Id = "kitchen_boost", Cost = 4_300, Multipliers = { PerSecond = 1.5, Value = 1.5 } },
	{ Id = "kitchen_boost_2", Cost = 18_000, Multipliers = { PerSecond = 1.5, Value = 1.5 } },
})
-- Each cooked good is worth far more.
path("kitchen", "kitchen", "value", "kitchen_boost_2", {
	{ Cost = 35_000, Multipliers = { Value = 2.5 } },
	{ Cost = 460_000, Multipliers = { Value = 5 } },
	{ Cost = 4_000_000, Multipliers = { Value = 6 } },
	{ Cost = 24_000_000, Multipliers = { Value = 6 } },
})
-- A café that sells to every visitor.
path("kitchen", "kitchen", "vendor", "kitchen_boost_2", {
	{ Cost = 35_000, Spend = 40 },
	{ Cost = 460_000, Multipliers = { Spend = 3 } },
	{ Cost = 4_000_000, Multipliers = { Spend = 3 } },
	{ Cost = 24_000_000, Multipliers = { Spend = 4 } },
})

building({
	Id = "attraction_1",
	Kind = "Attraction",
	Type = "Walkthrough",
	Cost = 25_000,
	Draw = 1,
	Capacity = 20,
	Ticket = 25,
	Requires = "kitchen",
}, {
	{ Id = "attraction_1_boost", Cost = 52_000, Multipliers = { Ticket = 4 } },
	{ Id = "attraction_1_boost_2", Cost = 140_000, Multipliers = { Draw = 2.5, Capacity = 2.5 } },
})
-- Bigger: lets in and draws more visitors.
path("attraction_1", "attraction_1", "capacity", "attraction_1_boost_2", {
	{ Cost = 360_000, Multipliers = { Draw = 1.2, Capacity = 1.5, Ticket = 1.5 } },
	{ Cost = 1_900_000, Multipliers = { Draw = 1.5, Capacity = 2, Ticket = 2 } },
	{ Cost = 8_000_000, Multipliers = { Draw = 1.5, Capacity = 2.5, Ticket = 2.5 } },
	{ Cost = 31_000_000, Multipliers = { Draw = 1.5, Capacity = 2.5, Ticket = 2.5 } },
})
-- Scarier: every visitor pays more.
path("attraction_1", "attraction_1", "ticket", "attraction_1_boost_2", {
	{ Cost = 360_000, Multipliers = { Ticket = 2 } },
	{ Cost = 1_900_000, Multipliers = { Ticket = 2.5 } },
	{ Cost = 8_000_000, Multipliers = { Ticket = 2.5 } },
	{ Cost = 31_000_000, Multipliers = { Ticket = 3 } },
})

building({
	Id = "attraction_2",
	Kind = "Attraction",
	Type = "Showpiece",
	Cost = 200_000,
	Draw = 4,
	Ticket = 20,
	Requires = "attraction_1",
}, {
	{ Id = "attraction_2_boost", Cost = 610_000, Multipliers = { Draw = 2 } },
	{ Id = "attraction_2_boost_2", Cost = 1_500_000, Multipliers = { Ticket = 12 } },
})
-- Draws bigger crowds to the whole plot.
path("attraction_2", "attraction_2", "draw", "attraction_2_boost_2", {
	{ Cost = 3_200_000, Multipliers = { Draw = 1.2, Ticket = 1.5 } },
	{ Cost = 13_000_000, Multipliers = { Draw = 1.5, Ticket = 2 } },
	{ Cost = 40_000_000, Multipliers = { Draw = 1.5, Ticket = 2 } },
	{ Cost = 74_000_000, Multipliers = { Draw = 1.5, Ticket = 2 } },
})
-- Every visitor pays more to see it.
path("attraction_2", "attraction_2", "ticket", "attraction_2_boost_2", {
	{ Cost = 3_200_000, Multipliers = { Ticket = 2.5 } },
	{ Cost = 13_000_000, Multipliers = { Ticket = 3 } },
	{ Cost = 40_000_000, Multipliers = { Ticket = 2.5 } },
	{ Cost = 74_000_000, Multipliers = { Ticket = 2 } },
})

building({
	Id = "attraction_3",
	Kind = "Attraction",
	Type = "Ride",
	Cost = 2_500_000,
	Draw = 2,
	Seats = 60,
	RoundSeconds = 10,
	Ticket = 400,
	Requires = "attraction_2",
}, {
	{ Id = "attraction_3_boost", Cost = 5_100_000, Multipliers = { Ticket = 4 } },
	{ Id = "attraction_3_boost_2", Cost = 10_000_000, Multipliers = { Draw = 2, Seats = 2 } },
})
-- Longer trains for bigger crowds.
path("attraction_3", "attraction_3", "seats", "attraction_3_boost_2", {
	{ Cost = 16_000_000, Multipliers = { Draw = 1.5, Seats = 2, Ticket = 2 } },
	{ Cost = 51_000_000, Multipliers = { Draw = 1.5, Seats = 2, Ticket = 2 } },
	{ Cost = 97_000_000, Multipliers = { Draw = 1.5, Seats = 2, Ticket = 2 } },
	{ Cost = 140_000_000, Multipliers = { Draw = 1.5, Seats = 2, Ticket = 2 } },
})
-- Scarier: every rider pays more.
path("attraction_3", "attraction_3", "ticket", "attraction_3_boost_2", {
	{ Cost = 16_000_000, Multipliers = { Ticket = 3 } },
	{ Cost = 51_000_000, Multipliers = { Ticket = 3 } },
	{ Cost = 97_000_000, Multipliers = { Ticket = 2 } },
	{ Cost = 140_000_000, Multipliers = { Ticket = 2 } },
})
-- Parades round the festival, pulling in visitors for everything.
path("attraction_3", "attraction_3", "draw", "attraction_3_boost_2", {
	{ Cost = 16_000_000, Multipliers = { Draw = 1.5, Ticket = 2.5 } },
	{ Cost = 51_000_000, Multipliers = { Draw = 1.5, Ticket = 3 } },
	{ Cost = 97_000_000, Multipliers = { Draw = 1.5, Ticket = 2 } },
	{ Cost = 140_000_000, Multipliers = { Draw = 1.5, Ticket = 2 } },
})

return {
	StartingCoins = 0,
	IncomeTickSeconds = 1,

	-- What each good sells for at the stall, before Markup and Value boosts.
	Items = {
		handmade = { Value = 1 },
		raw = { Value = 1 },
		cooked = { Value = 3 },
	},

	-- Visitors a plot gets before it has any attractions.
	BaseVisitorsPerSecond = 1,

	Upgrades = Upgrades,
}
