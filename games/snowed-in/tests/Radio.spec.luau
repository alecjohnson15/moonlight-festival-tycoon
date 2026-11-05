-- The rescue radio's rules (shared/Radio): freeing parts with each
-- landmark's trial, carrying, dropping, fitting, parts that come home on
-- their own, catch-up help, and the cases that could leave a run unwinnable
-- or call the train twice.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Cycle = RobloxLoader.require("src/shared/Cycle")
local Map = RobloxLoader.require("src/shared/Config/Map")
local Radio = RobloxLoader.require("src/shared/Radio")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local EMPTY = { Who = "a", Tool = nil, Pack = {} }

-- Frees a part however its trial asks.
local function free(radio, id: string, who: any)
	local part = radio.Parts[id]
	local trial = Radio.trial(part)
	local attempt = { Who = who, Tool = "Torch", Pack = { Wood = 99, Scrap = 99 } }
	local outcome
	for _ = 1, Radio.turns(trial) do
		outcome = Radio.work(radio, id, attempt, true)
	end
	return outcome
end

describe("radio parts", function()
	it("starts with every landmark's part frozen and none fitted", function()
		local radio = Radio.new()
		expect(#radio.Order).toBe(#Map.Landmarks)
		expect(Radio.count(radio, "Frozen")).toBe(4)
		expect(Radio.fitted(radio)).toBe(0)
		expect(Radio.complete(radio)).toBe(false)
	end)

	it("gives each landmark a different way to free its part", function()
		local kinds = {}
		for _, landmark in Map.Landmarks do
			local trial = landmark.Trial
			kinds[trial.Kind .. (trial.Resource or "")] = true
			assert(#trial.Hint > 20, `{landmark.Id} needs a hint`)
		end
		local distinct = 0
		for _ in kinds do
			distinct += 1
		end
		expect(distinct).toBe(4)
	end)

	it("saws the sawmill's logs over several turns, by anyone", function()
		local radio = Radio.new()
		local first = Radio.work(radio, "Generator", { Who = "a", Pack = {} }, true)
		expect(first.Ok).toBe(true)
		expect(first.Freed).toBe(false)
		Radio.work(radio, "Generator", { Who = "b", Pack = {} }, true)
		local last = Radio.work(radio, "Generator", { Who = "a", Pack = {} }, true)
		expect(last.Freed).toBe(true)
		expect(radio.Parts.Generator.State).toBe("Loose")
	end)

	it("melts the cave ice only with a tool in hand", function()
		local radio = Radio.new()
		local bare = Radio.work(radio, "Battery", EMPTY, true)
		expect(bare.Ok).toBe(false)
		expect(radio.Parts.Battery.State).toBe("Frozen")
		local lit = Radio.work(radio, "Battery", { Who = "a", Tool = "Torch", Pack = {} }, true)
		expect(lit.Freed).toBe(true)
	end)

	it("takes the lighthouse's wood and the depot's scrap from the backpack", function()
		local radio = Radio.new()
		local short = Radio.work(radio, "Lamp", { Who = "a", Pack = { Wood = 2 } }, true)
		expect(short.Ok).toBe(false)
		assert(string.find(short.Reason, "6 wood"), short.Reason)
		local lamp = Radio.work(radio, "Lamp", { Who = "a", Pack = { Wood = 6 } }, true)
		expect(lamp.Freed).toBe(true)
		expect(lamp.Take.Wood).toBe(6)
		local antenna = Radio.work(radio, "Antenna", { Who = "a", Pack = { Scrap = 5 } }, true)
		expect(antenna.Freed).toBe(true)
		expect(antenna.Take.Scrap).toBe(4)
	end)

	it("frees nothing between runs", function()
		local radio = Radio.new()
		local outcome = Radio.work(radio, "Generator", { Who = "a", Pack = {} }, false)
		expect(outcome.Ok).toBe(false)
		expect(radio.Parts.Generator.Progress).toBe(0)
	end)

	it("lets a player carry one part, and a part have one carrier", function()
		local radio = Radio.new()
		free(radio, "Generator", "a")
		free(radio, "Battery", "a")
		expect(Radio.pickUp(radio, "Generator", "a", true)).toBe(true)
		local ok, reason = Radio.pickUp(radio, "Battery", "a", true)
		expect(ok).toBe(false)
		assert(reason ~= nil, "says why")
		expect(Radio.pickUp(radio, "Generator", "b", true)).toBe(false)
		expect(Radio.carriedBy(radio, "a").Id).toBe("Generator")
	end)

	it("drops a carrier's part where they were, and can't fit what isn't carried", function()
		local radio = Radio.new()
		free(radio, "Generator", "a")
		Radio.pickUp(radio, "Generator", "a", true)
		local dropped = Radio.drop(radio, "a", 100)
		expect(dropped.Id).toBe("Generator")
		expect(dropped.State).toBe("Loose")
		expect(dropped.LooseSince).toBe(100)
		local part = Radio.fit(radio, "a", true)
		expect(part).toBe(nil)
		expect(Radio.drop(radio, "a", 101)).toBe(nil)
	end)

	it("sends a part left lying too long back to its landmark, once", function()
		local radio = Radio.new()
		free(radio, "Lamp", "a")
		Radio.pickUp(radio, "Lamp", "a", true)
		Radio.drop(radio, "a", 10)
		expect(#Radio.stale(radio, 10 + Balance.Radio.LooseReturnSeconds - 1)).toBe(0)
		local stale = Radio.stale(radio, 10 + Balance.Radio.LooseReturnSeconds)
		expect(#stale).toBe(1)
		Radio.sendHome(stale[1])
		expect(stale[1].State).toBe("Loose")
		expect(#Radio.stale(radio, 10_000)).toBe(0)
	end)

	it("never sends home a part freed at its landmark and not yet touched", function()
		local radio = Radio.new()
		free(radio, "Antenna", "a")
		expect(#Radio.stale(radio, 1e9)).toBe(0)
	end)

	it("fits four parts carried in at once, and calls the train on the last only", function()
		local radio = Radio.new()
		local carriers = { Generator = "a", Battery = "b", Lamp = "c", Antenna = "d" }
		for id, who in carriers do
			free(radio, id, who)
			expect(Radio.pickUp(radio, id, who, true)).toBe(true)
		end
		local calls = 0
		for _, who in { "a", "b", "c", "d" } do
			local part, complete = Radio.fit(radio, who, true)
			assert(part ~= nil, `{who} fits a part`)
			if complete then
				calls += 1
			end
		end
		expect(calls).toBe(1)
		expect(Radio.fitted(radio)).toBe(4)
		-- Trying again fits nothing and calls nothing.
		local again, complete = Radio.fit(radio, "a", true)
		expect(again).toBe(nil)
		expect(complete).toBe(false)
	end)

	it("won't fit a part once the run is over", function()
		local radio = Radio.new()
		free(radio, "Generator", "a")
		Radio.pickUp(radio, "Generator", "a", true)
		local part = Radio.fit(radio, "a", false)
		expect(part).toBe(nil)
		expect(radio.Parts.Generator.State).toBe("Carried")
	end)

	it("freezes everything again for a new run and hands back the carriers", function()
		local radio = Radio.new()
		free(radio, "Generator", "a")
		Radio.pickUp(radio, "Generator", "a", true)
		free(radio, "Battery", "b")
		Radio.pickUp(radio, "Battery", "b", true)
		Radio.fit(radio, "b", true)
		local carriers = Radio.reset(radio)
		expect(#carriers).toBe(1)
		expect(carriers[1]).toBe("a")
		expect(Radio.count(radio, "Frozen")).toBe(4)
		expect(radio.Parts.Generator.Progress).toBe(0)
	end)
end)

describe("radio and the train", function()
	it("brings the train when the last part goes in on the last night", function()
		-- The fourth part is fitted during night 10: the dawn after it
		-- brings the train, not a new day.
		local after = Cycle.next({ Phase = "Dawn", Night = Balance.Nights, Called = true })
		expect(after.Phase).toBe("Rescue")
	end)

	it("keeps going into overtime without the radio, and ends at the last night", function()
		local dawn10 = Cycle.next({ Phase = "Dawn", Night = Balance.Nights, Called = false })
		expect(dawn10.Phase).toBe("Day")
		local last = Cycle.next({ Phase = "Dawn", Night = Balance.LastNight, Called = false })
		expect(last.Phase).toBe("Lost")
		local lateCall = Cycle.next({ Phase = "Dawn", Night = Balance.Nights + 2, Called = true })
		expect(lateCall.Phase).toBe("Rescue")
	end)

	it("never brings the train before the last night, even with the radio fixed", function()
		for night = 1, Balance.Nights - 1 do
			local after = Cycle.next({ Phase = "Dawn", Night = night, Called = true })
			expect(after.Phase).toBe("Day")
		end
	end)
end)

describe("catch-up", function()
	it("expects about a part every two nights from night 4", function()
		expect(Radio.expected(3)).toBe(0)
		expect(Radio.expected(4)).toBe(1)
		expect(Radio.expected(6)).toBe(2)
		expect(Radio.expected(8)).toBe(3)
		expect(Radio.expected(10)).toBe(4)
		expect(Radio.expected(15)).toBe(4)
	end)

	it("helps a team that is behind, and only while it is", function()
		expect(Radio.behind(3, 0)).toBe(false)
		expect(Radio.behind(4, 0)).toBe(true)
		expect(Radio.behind(4, 1)).toBe(false)
		expect(Radio.behind(8, 2)).toBe(true)
		expect(Radio.behind(12, 4)).toBe(false)
	end)
end)
