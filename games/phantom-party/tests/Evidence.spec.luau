-- Leads and the Truth Bell: glimpses are usually right and sometimes wrong,
-- a lead never names anyone, notebooks expire and can't be flooded, and the
-- bell takes more pages for a bigger party and rings a limited number of
-- times.

local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Bell = Loader.require("src/shared/Rules/Bell")
local Evidence = Loader.require("src/shared/Rules/Evidence")
local EvidenceConfig = Loader.require("src/shared/Config/Evidence")
local Items = Loader.require("src/shared/Config/Items")
local Progress = Loader.require("src/shared/Rules/Progress")
local Rewards = Loader.require("src/shared/Config/Rewards")
local Roles = Loader.require("src/shared/Config/Roles")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local ROOMS = { "Foyer", "Ballroom", "Library", "Hall", "Kitchen", "Garden", "Big Top", "Mirror Maze" }

describe("mask colours", function()
	it("put every mask in one of the four groups, and use all four", function()
		local used = {}
		for _, item in Items.List do
			if item.Kind == "Mask" then
				local tone = Evidence.tone(item.Id)
				expect(table.find(Evidence.TONES, tone) ~= nil).toBe(true)
				used[tone] = true
			end
		end
		for _, tone in Evidence.TONES do
			expect(used[tone]).toBe(true)
		end
	end)

	it("count an unknown mask as the default one", function()
		expect(Evidence.tone(nil)).toBe(Evidence.tone(Items.DEFAULTS.Mask))
		expect(Evidence.tone("no_such_mask")).toBe(Evidence.tone(Items.DEFAULTS.Mask))
	end)

	it("read obvious colours the way a player would", function()
		expect(Evidence.toneOfColor("#111111")).toBe("dark")
		expect(Evidence.toneOfColor("#F5F5F0")).toBe("pale")
		expect(Evidence.toneOfColor("#FF8C1A")).toBe("warm")
		expect(Evidence.toneOfColor("#127475")).toBe("cool")
	end)
end)

describe("a glimpse", function()
	it("is right about as often as the config says, and never certain", function()
		local random = seeded(11)
		local right, total = 0, 20000
		local wrong = {}
		for _ = 1, total do
			local seen = Evidence.glimpse("warm", random)
			if seen == "warm" then
				right += 1
			else
				wrong[seen] = (wrong[seen] or 0) + 1
			end
		end
		local rate = right / total
		expect(math.abs(rate - EvidenceConfig.GlimpseAccuracy) < 0.02).toBe(true)
		expect(rate < 1).toBe(true)
		-- The wrong answers spread evenly over the other three groups.
		for _, tone in { "dark", "pale", "cool" } do
			local share = (wrong[tone] or 0) / (total - right)
			expect(math.abs(share - 1 / 3) < 0.04).toBe(true)
		end
	end)

	it("is as reliable on a full server as on a small one", function()
		for _, players in { 2, 5, 12 } do
			local random = seeded(players)
			local right, total = 0, 0
			for _ = 1, 4000 do
				for _ = 1, players - 1 do
					total += 1
					if Evidence.glimpse("cool", random) == "cool" then
						right += 1
					end
				end
			end
			expect(math.abs(right / total - EvidenceConfig.GlimpseAccuracy) < 0.03).toBe(true)
		end
	end)
end)

describe("who notices", function()
	it("sees within range with a clear view, hears further, and misses the rest", function()
		expect(Evidence.sense(10, true, 10)).toBe("See")
		expect(Evidence.sense(10, false, 10)).toBe("Hear")
		expect(Evidence.sense(EvidenceConfig.SeeRange + 1, true, 30)).toBe("Hear")
		expect(Evidence.sense(nil, false, EvidenceConfig.HearRange + 1)).toBe(nil)
	end)
end)

