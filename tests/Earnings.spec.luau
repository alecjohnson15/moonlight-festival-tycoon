-- The production chain, visitors, attractions and vendors, then the shipped
-- balance: every route through the tree must take about 90 minutes, every
-- purchase must earn something and the next one must never be far off.

local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Earnings = require("../src/shared/Earnings")
local Format = require("../src/shared/Format")
local Progression = require("../src/shared/Progression")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local BALANCE = {
	Items = { snack = { Value = 1 }, raw = { Value = 1 }, cooked = { Value = 5 } },
	BaseVisitorsPerSecond = 2,
	Upgrades = {
		{ Id = "stall", Kind = "Stall", Cost = 0, Makes = "snack", PerSecond = 1 },
		{ Id = "patch", Kind = "Grower", Cost = 10, Makes = "raw", PerSecond = 6, Requires = "stall" },
		{
			Id = "oven",
			Kind = "Kitchen",
			Cost = 20,
			Takes = "raw",
			Makes = "cooked",
			PerSecond = 4,
			Requires = "patch",
		},
		{
			Id = "big_oven",
			Kind = "Boost",
			Cost = 30,
			Target = "oven",
			Multipliers = { PerSecond = 2 },
			Requires = "oven",
		},
		{
			Id = "maze",
			Kind = "Attraction",
			Type = "Walkthrough",
			Cost = 40,
			Draw = 1,
			Capacity = 4,
			Ticket = 10,
			Requires = "stall",
		},
		{ Id = "beacon", Kind = "Attraction", Type = "Showpiece", Cost = 50, Draw = 3, Requires = "stall" },
		{
			Id = "train",
			Kind = "Attraction",
			Type = "Ride",
			Cost = 60,
			Seats = 8,
			RoundSeconds = 5,
			Ticket = 3,
			Requires = "stall",
		},
	},
}

local function set(ids: { string }): { [string]: boolean }
	local result = {}
	for _, id in ids do
		result[id] = true
	end
	return result
end

local function withBase(visitors: number)
	local copy = table.clone(BALANCE)
	copy.BaseVisitorsPerSecond = visitors
	return copy
end

describe("Earnings.chain", function()
	it("sells what the stall makes itself", function()
		local chain = Earnings.chain(set({ "stall" }), BALANCE)
		expect(chain.CoinsPerSecond).toBe(1)
		expect(chain.Selling.snack).toBe(1)
	end)

	it("sells grown goods as they are when there is no kitchen", function()
		local chain = Earnings.chain(set({ "stall", "patch" }), BALANCE)
		expect(chain.Stations.patch.Out).toBe(6)
		expect(chain.CoinsPerSecond).toBe(7)
	end)

	it("cooks what the kitchen has room for and sells the rest as it is", function()
		local chain = Earnings.chain(set({ "stall", "patch", "oven" }), BALANCE)
		local oven = chain.Stations.oven
		expect(oven.In).toBe(4)
		expect(oven.Capacity).toBe(4)
		expect(oven.Overflow).toBe(2)
		expect(chain.Selling.raw).toBe(2)
		expect(chain.Selling.cooked).toBe(4)
		expect(chain.CoinsPerSecond).toBe(1 + 2 + 4 * 5)
	end)

	it("lets a boost multiply its target's rate", function()
		local chain = Earnings.chain(set({ "stall", "patch", "oven", "big_oven" }), BALANCE)
		expect(chain.Stations.oven.Capacity).toBe(8)
		expect(chain.Stations.oven.In).toBe(6)
		expect(chain.Stations.oven.Overflow).toBe(0)
		expect(chain.CoinsPerSecond).toBe(1 + 6 * 5)
	end)

	it("ignores a boost whose station isn't owned", function()
		expect(Earnings.chain(set({ "stall", "big_oven" }), BALANCE).CoinsPerSecond).toBe(1)
	end)

	it("lets a kitchen's Value raise the price of what it cooks", function()
		local balance = table.clone(BALANCE)
		balance.Upgrades = table.clone(BALANCE.Upgrades)
		table.insert(balance.Upgrades, {
			Id = "gold_pies",
			Kind = "Boost",
			Cost = 1,
			Target = "oven",
			Multipliers = { Value = 3 },
			Requires = "oven",
		})
		local chain = Earnings.chain(set({ "stall", "patch", "oven", "gold_pies" }), balance)
		expect(chain.CoinsPerSecond).toBe(1 + 2 + 4 * 5 * 3)
	end)

	it("lets the stall's Markup raise the price of everything it sells", function()
		local balance = table.clone(BALANCE)
		balance.Upgrades = table.clone(BALANCE.Upgrades)
		table.insert(balance.Upgrades, {
			Id = "market",
			Kind = "Boost",
			Cost = 1,
			Target = "stall",
			Multipliers = { Markup = 2 },
			Requires = "stall",
		})
		local chain = Earnings.chain(set({ "stall", "patch", "oven", "market" }), balance)
		expect(chain.CoinsPerSecond).toBe((1 + 2 + 4 * 5) * 2)
	end)

	it("sells nothing without a stall", function()
		local chain = Earnings.chain(set({ "patch" }), BALANCE)
		expect(chain.CoinsPerSecond).toBe(0)
		expect(next(chain.Selling)).toBe(nil)
	end)
end)

