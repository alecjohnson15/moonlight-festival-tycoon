-- Simulated shows: thousands of brackets with seeded random results, to
-- check the bracket's promises at every size a server can produce and to
-- compare the two seeding modes. These are simulations of the rules, not of
-- players: they can't say whether a show is fun to watch.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Bracket = RobloxLoader.require("src/shared/Bracket")
local Game = RobloxLoader.require("src/shared/Config/Game")
local Layout = RobloxLoader.require("src/shared/Config/Layout")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

-- Entrants p1..pn; p1 has the highest Style Score.
local function list(count: number)
	local entrants = {}
	for index = 1, count do
		table.insert(entrants, { Id = `p{index}`, Rating = 1500 - index * 20 })
	end
	return entrants
end

-- Plays a bracket out. winner(match) picks the winner; withdrawAt maps an
-- entrant to the walked-match count after which they leave. Returns how
-- many matchups were walked and how often each entrant walked.
local function playOut(bracket, winner, withdrawAt)
	local walked = 0
	local walks = {}
	local guard = 0
	while true do
		guard += 1
		assert(guard < 100, "the bracket never finished")
		for id, at in withdrawAt or {} do
			if walked >= at and not bracket.Withdrawn[id] then
				Bracket.withdraw(bracket, id)
			end
		end
		local match = Bracket.nextMatch(bracket)
		if not match then
			break
		end
		assert(not bracket.Withdrawn[match.A] and not bracket.Withdrawn[match.B], "a walker who left was sent out")
		walked += 1
		walks[match.A] = (walks[match.A] or 0) + 1
		walks[match.B] = (walks[match.B] or 0) + 1
		Bracket.report(bracket, match, winner(match))
	end
	return walked, walks
end

local MATCH_SECONDS = Game.Match.Intro + Game.Match.Walk + Game.Match.Pose + Game.Match.VoteGrace + Game.Match.Result

describe("Tournament simulation", function()
	it("finishes in n - 1 matchups and walks everyone at least once, for 2 to 16 entrants", function()
		local rng = seeded(1)
		for count = 2, 16 do
			for _, mode in { "Random", "Rating" } do
				for _ = 1, 50 do
					local bracket = Bracket.new(Bracket.seeded(list(count), mode, rng))
					local walked, walks = playOut(bracket, function(match)
						return if rng() < 0.5 then match.A else match.B
					end)
					expect(walked).toBe(count - 1)
					for index = 1, count do
						assert((walks[`p{index}`] or 0) >= 1, `p{index} never walked ({count} entrants, {mode})`)
					end
					assert(Bracket.champion(bracket) ~= nil, "no champion")
				end
			end
		end
	end)

	it("keeps a full show inside a bounded time", function()
		-- Booths cap a show at 12 walkers: 11 matchups plus the lineup.
		local most = #Layout.Booths
		local seconds = (most - 1) * MATCH_SECONDS + Game.Show.LineupSeconds
		print(`        longest show: {most} walkers, {math.floor(seconds)} s`)
		expect(seconds < 5 * 60).toBe(true)
		expect(#Layout.Lineup >= most).toBe(true)
	end)

	it("survives walkers leaving at any moment and never sends out someone who left", function()
		local rng = seeded(7)
		for _ = 1, 2000 do
			local count = 2 + math.floor(rng() * 11)
			local bracket = Bracket.new(Bracket.seeded(list(count), "Random", rng))
			local withdrawAt = {}
			for index = 1, count do
				if rng() < 0.25 then
					withdrawAt[`p{index}`] = math.floor(rng() * count)
				end
			end
			local walked = playOut(bracket, function(match)
				return if rng() < 0.5 then match.A else match.B
			end, withdrawAt)
			expect(walked <= count - 1).toBe(true)
		end
	end)

	it("gives byes by luck in Random mode and to the top scores in Rating mode", function()
		-- Five entrants means three byes.
		local rng = seeded(11)
		local runs = 3000
		local byes = { Random = {}, Rating = {} }
		for mode, counts in byes do
			for _ = 1, runs do
				local bracket = Bracket.new(Bracket.seeded(list(5), mode, rng))
				for _, match in bracket.Rounds[1] do
					if match.Skipped then
						local id = match.Winner
						counts[id] = (counts[id] or 0) + 1
					end
				end
			end
		end
		local share = function(mode, id)
			return (byes[mode][id] or 0) / runs
		end
		print(
			`        bye chance, top vs lowest score: Rating {share("Rating", "p1")} vs {share("Rating", "p5")}; Random {math.floor(
				share("Random", "p1") * 100
			)}% vs {math.floor(share("Random", "p5") * 100)}%`
		)
		expect(share("Rating", "p1")).toBe(1)
		expect(share("Rating", "p5")).toBe(0)
		expect(math.abs(share("Random", "p1") - 0.6) < 0.05).toBe(true)
		expect(math.abs(share("Random", "p5") - 0.6) < 0.05).toBe(true)
	end)

	it("gives the lowest Style Score a fair shot at the crown in Random mode", function()
		-- Each look has a hidden quality the score knows nothing about; the
		-- better look wins 70% of the time. With five walkers and three byes,
		-- Rating seeding makes the lowest score win three matchups instead of
		-- two; Random spreads that luck.
		local rng = seeded(23)
		local runs = 4000
		local crowns = { Random = 0, Rating = 0 }
		for mode in crowns do
			for _ = 1, runs do
				local quality = {}
				for index = 1, 5 do
					quality[`p{index}`] = rng()
				end
				local bracket = Bracket.new(Bracket.seeded(list(5), mode, rng))
				playOut(bracket, function(match)
					local better = if quality[match.A] >= quality[match.B] then match.A else match.B
					local worse = if better == match.A then match.B else match.A
					return if rng() < 0.7 then better else worse
				end)
				if Bracket.champion(bracket) == "p5" then
					crowns[mode] += 1
				end
			end
		end
		local random = crowns.Random / runs
		local rating = crowns.Rating / runs
		print(
			`        lowest score's crown chance with 5 walkers: Rating {math.floor(rating * 1000) / 10}%, Random {math.floor(
				random * 1000
			) / 10}% (fair share 20%)`
		)
		expect(math.abs(random - 0.2) < 0.03).toBe(true)
		expect(rating < random).toBe(true)
	end)

	it("never puts anyone in two matchups of the same round", function()
		local rng = seeded(31)
		for count = 2, 16 do
			local bracket = Bracket.new(Bracket.seeded(list(count), "Random", rng))
			playOut(bracket, function(match)
				return if rng() < 0.5 then match.A else match.B
			end)
			for _, matches in bracket.Rounds do
				local seen = {}
				for _, match in matches do
					for _, id in { match.A, match.B } do
						if id then
							assert(not seen[id], `{id} is in two matchups of one round`)
							seen[id] = true
						end
					end
				end
			end
		end
	end)
end)
