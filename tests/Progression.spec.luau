local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Earnings = require("../src/shared/Earnings")
local Progression = require("../src/shared/Progression")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local UPGRADES = {
	{ Id = "stall", Kind = "Stall", Cost = 0 },
	{ Id = "counter", Kind = "Boost", Cost = 10, Requires = "stall" },
	{ Id = "sign", Kind = "Boost", Cost = 20, Requires = "stall" },
	{ Id = "patch", Kind = "Grower", Cost = 50, Requires = "stall" },
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
			{ Id = "a", Kind = "Stall", Cost = 0 },
			{ Id = "a", Kind = "Stall", Cost = 0 },
			{ Id = "b", Kind = "Grower", Cost = 5, Requires = "missing" },
		})
		expect(problems).toContain("duplicate id a")
		expect(problems).toContain("requires unknown upgrade missing")
	end)

	it("reports costs that are fractional or negative", function()
		local problems = Progression.validate({
			{ Id = "p", Kind = "Grower", Cost = 1.5 },
			{ Id = "q", Kind = "Grower", Cost = -1 },
		})
		expect(problems).toContain("p: cost must be a whole number")
		expect(problems).toContain("q: cost must be a whole number")
	end)

	it("reports requirement loops", function()
		local problems = Progression.validate({
			{ Id = "x", Kind = "Grower", Cost = 1, Requires = "y" },
			{ Id = "y", Kind = "Grower", Cost = 1, Requires = "x" },
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
		local earned = Earnings.perSecond(s.Owned, Balance) * 60
		expect(s.Coins + earned >= cheapest).toBe(true)
	end)
end)

return nil