describe("Earnings visitors and attractions", function()
	it("adds every owned attraction's draw to the base visitors", function()
		expect(Earnings.visitorsPerSecond(set({ "stall" }), BALANCE)).toBe(2)
		expect(Earnings.visitorsPerSecond(set({ "maze", "beacon", "train" }), BALANCE)).toBe(6)
	end)

	it("lets a walkthrough serve visitors up to its capacity", function()
		expect(Earnings.attractions(set({ "maze" }), BALANCE).maze.CoinsPerSecond).toBe(30)
		local busy = Earnings.attractions(set({ "maze", "beacon" }), BALANCE)
		expect(busy.maze.Visitors).toBe(4)
		expect(busy.maze.CoinsPerSecond).toBe(40)
	end)

	it("earns nothing from a showpiece without a ticket", function()
		expect(Earnings.attractions(set({ "beacon" }), BALANCE).beacon.CoinsPerSecond).toBe(0)
	end)

	it("charges every visitor a showpiece's ticket, however many come", function()
		local balance = table.clone(BALANCE)
		balance.Upgrades = table.clone(BALANCE.Upgrades)
		table.insert(
			balance.Upgrades,
			{ Id = "statue", Kind = "Attraction", Type = "Showpiece", Cost = 1, Draw = 100, Ticket = 2 }
		)
		expect(Earnings.attractions(set({ "statue" }), balance).statue.CoinsPerSecond).toBe((2 + 100) * 2)
	end)

	it("lets boosts raise an attraction's draw, room, seats and ticket", function()
		local balance = table.clone(BALANCE)
		balance.Upgrades = table.clone(BALANCE.Upgrades)
		table.insert(balance.Upgrades, {
			Id = "bigger_maze",
			Kind = "Boost",
			Cost = 1,
			Target = "maze",
			Multipliers = { Draw = 3, Capacity = 2, Ticket = 1.5 },
			Requires = "maze",
		})
		table.insert(balance.Upgrades, {
			Id = "long_train",
			Kind = "Boost",
			Cost = 1,
			Target = "train",
			Multipliers = { Seats = 2 },
			Requires = "train",
		})
		local owned = set({ "maze", "bigger_maze", "train", "long_train" })
		-- 2 base + 3 from the boosted maze.
		expect(Earnings.visitorsPerSecond(owned, balance)).toBe(5)
		local attractions = Earnings.attractions(owned, balance)
		expect(attractions.maze.Visitors).toBe(5)
		expect(attractions.maze.CoinsPerSecond).toBe(5 * 15)
		-- 16 seats now, and 25 visitors arrive each round.
		expect(attractions.train.Visitors).toBe(16 / 5)
		local effective = Earnings.effective(owned, balance)
		expect(effective.train.Seats).toBe(16)
		expect(BALANCE.Upgrades[7].Seats).toBe(8)
	end)

	it("averages a ride's rounds, limited by seats or by arrivals", function()
		-- 2 visitors a second for 5 seconds fills all 8 seats.
		local full = Earnings.attractions(set({ "train" }), BALANCE).train
		expect(full.Visitors).toBe(8 / 5)
		expect(full.CoinsPerSecond).toBe(8 * 3 / 5)
		-- 0.5 a second only brings 2 riders a round.
		local quiet = Earnings.attractions(set({ "train" }), withBase(0.5)).train
		expect(quiet.Visitors).toBe(2 / 5)
	end)

	it("totals the chain and every attraction", function()
		local owned = set({ "stall", "patch", "maze", "train" })
		local expected = Earnings.chain(owned, BALANCE).CoinsPerSecond
			+ Earnings.attractions(owned, BALANCE).maze.CoinsPerSecond
			+ Earnings.attractions(owned, BALANCE).train.CoinsPerSecond
		expect(Earnings.perSecond(owned, BALANCE)).toBe(expected)
	end)
end)

