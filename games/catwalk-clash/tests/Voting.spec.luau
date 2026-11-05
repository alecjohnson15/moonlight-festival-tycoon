local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Voting = RobloxLoader.require("src/shared/Voting")
local Game = RobloxLoader.require("src/shared/Config/Game")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
local settings = Game.Voting

local none = { A = 0, B = 0 }

describe("Voting", function()
	it("never lets a walker vote in their own matchup", function()
		expect((Voting.canVote("u1", "u1", "u2", "A", 5, 2, 10))).toBe(false)
		expect((Voting.canVote("u3", "u1", "u2", "A", 5, 2, 10))).toBe(true)
	end)

	it("only counts votes inside the window", function()
		local _, early = Voting.canVote("u3", "u1", "u2", "A", 1, 2, 10)
		local _, late = Voting.canVote("u3", "u1", "u2", "B", 11, 2, 10)
		expect(early).toBe("TooEarly")
		expect(late).toBe("Closed")
		local _, bad = Voting.canVote("u3", "u1", "u2", "C", 5, 2, 10)
		expect(bad).toBe("BadSide")
	end)

	it("counts friends and brand new accounts for less in Flat mode", function()
		expect(Voting.weight(settings, false, 400)).toBe(1)
		expect(Voting.weight(settings, true, 400)).toBe(settings.FriendWeight)
		expect(Voting.weight(settings, true, 1)).toBe(settings.FriendWeight * settings.NewAccountWeight)
	end)

	it("lets the judges decide an empty room", function()
		local tally = Voting.tally(settings, {}, { "B", "B", "A" }, none, none, 0)
		expect(tally.Winner).toBe("B")
		expect(tally.DecidedBy).toBe("Judges")
	end)

	it("lets a crowd outvote the judges", function()
		local ballots = {}
		for index = 1, 10 do
			ballots[index] = { Side = "A", Weight = 1 }
		end
		local tally = Voting.tally(settings, ballots, { "B", "B", "B" }, none, none, 0)
		expect(tally.Winner).toBe("A")
		expect(tally.VotesA).toBe(10)
	end)

	it("stops a friend group from beating a smaller honest crowd", function()
		for _, mode in { "Capped", "Flat" } do
			local modeSettings = table.clone(settings)
			modeSettings.Mode = mode
			local ballots = {}
			-- Four friends of walker A against three strangers voting B.
			for index = 1, 4 do
				ballots[index] = Voting.ballot(modeSettings, "A", true, 400)
			end
			for index = 5, 7 do
				ballots[index] = Voting.ballot(modeSettings, "B", false, 400)
			end
			local tally = Voting.tally(modeSettings, ballots, { "A", "B", "B" }, none, none, 0)
			expect(tally.Winner).toBe("B")
		end
	end)

	it("counts a few friends and newcomers in full, and only caps a crowd of them", function()
		local one = { Voting.ballot(settings, "A", true, 400) }
		expect(Voting.tally(settings, one, {}, none, none, 0).A).toBe(1)
		local newcomer = { Voting.ballot(settings, "B", false, 1) }
		expect(Voting.tally(settings, newcomer, {}, none, none, 0).B).toBe(1)
		local crowd = {}
		for index = 1, 6 do
			crowd[index] = Voting.ballot(settings, "A", true, 400)
		end
		local full = settings.SuspectFullVotes
		local expected = full + (6 - full) * settings.SuspectWeight
		expect(Voting.tally(settings, crowd, {}, none, none, 0).A).toBe(expected)
	end)

	it("never marks a vote against a friend as suspect", function()
		-- The server passes friendOfChosen for the walker voted for only.
		local ballot = Voting.ballot(settings, "B", false, 400)
		expect(ballot.Suspect).toBe(false)
		expect(ballot.Weight).toBe(1)
	end)

	it("shows plain vote counts, never weights", function()
		local ballots = {
			Voting.ballot(settings, "A", true, 1),
			Voting.ballot(settings, "A", true, 1),
			Voting.ballot(settings, "A", true, 1),
			Voting.ballot(settings, "B", false, 400),
		}
		local tally = Voting.tally(settings, ballots, { "A", "B", "B" }, none, none, 0)
		expect(tally.VotesA).toBe(3)
		expect(tally.VotesB).toBe(1)
	end)

	it("always picks A or B, the same way every time, for any ballots", function()
		local state = 12345
		local function random()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		for _ = 1, 500 do
			local ballots = {}
			for index = 1, math.floor(random() * 20) do
				local side = if random() < 0.5 then "A" else "B"
				ballots[index] = Voting.ballot(settings, side, random() < 0.3, if random() < 0.2 then 2 else 400)
			end
			local judges = {}
			for index = 1, 3 do
				judges[index] = if random() < 0.5 then "A" else "B"
			end
			local scores = { A = math.floor(random() * 3), B = math.floor(random() * 3) }
			local first = Voting.tally(settings, ballots, judges, scores, none, 1)
			local again = Voting.tally(settings, ballots, judges, scores, none, 1)
			expect(first.Winner == "A" or first.Winner == "B").toBe(true)
			expect(first.Winner).toBe(again.Winner)
			expect(first.Share >= 0.5 and first.Share <= 1).toBe(true)
			expect(first.VotesA + first.VotesB).toBe(#ballots)
		end
	end)

	it("breaks ties on judges' score, then Style Score, then a coin", function()
		local ballots = { { Side = "A", Weight = 1 }, { Side = "B", Weight = 1 } }
		local judged = Voting.tally(settings, ballots, {}, { A = 10, B = 20 }, none, 0)
		expect(judged.Winner).toBe("B")
		expect(judged.DecidedBy).toBe("Judges")
		local scored = Voting.tally(settings, ballots, {}, none, { A = 1200, B = 1000 }, 1)
		expect(scored.Winner).toBe("A")
		local coin = Voting.tally(settings, ballots, {}, none, none, 1)
		expect(coin.Winner).toBe("B")
		expect(coin.DecidedBy).toBe("Coin")
	end)
end)
