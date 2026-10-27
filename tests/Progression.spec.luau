local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Progression = require("../src/shared/Progression")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local UPGRADES = {
	{ Id = "stall", Kind = "Producer", Cost = 0, IncomePerSecond = 2 },
	{ Id = "counter", Kind = "Boost", Cost = 10, Target = "stall", Multiplier = 3, Requires = "stall" },
	{ Id = "sign", Kind = "Boost", Cost = 20, Target = "stall", Multiplier = 2, Requires = "stall" },
	{ Id = "patch", Kind = "Producer", Cost = 50, IncomePerSecond = 5, Requires = "stall" },
}

local function state(coins: number, owned: { string }?)
	local set = {}
	for _, id in owned or {} do
		set[id] = true
	end
	return { Coins = coins, Owned = set }
end

describe("Progression.validate", function()
	it("accepts the shipped balance config", function()
		expect(#Progression.validate(Balance.Upgrades)).toBe(0)
	end)

	it("reports duplicate ids and unknown requirements", function()
		local problems = Progression.validate({
			{ Id = "a", Kind = "Producer", Cost = 0, IncomePerSecond = 1 },
			{ Id = "a", Kind = "Producer", Cost = 0, IncomePerSecond = 1 },
			{ Id = "b", Kind = "Producer", Cost = 5, IncomePerSecond = 1, Requires = "missing" },
		})
		expect(problems).toContain("duplicate id a")
		expect(problems).toContain("requires unknown upgrade missing")
	end)

	it("reports boosts that target a boost and bad costs", function()
		local problems = Progression.validate({
			{ Id = "p", Kind = "Producer", Cost = 1.5, IncomePerSecond = 1 },
			{ Id = "b1", Kind = "Boost", Cost = 1, Target = "p", Multiplier = 2 },
			{ Id = "b2", Kind = "Boost", Cost = 1, Target = "b1", Multiplier = 2 },
		})
		expect(problems).toContain("p: cost must be a whole number")
		expect(problems).toContain("b2: boost must target a producer")
	end)

	it("reports requirement loops", function()
		local problems = Progression.validate({
			{ Id = "x", Kind = "Producer", Cost = 1, IncomePerSecond = 1, Requires = "y" },
			{ Id = "y", Kind = "Producer", Cost = 1, IncomePerSecond = 1, Requires = "x" },
		})
		expect(problems).toContain("requirement loop")
	end)
end)

describe("Progression.purchase", function()
	it("charges and grants an unlocked, affordable upgrade", function()
		local s = state(60, { "stall" })
		local ok = Progression.purchase(s, UPGRADES, "patch")
		expect(ok).toBe(true)
		expect(s.Coins).toBe(10)
		expect(s.Owned.patch).toBe(true)
	end)

	it("refuses with a reason and changes nothing", function()
		local cases = {
			{ s = state(100), id = "nope", reason = "UnknownUpgrade" },
			{ s = state(100), id = "patch", reason = "Locked" },
			{ s = state(5, { "stall" }), id = "patch", reason = "TooExpensive" },
			{ s = state(100, { "stall" }), id = "stall", reason = "AlreadyOwned" },
		}
		for _, case in cases do
			local before = case.s.Coins
			local ok, reason = Progression.purchase(case.s, UPGRADES, case.id)
			expect(ok).toBe(false)
			expect(reason).toBe(case.reason)
			expect(case.s.Coins).toBe(before)
		end
	end)
end)

describe("Progression.incomePerSecond", function()
	it("is zero with nothing owned", function()
		expect(Progression.incomePerSecond({}, UPGRADES)).toBe(0)
	end)

	it("adds producers and multiplies only the boosted one", function()
		expect(Progression.incomePerSecond({ stall = true, patch = true }, UPGRADES)).toBe(7)
		expect(Progression.incomePerSecond({ stall = true, patch = true, counter = true }, UPGRADES)).toBe(11)
	end)

	it("stacks boosts on the same producer", function()
		expect(Progression.incomePerSecond({ stall = true, counter = true, sign = true }, UPGRADES)).toBe(12)
	end)

	it("ignores a boost whose producer isn't owned", function()
		expect(Progression.incomePerSecond({ counter = true }, UPGRADES)).toBe(0)
	end)
end)

describe("Progression.available", function()
	it("lists unlocked, unowned upgrades in config order", function()
		local ids = {}
		for _, upgrade in Progression.available({ stall = true, counter = true }, UPGRADES) do
			table.insert(ids, upgrade.Id)
		end
		expect(ids).toEqual({ "sign", "patch" })
	end)
end)

describe("first minute (shipped balance)", function()
	it("offers a free first upgrade to a brand-new player", function()
		local s = state(Balance.StartingCoins)
		local first = Progression.available(s.Owned, Balance.Upgrades)[1]
		expect(first.Cost).toBe(0)
		expect(Progression.purchase(s, Balance.Upgrades, first.Id)).toBe(true)
	end)

	it("makes the first paid upgrade affordable within 60 seconds of passive income", function()
		local s = state(Balance.StartingCoins)
		local first = Progression.available(s.Owned, Balance.Upgrades)[1]
		Progression.purchase(s, Balance.Upgrades, first.Id)
		local cheapest = math.huge
		for _, upgrade in Progression.available(s.Owned, Balance.Upgrades) do
			cheapest = math.min(cheapest, upgrade.Cost)
		end
		local earned = Progression.incomePerSecond(s.Owned, Balance.Upgrades) * 60
		expect(s.Coins + earned >= cheapest).toBe(true)
	end)
end)

return nil