describe("Earnings.vendors", function()
	local function withVendor()
		local balance = table.clone(BALANCE)
		balance.Upgrades = table.clone(BALANCE.Upgrades)
		table.insert(
			balance.Upgrades,
			{ Id = "snacks", Kind = "Vendor", Cost = 1, Target = "stall", Spend = 3, Requires = "stall" }
		)
		table.insert(balance.Upgrades, {
			Id = "big_snacks",
			Kind = "Boost",
			Cost = 1,
			Target = "snacks",
			Multipliers = { Spend = 2 },
			Requires = "snacks",
		})
		table.insert(balance.Upgrades, {
			Id = "market",
			Kind = "Boost",
			Cost = 1,
			Target = "stall",
			Multipliers = { Markup = 2 },
			Requires = "stall",
		})
		return balance
	end

	it("earns Spend from every visitor", function()
		local balance = withVendor()
		expect(Earnings.vendors(set({ "stall", "snacks" }), balance).snacks.CoinsPerSecond).toBe(2 * 3)
		expect(Earnings.vendors(set({ "stall", "snacks", "beacon" }), balance).snacks.CoinsPerSecond).toBe(5 * 3)
	end)

	it("lets boosts raise Spend, and the stall's Markup raise every sale", function()
		local balance = withVendor()
		expect(Earnings.vendors(set({ "stall", "snacks", "big_snacks" }), balance).snacks.CoinsPerSecond).toBe(2 * 6)
		local all = set({ "stall", "snacks", "big_snacks", "market" })
		expect(Earnings.vendors(all, balance).snacks.CoinsPerSecond).toBe(2 * 6 * 2)
		expect(Earnings.perSecond(all, balance)).toBe(1 * 2 + 2 * 6 * 2)
	end)
end)

