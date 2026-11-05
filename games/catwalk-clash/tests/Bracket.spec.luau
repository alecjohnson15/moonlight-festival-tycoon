local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Bracket = RobloxLoader.require("src/shared/Bracket")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function entrants(count: number)
	local list = {}
	for index = 1, count do
		table.insert(list, { Id = `p{index}`, Seed = 2000 - index })
	end
	return list
end

-- Plays the bracket to the end with the higher seed (lower number) winning.
local function playOut(bracket)
	local walked = 0
	while true do
		local match = Bracket.nextMatch(bracket)
		if not match then
			break
		end
		walked += 1
		local a = tonumber(string.sub(match.A, 2))
		local b = tonumber(string.sub(match.B, 2))
		Bracket.report(bracket, match, if a < b then match.A else match.B)
	end
	return walked
end

describe("Bracket", function()
	it("orders seeds so the top two meet only in the final", function()
		expect(table.concat(Bracket.seedOrder(8), ",")).toBe("1,8,4,5,2,7,3,6")
	end)

	it("takes n - 1 walked matchups for every size from 2 to 16", function()
		for count = 2, 16 do
			local bracket = Bracket.new(entrants(count))
			expect(playOut(bracket)).toBe(count - 1)
			expect(Bracket.champion(bracket)).toBe("p1")
		end
	end)

	it("gives byes to the top seeds", function()
		local bracket = Bracket.new(entrants(5))
		local first = Bracket.nextMatch(bracket)
		expect(first.A).toBe("p4")
		expect(first.B).toBe("p5")
	end)

	it("places first, second and the semifinal losers", function()
		local bracket = Bracket.new(entrants(4))
		playOut(bracket)
		local places = Bracket.placements(bracket)
		expect(places.first).toBe("p1")
		expect(places.second).toBe("p2")
		expect(#places.third).toBe(2)
	end)

	it("gives a walkover when a walker leaves", function()
		local bracket = Bracket.new(entrants(4))
		Bracket.withdraw(bracket, "p1")
		local walked = playOut(bracket)
		expect(walked).toBe(2)
		expect(Bracket.champion(bracket)).toBe("p2")
	end)

	it("names rounds from the final back", function()
		local bracket = Bracket.new(entrants(9))
		expect(bracket.RoundCount).toBe(4)
		expect(Bracket.roundName(bracket, 4)).toBe("Final")
		expect(Bracket.roundName(bracket, 3)).toBe("Semifinal")
		expect(Bracket.roundName(bracket, 2)).toBe("Quarterfinal")
		expect(Bracket.roundName(bracket, 1)).toBe("Round 1")
	end)
end)
