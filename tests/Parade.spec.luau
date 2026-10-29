-- The Moonlight Parade's rules: when parades start, where floats and
-- lanterns go, what counts as a catch, what catches pay, and that parades
-- and Ghost Catcher rounds together can't break the 90-minute pacing.

local TestKit = require("./TestKit")
local Pacing = require("./Pacing")
local Activity = require("../src/shared/Activity")
local ActivityConfig = require("../src/shared/Config/Activity")
local Config = require("../src/shared/Config/Parade")
local Parade = require("../src/shared/Parade")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- A repeatable stand-in for Random, from 0 to 1.
local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = state * 16807 % 2147483647
		return state / 2147483647
	end
end

local ROUTE = { RadiusX = 20, RadiusZ = 26 }

describe("Moonlight Parade", function()
	it("starts a while after the server does, then every interval", function()
		local first = 1000 + Config.FirstSeconds
		expect(Parade.nextStart(Config, 1000, 1000)).toBe(first)
		expect(Parade.nextStart(Config, 1000, first)).toBe(first)
		expect(Parade.nextStart(Config, 1000, first + 1)).toBe(first + Config.IntervalSeconds)
		expect(Parade.nextStart(Config, 1000, first + Config.IntervalSeconds * 2.5)).toBe(
			first + Config.IntervalSeconds * 3
		)
		-- The warning comes after the first minute, and a parade ends well
		-- before the next.
		assert(Config.FirstSeconds - Config.WarnSeconds >= 60, "the first parade is announced too soon")
		assert(Config.RunSeconds < Config.IntervalSeconds / 2, "parades take up too much of the night")
	end)

	it("spaces the floats evenly round the loop, the first leading", function()
		local gap = math.pi * 2 / Config.Floats
		expect(Parade.floatAngle(Config, 0, 1)).toBe(0)
		for index = 2, Config.Floats do
			local behind = Parade.floatAngle(Config, 5, index - 1) - Parade.floatAngle(Config, 5, index)
			assert(math.abs(behind - gap) < 1e-9, `float {index} is {behind} radians behind`)
		end
		local lap = Parade.floatAngle(Config, Config.LapSeconds, 1)
		assert(math.abs(lap - math.pi * 2) < 1e-9, "a float doesn't go once round in a lap")
	end)

	it("lets go of more lanterns with more players, and the meter wants most", function()
		expect(Parade.lanternCount(Config, 0)).toBe(Config.Lanterns + Config.LanternsPerPlayer)
		expect(Parade.lanternCount(Config, 4)).toBe(Config.Lanterns + Config.LanternsPerPlayer * 4)
		for players = 1, 12 do
			local count = Parade.lanternCount(Config, players)
			local goal = Parade.goal(Config, count)
			assert(goal >= 1 and goal < count, `{players} players need {goal} of {count}`)
			-- Everyone can play a part: there are at least a few for each.
			assert(count / players >= Config.LanternsPerPlayer, `{players} players share only {count} lanterns`)
		end
	end)

	it("spreads lanterns over the parade, each with its time to be caught", function()
		for seed = 1, 30 do
			local count = Parade.lanternCount(Config, seed % 8 + 1)
			local lanterns = Parade.schedule(Config, seeded(seed * 7919), count)
			expect(#lanterns).toBe(count)
			expect(lanterns[1].At).toBe(0)
			for i, lantern in lanterns do
				if i > 1 then
					assert(lantern.At > lanterns[i - 1].At, `seed {seed}: lantern {i} comes before the one before it`)
				end
				assert(
					lantern.At + Config.LanternSeconds <= Config.RunSeconds + 1e-9,
					`seed {seed}: lantern {i} outlasts the parade`
				)
				assert(math.abs(lantern.Offset) <= Config.Spread, `seed {seed}: lantern {i} is off the route`)
				-- Just behind a float, where it was let go.
				local float = (i - 1) % Config.Floats + 1
				local behind = Parade.floatAngle(Config, lantern.At, float) - lantern.Angle
				assert(behind >= 0.2 and behind <= 0.4 + 1e-9, `seed {seed}: lantern {i} is {behind} radians behind`)
			end
		end
	end)

	it("catches a lantern only near it and only while it's out", function()
		local lantern = { At = 10, Angle = 0, Offset = 0 }
		local x, y, z = Parade.point(ROUTE, 0, 0, Config.Height)
		expect(x).toBe(ROUTE.RadiusX)
		expect(z).toBe(0)
		expect(Parade.catches(Config, ROUTE, lantern, 11, x + 1, y, z + 1)).toBe(true)
		expect(Parade.catches(Config, ROUTE, lantern, 9.9, x, y, z)).toBe(false)
		expect(Parade.catches(Config, ROUTE, lantern, 10 + Config.LanternSeconds + 0.1, x, y, z)).toBe(false)
		expect(Parade.catches(Config, ROUTE, lantern, 11, x + Config.CatchRadius + 0.1, y, z)).toBe(false)
		expect(Parade.catches(Config, ROUTE, lantern, 11, x, y + Config.CatchHeight + 0.1, z)).toBe(false)
		-- Offset moves it out from the loop.
		local out = { At = 10, Angle = math.pi / 2, Offset = 3 }
		expect(Parade.catches(Config, ROUTE, out, 11, 0, y, ROUTE.RadiusZ + 3)).toBe(true)
		expect(Parade.catches(Config, ROUTE, out, 11, 0, y, ROUTE.RadiusZ - 3)).toBe(false)
	end)

	it("pays seconds of income for the first catches, with floors for a new plot", function()
		expect(Parade.catchReward(Config, 0, 0)).toBe(Config.MinReward)
		expect(Parade.catchReward(Config, 1000, 0)).toBe(math.floor(1000 * Config.RewardSeconds + 0.5))
		expect(Parade.catchReward(Config, 1000, Config.PaidLanterns - 1)).toBe(
			math.floor(1000 * Config.RewardSeconds + 0.5)
		)
		expect(Parade.catchReward(Config, 1000, Config.PaidLanterns)).toBe(0)
		expect(Parade.fullReward(Config, 0)).toBe(Config.FullMinReward)
		expect(Parade.fullReward(Config, 1000)).toBe(math.floor(1000 * Config.FullSeconds + 0.5))
	end)

	it("can't make the run shorter than 80 minutes, with Ghost Catcher back to back", function()
		-- The pacing tests run on passive income alone. A player who plays
		-- every Ghost Catcher round and catches all they're paid for in every
		-- parade, filling the meter each time, earns this much more on top.
		local activity = Activity.bonusShare(ActivityConfig)
		local parade = Parade.bonusShare(Config)
		local fastest = Pacing.fastest().Seconds / 60
		local minutes = fastest / (1 + activity + parade)
		print(
			`  Ghost Catcher adds {math.floor(activity * 1000 + 0.5) / 10}%, parades `
				.. `{math.floor(parade * 1000 + 0.5) / 10}%: the fastest route takes `
				.. `{math.floor(minutes * 10) / 10} minutes`
		)
		assert(minutes >= Pacing.Rules.MinMinutes, `playing everything takes the run down to {minutes} minutes`)
	end)
end)

return nil
