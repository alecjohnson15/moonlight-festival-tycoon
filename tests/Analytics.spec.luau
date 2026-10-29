-- The onboarding funnel: steps log in order, once each, and stop at the
-- first one a player hasn't reached; new path picks are found.

local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Funnel = require("../src/server/Lib/Funnel")
local Migrations = require("../src/server/Lib/Migrations")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function state(owned: { string }?, coins: number?): Funnel.State
	local set = {}
	for _, id in owned or {} do
		set[id] = true
	end
	return {
		Spawned = true,
		NearGate = true,
		HasPlot = owned ~= nil,
		Owned = set,
		LifetimeCoins = coins or 0,
	}
end

describe("onboarding funnel", function()
	it("names every step, with no name used twice", function()
		local seen = {}
		for index, step in Funnel.Steps do
			assert(type(step.Name) == "string" and #step.Name > 0, `step {index} has no name`)
			assert(not seen[step.Name], `{step.Name} is used twice`)
			seen[step.Name] = true
		end
		-- Roblox takes up to 100 steps.
		assert(#Funnel.Steps <= 100, "too many steps")
	end)

	it("logs a new player's first step only", function()
		local fresh = state()
		fresh.Spawned = false
		fresh.NearGate = false
		expect(#Funnel.toLog(0, fresh, Balance.Upgrades)).toBe(1)
		expect(Funnel.toLog(0, fresh, Balance.Upgrades)[1]).toBe(1)
	end)

	it("logs steps in order up to the first one not reached, and none twice", function()
		local claimed = state({})
		local steps = Funnel.toLog(0, claimed, Balance.Upgrades)
		expect(#steps).toBe(4)
		for index, step in steps do
			expect(step).toBe(index)
		end
		expect(#Funnel.toLog(4, claimed, Balance.Upgrades)).toBe(0)

		-- Coins earned before the stall is built still wait for the stall.
		local early = state({}, 50)
		expect(#Funnel.toLog(4, early, Balance.Upgrades)).toBe(0)
		local stall = state({ "starter_stall" }, 50)
		local next = Funnel.toLog(4, stall, Balance.Upgrades)
		expect(#next).toBe(2)
		expect(next[1]).toBe(5)
		expect(next[2]).toBe(6)
	end)

	it("reaches every step by the end of any route", function()
		local owned = {}
		for _, upgrade in Balance.Upgrades do
			table.insert(owned, upgrade.Id)
		end
		expect(#Funnel.toLog(0, state(owned, 1000), Balance.Upgrades)).toBe(#Funnel.Steps)
	end)

	it("finds the paths picked since it last looked", function()
		local picked = Funnel.newPaths({ grower = "output" }, { grower = "output", starter_stall = "vendor" })
		expect(#picked).toBe(1)
		expect(picked[1].Building).toBe("starter_stall")
		expect(picked[1].Path).toBe("vendor")
		expect(#Funnel.newPaths({ grower = "output" }, { grower = "output" })).toBe(0)
	end)

	it("starts a new save with nothing logged", function()
		local data = Migrations.new()
		expect(data.Onboarding).toBe(0)
		expect(data.Sessions).toBe(0)
	end)
end)

return nil
