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

-- A stall with a shared upgrade, then two paths of two tiers each.
local TREE = {
	{ Id = "stall", Kind = "Stall", Cost = 0 },
	{ Id = "counter", Kind = "Boost", Cost = 10, Requires = "stall", Building = "stall" },
	{ Id = "sweets_1", Kind = "Boost", Cost = 20, Requires = "counter", Building = "stall", Path = "sweets" },
	{ Id = "sweets_2", Kind = "Boost", Cost = 40, Requires = "sweets_1", Building = "stall", Path = "sweets" },
	{ Id = "snacks_1", Kind = "Vendor", Cost = 20, Requires = "counter", Building = "stall", Path = "snacks" },
	{ Id = "snacks_2", Kind = "Boost", Cost = 40, Requires = "snacks_1", Building = "stall", Path = "snacks" },
	{ Id = "patch", Kind = "Grower", Cost = 50, Requires = "stall" },
}

local function ids(upgrades): { string }
	local result = {}
	for _, upgrade in upgrades do
		table.insert(result, upgrade.Id)
	end
	return result
end

describe("Progression paths", function()
	it("offers every path at the fork", function()
		expect(ids(Progression.available({ stall = true, counter = true }, TREE))).toEqual({
			"sweets_1",
			"snacks_1",
			"patch",
		})
	end)

	it("locks the other paths once one is bought, on the server and in what's offered", function()
		local s = state(1000, { "stall", "counter" })
		expect(Progression.purchase(s, TREE, "snacks_1")).toBe(true)
		local ok, reason = Progression.purchase(s, TREE, "sweets_1")
		expect(ok).toBe(false)
		expect(reason).toBe("PathLocked")
		expect(s.Owned.sweets_1).toBe(nil)
		expect(ids(Progression.available(s.Owned, TREE))).toEqual({ "snacks_2", "patch" })
		expect(Progression.pathLocked(s.Owned, TREE, TREE[4])).toBe(true)
		expect(Progression.pathLocked(s.Owned, TREE, TREE[6])).toBe(false)
		expect(Progression.pathLocked(s.Owned, TREE, TREE[7])).toBe(false)
	end)

	it("reads the chosen path from what is owned, so saves keep it", function()
		expect(Progression.chosenPaths({ stall = true, counter = true }, TREE)).toEqual({})
		expect(Progression.chosenPaths({ stall = true, counter = true, sweets_1 = true }, TREE)).toEqual({
			stall = "sweets",
		})
	end)

	it("groups paths in tier order and knows each tier and when a path is done", function()
		local paths = Progression.paths(TREE)
		expect(ids(paths.stall.sweets)).toEqual({ "sweets_1", "sweets_2" })
		expect(ids(paths.stall.snacks)).toEqual({ "snacks_1", "snacks_2" })
		expect(paths.patch).toBe(nil)
		local tier, count = Progression.pathTier(TREE, "snacks_2")
		expect(tier).toBe(2)
		expect(count).toBe(2)
		expect(Progression.pathTier(TREE, "counter")).toBe(nil)
		expect(Progression.pathComplete({ snacks_1 = true }, TREE, "stall", "snacks")).toBe(false)
		expect(Progression.pathComplete({ snacks_1 = true, snacks_2 = true }, TREE, "stall", "snacks")).toBe(true)
		expect(Progression.pathComplete({}, TREE, "stall", "nothing")).toBe(false)
	end)

	it("reports paths that can't work", function()
		local problems = Progression.validate({
			{ Id = "stall", Kind = "Stall", Cost = 0 },
			{ Id = "patch", Kind = "Grower", Cost = 0, Requires = "stall" },
			{ Id = "a_1", Kind = "Boost", Cost = 1, Requires = "stall", Building = "stall", Path = "a" },
			{ Id = "b_1", Kind = "Boost", Cost = 1, Requires = "stall", Building = "stall", Path = "b" },
			{ Id = "b_2", Kind = "Boost", Cost = 1, Requires = "a_1", Building = "stall", Path = "b" },
			{ Id = "c_1", Kind = "Boost", Cost = 1, Requires = "patch", Building = "stall", Path = "c" },
			{ Id = "lonely", Kind = "Boost", Cost = 1, Requires = "patch", Building = "patch", Path = "only" },
			{ Id = "drifter", Kind = "Boost", Cost = 1, Requires = "stall", Path = "x" },
			{ Id = "misfiled", Kind = "Boost", Cost = 1, Requires = "stall", Building = "a_1" },
			{ Id = "early", Kind = "Boost", Cost = 1, Building = "patch" },
			{ Id = "a_2", Kind = "Boost", Cost = 1, Requires = "a_1", Building = "stall", Path = "a" },
			{ Id = "a_2b", Kind = "Boost", Cost = 1, Requires = "a_1", Building = "stall", Path = "a" },
		})
		expect(problems).toContain("b_2: requires a_1, which is on another path")
		expect(problems).toContain("c_1: the paths of stall must all start after the same upgrade")
		expect(problems).toContain("patch has only one path")
		expect(problems).toContain("drifter: a path upgrade must name its Building")
		expect(problems).toContain("misfiled: Building a_1 is not a building")
		expect(problems).toContain("early: must require its Building")
		expect(problems).toContain("stall path a must be one line of tiers")
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
