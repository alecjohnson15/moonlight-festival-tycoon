-- Checks the pace of a run (Config/Balance) stays fair: the hearth needs
-- feeding but never more than a team can chop, nights grow without
-- swamping the monster cap, and the rewards make the paid-for-with-
-- snowflakes things a few evenings of play away. tools/simulate_run.luau
-- prints the whole run night by night with the same numbers.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Resources = RobloxLoader.require("src/shared/Config/Resources")
local Roles = RobloxLoader.require("src/shared/Config/Roles")
local Profile = RobloxLoader.require("src/shared/Profile")
local Waves = RobloxLoader.require("src/shared/Waves")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local hearth = Balance.Hearth
local phases = Balance.Phases

-- Flame the hearth burns through in one day-and-night cycle on its own.
local function burnPerCycle(first: boolean): number
	local day = if first then phases.FirstDay else phases.Day
	return (day + phases.Dusk + phases.Dawn) * hearth.BurnPerSecondDay + phases.Night * hearth.BurnPerSecondNight
end

describe("hearth", function()
	it("lasts through the first night even if nobody feeds it", function()
		expect(hearth.StartFlame - burnPerCycle(true) > 5).toBe(true)
	end)

	it("goes out on the second day if nobody feeds it, so feeding matters", function()
		local left = hearth.StartFlame - burnPerCycle(true) - phases.Day * hearth.BurnPerSecondDay
		expect(left < 0).toBe(true)
	end)

	it("needs only a short spell of chopping a day from one player", function()
		local pine = Resources.Nodes.Pine
		local wood = burnPerCycle(false) / hearth.Fuel.Wood
		local chops = math.ceil(wood / pine.Yield)
		-- Each chop is the hold plus a few seconds of walking between pines.
		local seconds = chops * (pine.HoldSeconds + 3)
		expect(seconds < phases.Day / 3).toBe(true)
	end)

	it("makes coal worth carrying", function()
		local coal = Resources.Nodes.CoalSeam
		local wood = Resources.Nodes.Pine
		local coalPerSecond = hearth.Fuel.Coal * coal.Yield / coal.HoldSeconds
		local woodPerSecond = hearth.Fuel.Wood * wood.Yield / wood.HoldSeconds
		expect(coalPerSecond > woodPerSecond).toBe(true)
	end)

	it("fits a full night's burn inside the starting hearth", function()
		expect(phases.Night * hearth.BurnPerSecondNight < hearth.Levels[1].MaxFlame).toBe(true)
	end)
end)

describe("nights", function()
	it("grows every night, faster in overtime", function()
		for players = 1, Balance.MaxPlayers do
			for night = 2, Balance.LastNight do
				expect(Waves.budget(night, players) > Waves.budget(night - 1, players)).toBe(true)
			end
		end
		local normal = Waves.budget(Balance.Nights, 4) - Waves.budget(Balance.Nights - 1, 4)
		local overtime = Waves.budget(Balance.Nights + 2, 4) - Waves.budget(Balance.Nights + 1, 4)
		expect(overtime > normal).toBe(true)
	end)

	it("keeps the biggest normal night within twice the monster cap", function()
		expect(Waves.budget(Balance.Nights, Balance.MaxPlayers) <= Balance.Waves.MaxAlive * 2).toBe(true)
	end)

	it("puts the bosses on nights that exist", function()
		for night, kind in Balance.Bosses do
			expect(night <= Balance.Nights).toBe(true)
			expect(type(kind)).toBe("string")
		end
	end)
end)

describe("rewards", function()
	local function flakes(nights: number, parts: number, won: boolean, knockouts: number): number
		return Profile.runFlakes({ Nights = nights, Parts = parts, Won = won, Knockouts = knockouts })
	end

	it("pays a lost run something, and a win much more", function()
		local lost = flakes(4, 1, false, 20)
		local won = flakes(Balance.Nights, 4, true, 80)
		expect(lost > 0).toBe(true)
		expect(won > lost * 3).toBe(true)
	end)

	it("puts each earnable role two to six wins away", function()
		local win = flakes(Balance.Nights, 4, true, 60)
		for _, role in Roles.List do
			if role.Price > 0 then
				local wins = role.Price / win
				expect(wins >= 2 and wins <= 6).toBe(true)
			end
		end
	end)
end)
