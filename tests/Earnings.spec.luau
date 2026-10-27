-- The production chain, visitors and attractions, then the shipped balance:
-- every upgrade must earn something and the next one must never be far off.

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
		{ Id = "oven", Kind = "Kitchen", Cost = 20, Takes = "raw", Makes = "cooked", PerSecond = 4, Requires = "patch" },
		{ Id = "big_oven", Kind = "Boost", Cost = 30, Target = "oven", Multiplier = 2, Requires = "oven" },
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

	it("earns nothing from a showpiece directly", function()
		expect(Earnings.attractions(set({ "beacon" }), BALANCE).beacon.CoinsPerSecond).toBe(0)
	end)

	it("averages a ride's rounds, limited by seats or by arrivals", function()
		-- 2 visitors a second for 5 seconds fills all 8 seats.
		local full = Earnings.attractions(set({ "train" }), BALANCE).train
		expect(full.Visitors).toBe(8 / 5)
		expect(full.CoinsPerSecond).toBe(8 / 5 * 3)
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
				{ Id = "loose", Kind = "Boost", Cost = 1, Target = "patch", Multiplier = 2 },
				{ Id = "silly", Kind = "Boost", Cost = 1, Target = "maze", Multiplier = 1, Requires = "maze" },
				{ Id = "maze", Kind = "Attraction", Type = "Walkthrough", Cost = 1, Ticket = 2.5 },
				{ Id = "train", Kind = "Attraction", Type = "Ride", Cost = 1, Ticket = 1 },
				{ Id = "statue", Kind = "Attraction", Type = "Showpiece", Cost = 1 },
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
		expect(problems).toContain("silly: boost must target a stall, grower or kitchen")
		expect(problems).toContain("silly: boost needs a Multiplier above 1")
		expect(problems).toContain("maze: walkthrough needs a positive Capacity")
		expect(problems).toContain("maze: Ticket must be a whole number")
		expect(problems).toContain("train: ride needs a whole number of Seats")
		expect(problems).toContain("train: ride needs a positive RoundSeconds")
		expect(problems).toContain("statue: showpiece needs a positive Draw")
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

-- Everything an upgrade needs before it can be bought, plus the upgrade.
local function withRequirements(id: string): { [string]: boolean }
	local owned = {}
	local current = Progression.find(Balance.Upgrades, id)
	while current do
		owned[current.Id] = true
		current = current.Requires and Progression.find(Balance.Upgrades, current.Requires)
	end
	return owned
end

describe("shipped balance", function()
	it("passes validation", function()
		local problems = Earnings.validate(Balance)
		expect(#problems).toBe(0)
	end)

	it("makes every upgrade add income as soon as it can be bought", function()
		for _, upgrade in Balance.Upgrades do
			local after = withRequirements(upgrade.Id)
			local before = table.clone(after)
			before[upgrade.Id] = nil
			local gain = Earnings.perSecond(after, Balance) - Earnings.perSecond(before, Balance)
			assert(gain > 0, `{upgrade.Id} adds nothing when first available`)
		end
	end)

	it("keeps every next upgrade within two minutes of passive income", function()
		-- Buys the cheapest available upgrade each time, earning only passive
		-- income: no serving, so real players get there sooner.
		local state = { Coins = Balance.StartingCoins, Owned = {} }
		local seconds = 0
		while true do
			local available = Progression.available(state.Owned, Balance.Upgrades)
			if #available == 0 then
				break
			end
			table.sort(available, function(a, b)
				return a.Cost < b.Cost
			end)
			local nextUp = available[1]
			local income = Earnings.perSecond(state.Owned, Balance)
			local wait = if state.Coins >= nextUp.Cost then 0 else (nextUp.Cost - state.Coins) / income
			assert(wait <= 120, `{nextUp.Id} takes {math.ceil(wait)} seconds to afford`)
			seconds += wait
			-- Rounded up so float error can't leave the purchase a hair short.
			state.Coins = math.max(state.Coins + income * wait, nextUp.Cost)
			assert(Progression.purchase(state, Balance.Upgrades, nextUp.Id), `could not buy {nextUp.Id}`)
		end
		for _, upgrade in Balance.Upgrades do
			assert(state.Owned[upgrade.Id], `{upgrade.Id} was never bought`)
		end
		-- The whole MVP set in under 15 minutes for now; tune after playtests.
		assert(seconds < 15 * 60, `buying everything took {math.ceil(seconds)} seconds`)
	end)
end)

return nil
