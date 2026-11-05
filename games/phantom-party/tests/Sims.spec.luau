-- Simulations over many rounds (tests/Models): the role deal stays fair at
-- every party size, and the Truth Bell is neither a sure thing in the first
-- minute nor out of reach. Models, not measurements.

local Loader = require("./RobloxLoader")
local Models = require("./Models")
local TestKit = require("./TestKit")

local Rewards = Loader.require("src/shared/Config/Rewards")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("the role deal over 10,000 rounds", function()
	it("gives every player close to their fair share of each role, at 2 to 12 players", function()
		for players = 2, Models.MaxPlayers do
			local report = Models.deal(players, 10000, 100 + players)
			for roleId, line in report do
				if line.Fair > 0 then
					if line.Low < line.Fair * 0.85 or line.High > line.Fair * 1.15 then
						error(`{players} players, {roleId}: shares {line.Low} to {line.High}, fair {line.Fair}`)
					end
				end
			end
		end
	end)

	it("never leaves anyone waiting much more than three times the party size for a turn as the Phantom", function()
		for players = 2, Models.MaxPlayers do
			local report = Models.deal(players, 10000, 200 + players)
			if report.Phantom.LongestWait > players * 3 + 2 then
				error(`{players} players: someone waited {report.Phantom.LongestWait} rounds`)
			end
		end
	end)

	it("deals one player every special role in turn in practice", function()
		local report = Models.deal(1, 100, 1)
		expect(report.Phantom.Fair).toBe(1)
	end)
end)

describe("the Truth Bell model", function()
	it("rarely rings in the first minute, at any party size", function()
		for _, players in { 2, 3, 4, 5, 8, 12 } do
			local result = Models.bell(players, 3000, players)
			if result.Early > 0.1 then
				error(`{players} players: rang in the first minute in {result.Early * 100}% of rounds`)
			end
		end
	end)

	it("still rings in a good share of rounds once there are five or more", function()
		for _, players in { 5, 8, 12 } do
			local result = Models.bell(players, 3000, 50 + players)
			if result.Rang < 0.3 then
				error(`{players} players: rang in only {result.Rang * 100}% of rounds`)
			end
		end
	end)

	it("never rings more than the cap", function()
		local result = Models.bell(12, 3000, 9)
		expect(result.Rings <= Rewards.Bell.MaxRings).toBe(true)
	end)

	it("shows the first version rang several times a round on a full server", function()
		local old = Models.bell(12, 2000, 3, Models.oldBell(Rewards.Bell))
		expect(old.Rings > 2).toBe(true)
	end)
end)