describe("Earnings.stepRides", function()
	it("pays nothing until a round ends, then pays its riders", function()
		local clocks = {}
		local owned = set({ "stall", "train" })
		expect(#Earnings.stepRides(clocks, owned, BALANCE, 4)).toBe(0)
		local payouts = Earnings.stepRides(clocks, owned, BALANCE, 1)
		expect(payouts).toEqual({ { Id = "train", Riders = 8, Coins = 24 } })
		expect(clocks.train).toBe(0)
	end)

	it("pays once for every round that ended during a long step", function()
		local clocks = {}
		local payouts = Earnings.stepRides(clocks, set({ "train" }), BALANCE, 12)
		expect(#payouts).toBe(2)
		expect(clocks.train).toBe(2)
	end)

	it("fills only as many seats as visitors arrived", function()
		local payouts = Earnings.stepRides({}, set({ "train" }), withBase(0.5), 5)
		expect(payouts[1].Riders).toBe(2)
		expect(payouts[1].Coins).toBe(6)
	end)

	it("pays whole coins when a boost makes the ticket fractional", function()
		local balance = table.clone(BALANCE)
		balance.Upgrades = table.clone(BALANCE.Upgrades)
		table.insert(balance.Upgrades, {
			Id = "scary",
			Kind = "Boost",
			Cost = 1,
			Target = "train",
			Multipliers = { Ticket = 1.5 },
			Requires = "train",
		})
		local owned = set({ "train", "scary" })
		local payouts = Earnings.stepRides({}, owned, withBase(0.5), 5)
		expect(payouts[1].Coins).toBe(6)
		payouts = Earnings.stepRides({}, owned, balance, 5)
		-- 8 riders at 4.5 each.
		expect(payouts[1].Coins).toBe(36)
		local quiet = table.clone(balance)
		quiet.BaseVisitorsPerSecond = 0.2
		-- 1 rider at 4.5 pays 4.
		expect(Earnings.stepRides({}, owned, quiet, 5)[1].Coins).toBe(4)
		expect(Earnings.attractions(owned, quiet).train.CoinsPerSecond).toBe(4 / 5)
	end)

	it("ignores rides the player doesn't own", function()
		local clocks = {}
		expect(#Earnings.stepRides(clocks, set({ "stall" }), BALANCE, 60)).toBe(0)
		expect(clocks.train).toBe(nil)
	end)
end)

describe("Earnings.validate", function()
	it("accepts the test config", function()
		expect(#Earnings.validate(BALANCE)).toBe(0)
	end)

	it("reports each kind's missing or wrong fields", function()
		local problems = Earnings.validate({
			Items = { raw = { Value = 1 }, junk = { Value = 0 } },
			BaseVisitorsPerSecond = 1,
			Upgrades = {
				{ Id = "patch", Kind = "Grower", Cost = 0, Makes = "gold", PerSecond = 0 },
				{ Id = "oven", Kind = "Kitchen", Cost = 1, Takes = "cooked", Makes = "raw", PerSecond = 1 },
				{ Id = "loose", Kind = "Boost", Cost = 1, Target = "patch", Multipliers = { PerSecond = 2 } },
				{
					Id = "silly",
					Kind = "Boost",
					Cost = 1,
					Target = "maze",
					Multipliers = { Seats = 1.5 },
					Requires = "maze",
				},
				{ Id = "empty", Kind = "Boost", Cost = 1, Target = "train", Requires = "train" },
				{
					Id = "half",
					Kind = "Boost",
					Cost = 1,
					Target = "train",
					Multipliers = { Seats = 1.5 },
					Requires = "train",
				},
				{ Id = "lost", Kind = "Boost", Cost = 1, Target = "nowhere", Multipliers = { Ticket = 2 } },
				{ Id = "shy", Kind = "Vendor", Cost = 1, Target = "patch", Spend = 0, Requires = "patch" },
				{ Id = "stray", Kind = "Vendor", Cost = 1, Target = "patch", Spend = 1 },
				{ Id = "maze", Kind = "Attraction", Type = "Walkthrough", Cost = 1, Ticket = 2.5 },
				{ Id = "train", Kind = "Attraction", Type = "Ride", Cost = 1, Ticket = 1 },
				{ Id = "statue", Kind = "Attraction", Type = "Showpiece", Cost = 1, Ticket = 0.5 },
				{ Id = "cloud", Kind = "Attraction", Type = "Cloud", Cost = 1 },
				{ Id = "thing", Kind = "Gadget", Cost = 1 },
			},
		})
		expect(problems).toContain("no stall")
		expect(problems).toContain("item junk: Value must be above 0")
		expect(problems).toContain("patch: makes unknown item gold")
		expect(problems).toContain("patch: needs a positive PerSecond")
		expect(problems).toContain("oven: takes cooked, which no stall or grower makes")
		expect(problems).toContain("loose: boost must require its target")
		expect(problems).toContain("silly: maze has no Seats to boost")
		expect(problems).toContain("empty: boost needs Multipliers")
		expect(problems).toContain("half: Seats multiplier must be whole")
		expect(problems).toContain("lost: boost must target a station, attraction or vendor")
		expect(problems).toContain("shy: vendor needs a positive Spend")
		expect(problems).toContain("stray: vendor must require its target")
		expect(problems).toContain("maze: walkthrough needs a positive Capacity")
		expect(problems).toContain("maze: Ticket must be a whole number")
		expect(problems).toContain("train: ride needs a whole number of Seats")
		expect(problems).toContain("train: ride needs a positive RoundSeconds")
		expect(problems).toContain("statue: showpiece needs a positive Draw")
		expect(problems).toContain("statue: Ticket must be a whole number")
		expect(problems).toContain("cloud: unknown attraction type Cloud")
		expect(problems).toContain("thing: unknown kind Gadget")
	end)
end)

describe("Format.whole", function()
	it("puts commas between thousands", function()
		expect(Format.whole(0)).toBe("0")
		expect(Format.whole(999)).toBe("999")
		expect(Format.whole(1000)).toBe("1,000")
		expect(Format.whole(123456)).toBe("123,456")
		expect(Format.whole(1234567.4)).toBe("1,234,567")
		expect(Format.whole(-4500)).toBe("-4,500")
	end)
end)

describe("Format.short", function()
	it("keeps prices short for pad labels", function()
		expect(Format.short(620)).toBe("620")
		expect(Format.short(6500)).toBe("6,500")
		expect(Format.short(10_000)).toBe("10K")
		expect(Format.short(97_000)).toBe("97K")
		expect(Format.short(460_000)).toBe("460K")
		expect(Format.short(1_100_000)).toBe("1.1M")
		expect(Format.short(1_000_000)).toBe("1M")
		expect(Format.short(16_000_000)).toBe("16M")
		expect(Format.short(140_000_000)).toBe("140M")
		expect(Format.short(2_500_000_000)).toBe("2.5B")
		expect(Format.short(999_950)).toBe("1M")
		expect(Format.short(9_960)).toBe("9,960")
	end)
end)

describe("Format.rate", function()
	it("shows whole numbers bare and anything else to one decimal place", function()
		expect(Format.rate(4)).toBe("4")
		expect(Format.rate(0)).toBe("0")
		expect(Format.rate(2.5)).toBe("2.5")
		expect(Format.rate(2.4999)).toBe("2.5")
		expect(Format.rate(1 / 3)).toBe("0.3")
		expect(Format.rate(12000)).toBe("12000")
	end)
end)

-- The pacing every route through the shipped tree is held to. A route picks
-- one path for every building that forks, and the player buys the cheapest
-- upgrade they can each time, earning only passive income; real players who
-- watch their rides pay out or plan ahead get there sooner.
local PACING = {
	-- The whole tree, on any route.
	MinMinutes = 80,
	MaxMinutes = 100,
	-- The slowest route takes at most this much longer than the fastest, so
	-- no choice of paths is a trap.
	MaxSpread = 1.2,
	-- Waits for the next upgrade: short while players learn the game, and
	-- never long enough to feel stuck.
	EarlyMinutes = 10,
	MaxEarlyWait = 120,
	MaxWait = 300,
	-- Every purchase raises income by at least this much.
	MinGain = 0.05,
}

-- Every combination of one path per forking building.
local function routes(): { { [string]: string } }
	local paths = Progression.paths(Balance.Upgrades)
	local result = { {} }
	for building, byPath in paths do
		local nextResult = {}
		for _, route in result do
			for name in byPath do
				local copy = table.clone(route)
				copy[building] = name
				table.insert(nextResult, copy)
			end
		end
		result = nextResult
	end
	return result
end

type Playthrough = {
	Name: string,
	Seconds: number,
	Waits: { { Id: string, At: number, Wait: number, Gain: number } },
	Owned: { [string]: boolean },
}

local function play(route: { [string]: string }): Playthrough
	local state = { Coins = Balance.StartingCoins, Owned = {} }
	local seconds = 0
	local waits = {}
	while true do
		local available = {}
		for _, upgrade in Progression.available(state.Owned, Balance.Upgrades) do
			if not upgrade.Path or route[upgrade.Building] == upgrade.Path then
				table.insert(available, upgrade)
			end
		end
		if #available == 0 then
			break
		end
		table.sort(available, function(a, b)
			return a.Cost < b.Cost
		end)
		local nextUp = available[1]
		local income = Earnings.perSecond(state.Owned, Balance)
		local wait = if state.Coins >= nextUp.Cost then 0 else (nextUp.Cost - state.Coins) / income
		assert(wait < math.huge, `{nextUp.Id} can never be afforded`)
		seconds += wait
		-- Rounded up so float error can't leave the purchase a hair short.
		state.Coins = math.max(state.Coins + income * wait, nextUp.Cost)
		assert(Progression.purchase(state, Balance.Upgrades, nextUp.Id), `could not buy {nextUp.Id}`)
		local gain = if income > 0 then Earnings.perSecond(state.Owned, Balance) / income - 1 else math.huge
		table.insert(waits, { Id = nextUp.Id, At = seconds, Wait = wait, Gain = gain })
	end
	local names = {}
	for building, path in route do
		table.insert(names, `{building}:{path}`)
	end
	table.sort(names)
	return { Name = table.concat(names, " "), Seconds = seconds, Waits = waits, Owned = state.Owned }
end

describe("shipped balance", function()
	it("passes validation", function()
		local problems = Earnings.validate(Balance)
		expect(#problems).toBe(0)
		expect(#Progression.validate(Balance.Upgrades)).toBe(0)
	end)

	it("forks every building into two or three paths of four tiers", function()
		local paths = Progression.paths(Balance.Upgrades)
		for _, upgrade in Balance.Upgrades do
			if not upgrade.Building then
				local byPath = paths[upgrade.Id]
				assert(byPath, `{upgrade.Id} has no paths`)
				local count = 0
				for name, tiers in byPath do
					count += 1
					assert(#tiers == 4, `{upgrade.Id} path {name} has {#tiers} tiers`)
				end
				assert(count == 2 or count == 3, `{upgrade.Id} has {count} paths`)
			end
		end
	end)

	local playthroughs = {}
	for _, route in routes() do
		table.insert(playthroughs, play(route))
	end

	it("lets every route buy everything on it, and nothing on other paths", function()
		for _, run in playthroughs do
			local chosen = Progression.chosenPaths(run.Owned, Balance.Upgrades)
			for _, upgrade in Balance.Upgrades do
				local onRoute = not upgrade.Path or chosen[upgrade.Building] == upgrade.Path
				assert(run.Owned[upgrade.Id] == (onRoute or nil), `{run.Name}: {upgrade.Id} bought wrongly`)
			end
		end
	end)

	it("takes every route 80 to 100 minutes, within a fifth of each other", function()
		local fastest, slowest = playthroughs[1], playthroughs[1]
		for _, run in playthroughs do
			local minutes = run.Seconds / 60
			assert(minutes >= PACING.MinMinutes, `{run.Name} takes only {math.floor(minutes)} minutes`)
			assert(minutes <= PACING.MaxMinutes, `{run.Name} takes {math.ceil(minutes)} minutes`)
			fastest = if run.Seconds < fastest.Seconds then run else fastest
			slowest = if run.Seconds > slowest.Seconds then run else slowest
		end
		print(
			`  {#playthroughs} routes, {math.floor(fastest.Seconds / 60)} to {math.ceil(slowest.Seconds / 60)} minutes`
		)
		assert(
			slowest.Seconds <= fastest.Seconds * PACING.MaxSpread,
			`{slowest.Name} takes far longer than {fastest.Name}`
		)
	end)

	it("keeps every next upgrade close: 2 minutes early on, 5 at most", function()
		for _, run in playthroughs do
			for _, step in run.Waits do
				local early = step.At - step.Wait < PACING.EarlyMinutes * 60
				local limit = if early then PACING.MaxEarlyWait else PACING.MaxWait
				assert(step.Wait <= limit, `{run.Name}: {step.Id} takes {math.ceil(step.Wait)} seconds to afford`)
			end
		end
	end)

	it("makes every purchase on every route raise income by at least 5%", function()
		for _, run in playthroughs do
			for _, step in run.Waits do
				assert(step.Gain >= PACING.MinGain, `{run.Name}: {step.Id} adds only {math.floor(step.Gain * 100)}%`)
			end
		end
	end)
end)

return nil