describe("a lead", function()
	it("never carries a name, a role or a placeholder", function()
		local roleNames = {}
		for _, role in Roles.List do
			table.insert(roleNames, role.Name)
		end
		for kind in Evidence.TEXT do
			for _, room in ROOMS do
				for _, tone in Evidence.TONES do
					local text = Evidence.text(kind, room, tone)
					expect(string.find(text, "{", 1, true)).toBe(nil)
					for _, name in roleNames do
						expect(string.find(text, name, 1, true)).toBe(nil)
					end
				end
			end
		end
	end)

	it("belongs to one of the four families", function()
		for kind in Evidence.TEXT do
			expect(table.find(Evidence.FAMILIES, Evidence.FAMILY_OF[kind]) ~= nil).toBe(true)
		end
	end)

	it("can't be written twice in a row for the same family", function()
		local book = Evidence.newBook()
		expect(Evidence.write(book, "HeardTag", "Hall", nil, 100) ~= nil).toBe(true)
		expect(Evidence.write(book, "HeardThrow", "Hall", nil, 101)).toBe(nil)
		expect(Evidence.write(book, "SawTag", "Hall", "dark", 101) ~= nil).toBe(true)
		expect(Evidence.write(book, "HeardTag", "Hall", nil, 100 + EvidenceConfig.Cooldown) ~= nil).toBe(true)
	end)

	it("expires, and the notebook holds only so many", function()
		local book = Evidence.newBook()
		local now = 0
		for _ = 1, 40 do
			now += EvidenceConfig.Cooldown
			Evidence.write(book, "HeardTag", "Hall", nil, now)
		end
		expect(#book.Leads <= EvidenceConfig.MaxLeads).toBe(true)
		Evidence.prune(book, now + EvidenceConfig.Lifetime + 1)
		expect(#book.Leads).toBe(0)
	end)

	it("can't be farmed: a whole round of events still fits the notebook", function()
		local book = Evidence.newBook()
		local written = 0
		for second = 0, 240, 0.25 do
			for kind in Evidence.TEXT do
				if Evidence.write(book, kind, "Hall", "pale", second) then
					written += 1
				end
			end
		end
		-- At most one lead per family per cooldown.
		expect(written <= #Evidence.FAMILIES * (240 / EvidenceConfig.Cooldown + 1)).toBe(true)
		expect(#book.Leads <= EvidenceConfig.MaxLeads).toBe(true)
	end)

	it("drops nothing for a new round: each round starts with an empty notebook", function()
		local book = Evidence.newBook()
		expect(#book.Leads).toBe(0)
		expect(next(book.Last)).toBe(nil)
	end)
end)

describe("the Truth Bell", function()
	it("takes more pages for a bigger party", function()
		local last = 0
		for guests = 1, 11 do
			local need = Bell.need(guests)
			expect(need >= last).toBe(true)
			expect(need >= Rewards.Bell.Min and need <= Rewards.Bell.Max).toBe(true)
			last = need
		end
		expect(Bell.need(11) > Bell.need(1)).toBe(true)
	end)

	it("chimes the room once on the way up, then rings when full", function()
		local bell = Bell.new(5)
		local events = {}
		for _ = 1, bell.Need do
			table.insert(events, Bell.add(bell) or "-")
		end
		local hints, rings = 0, 0
		for _, event in events do
			if event == "Hint" then
				hints += 1
			elseif event == "Ring" then
				rings += 1
			end
		end
		expect(hints).toBe(1)
		expect(rings).toBe(1)
		expect(events[#events]).toBe("Ring")
	end)

	it("stops filling once it has rung as often as it may", function()
		local bell = Bell.new(11)
		local rings = 0
		for _ = 1, 200 do
			if Bell.add(bell) == "Ring" then
				rings += 1
			end
		end
		expect(rings).toBe(Rewards.Bell.MaxRings)
		expect(bell.Spent).toBe(true)
		expect(Bell.add(bell)).toBe(nil)
	end)

	it("can be rolled back to the first version's pacing", function()
		local old = table.clone(Rewards.Bell)
		old.Base, old.PerGuest, old.Min, old.Max, old.MaxRings = 10, 0, 10, 10, math.huge
		local bell = Bell.new(11, old)
		expect(bell.Need).toBe(10)
		local rings = 0
		for _ = 1, 50 do
			if Bell.add(bell, old) == "Ring" then
				rings += 1
			end
		end
		expect(rings).toBe(5)
	end)

	it("pays for at most a capped number of pages a round", function()
		local pay = Progress.pay({
			Won = false,
			Survived = false,
			Tags = 0,
			Takedown = false,
			Revives = 0,
			Clues = 40,
			Coins = 0,
		})
		expect(pay.Lines).toEqual(pay.Lines)
		local paidPages = 0
		for _, line in pay.Lines do
			local count = string.match(line.Label, "Clue pages x(%d+)")
			if count then
				paidPages = tonumber(count) :: number
			end
		end
		expect(paidPages).toBe(Rewards.ClueCap)
	end)
end)
