-- Ghost Catcher's rules: where and when wisps appear, what counts as a catch
-- and what rounds pay. Parade.spec checks that playing them back to back,
-- with every parade too, can't break the 90-minute pacing.

local TestKit = require("./TestKit")
local Activity = require("../src/shared/Activity")
local Config = require("../src/shared/Config/Activity")
local Layout = require("../src/shared/Config/Layout")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- A repeatable stand-in for Random, from 0 to 1.
local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = state * 16807 % 2147483647
		return state / 2147483647
	end
end

local PAD = Layout.Activity.Pad

describe("Ghost Catcher", function()
	it("spreads a round's wisps over the round, each with time to be caught", function()
		local wisps = Activity.schedule(Config, seeded(7), PAD)
		expect(#wisps).toBe(Config.Wisps)
		expect(wisps[1].At).toBe(0)
		for i = 2, #wisps do
			assert(wisps[i].At > wisps[i - 1].At, `wisp {i} appears before the one before it`)
		end
		assert(wisps[#wisps].At + Config.WispSeconds <= Config.RoundSeconds + 1e-9, "the last wisp outlasts the round")
	end)

	it("puts wisps in the strip down the plot, a run apart from each other", function()
		local area = Config.Area
		for seed = 1, 50 do
			local last = PAD
			for i, wisp in Activity.schedule(Config, seeded(seed * 7919), PAD) do
				assert(math.abs(wisp.X - area.X) <= area.Width / 2, `seed {seed}: wisp {i} is off the strip sideways`)
				assert(math.abs(wisp.Z - area.Z) <= area.Depth / 2, `seed {seed}: wisp {i} is off the strip lengthways`)
				local gap = math.sqrt((wisp.X - last.X) ^ 2 + (wisp.Z - last.Z) ^ 2)
				assert(
					gap >= Config.MinGap and gap <= Config.MaxGap,
					`seed {seed}: wisp {i} is {gap} studs from the last`
				)
				last = wisp
			end
		end
	end)

	it("keeps wisps and the players chasing them off every buy pad", function()
		-- A player catching a wisp at the edge of the strip stands up to
		-- CatchRadius beyond it, and must still be clear of every pad.
		local area = Config.Area
		local reach = Config.CatchRadius + Layout.ButtonSize / 2
		for building, spots in Layout.Buttons do
			local list = { Build = spots.Build, Upgrades = spots.Upgrades }
			for path, spot in spots.Paths or {} do
				list[path] = spot
			end
			for name, spot in list do
				local apartX = math.abs(spot.X - area.X) >= area.Width / 2 + reach
				local apartZ = math.abs(spot.Z - area.Z) >= area.Depth / 2 + reach
				assert(apartX or apartZ, `wisps can lead players onto the {building} {name} pad`)
			end
		end
	end)

	it("catches a wisp only while it is out and the player is right by it", function()
		local wisp = { At = 4, X = 0, Z = 10 }
		local y = Config.Height
		expect(Activity.catches(Config, wisp, 5, 1, y, 11)).toBe(true)
		expect(Activity.catches(Config, wisp, 3.9, 0, y, 10)).toBe(false)
		expect(Activity.catches(Config, wisp, 4 + Config.WispSeconds + 0.1, 0, y, 10)).toBe(false)
		expect(Activity.catches(Config, wisp, 5, Config.CatchRadius + 0.1, y, 10)).toBe(false)
		expect(Activity.catches(Config, wisp, 5, 0, y + Config.CatchHeight + 0.1, 10)).toBe(false)
	end)

	it("pays seconds of income per wisp, with a floor for a new plot", function()
		expect(Activity.wispReward(Config, 0)).toBe(Config.MinReward)
		expect(Activity.wispReward(Config, 1000)).toBe(math.floor(1000 * Config.RewardSeconds + 0.5))
		expect(Activity.perfectReward(Config, 0)).toBe(Config.MinReward * 2)
		expect(Activity.perfectReward(Config, 1000)).toBe(math.floor(1000 * Config.PerfectSeconds + 0.5))
	end)
end)

return nil
