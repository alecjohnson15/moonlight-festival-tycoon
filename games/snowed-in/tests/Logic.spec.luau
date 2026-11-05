-- The run's clock, the waves, the stockpile, the build grid, the snapshot
-- codec and warmth.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Codec = RobloxLoader.require("src/shared/Codec")
local Cycle = RobloxLoader.require("src/shared/Cycle")
local Grid = RobloxLoader.require("src/shared/Grid")
local Stock = RobloxLoader.require("src/shared/Stock")
local Warmth = RobloxLoader.require("src/shared/Warmth")
local Waves = RobloxLoader.require("src/shared/Waves")
local Enemies = RobloxLoader.require("src/shared/Config/Enemies")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- A fixed sequence of rolls, the same every run.
local function roller(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

describe("cycle", function()
	it("goes day, dusk, night, dawn and counts the nights", function()
		local state = { Phase = "Intermission", Night = 0, Called = false }
		state = Cycle.next(state)
		expect(state.Phase).toBe("Day")
		expect(state.Night).toBe(0)
		state = Cycle.next(state)
		expect(state.Phase).toBe("Dusk")
		state = Cycle.next(state)
		expect(state.Phase).toBe("Night")
		expect(state.Night).toBe(1)
		state = Cycle.next(state)
		expect(state.Phase).toBe("Dawn")
		state = Cycle.next(state)
		expect(state.Phase).toBe("Day")
		expect(state.Night).toBe(1)
	end)

	it("sends the train after the last night only if the radio called it", function()
		local called = Cycle.next({ Phase = "Dawn", Night = Balance.Nights, Called = true })
		expect(called.Phase).toBe("Rescue")
		expect(Cycle.next(called).Phase).toBe("Won")
		local notCalled = Cycle.next({ Phase = "Dawn", Night = Balance.Nights, Called = false })
		expect(notCalled.Phase).toBe("Day")
		local tooLate = Cycle.next({ Phase = "Dawn", Night = Balance.LastNight, Called = false })
		expect(tooLate.Phase).toBe("Lost")
		-- A train called late still comes at the next dawn.
		local late = Cycle.next({ Phase = "Dawn", Night = Balance.Nights + 2, Called = true })
		expect(late.Phase).toBe("Rescue")
	end)

	it("starts over after the results", function()
		expect(Cycle.next({ Phase = "Won", Night = 10, Called = true }).Phase).toBe("Intermission")
		expect(Cycle.next({ Phase = "Lost", Night = 4, Called = false }).Phase).toBe("Intermission")
	end)

	it("makes the first day longer", function()
		assert(Cycle.length("Day", 0) > Cycle.length("Day", 1), "first day should be longer")
	end)

	it("runs the sky from morning through the night", function()
		expect(Cycle.clock("Day", 0)).toBe(7)
		expect(Cycle.clock("Day", 1)).toBe(17)
		expect(Cycle.clock("Night", 0.5) > 23 or Cycle.clock("Night", 0.5) < 1).toBe(true)
		expect(Cycle.clock("Dawn", 1)).toBe(7)
	end)

	it("takes about 45 minutes to reach the train", function()
		local total = Cycle.length("Day", 0)
		for night = 1, Balance.Nights do
			total += Cycle.length("Dusk", night) + Cycle.length("Night", night) + Cycle.length("Dawn", night)
			if night < Balance.Nights then
				total += Cycle.length("Day", night)
			end
		end
		local minutes = total / 60
		assert(minutes > 35 and minutes < 60, `a full run takes {minutes} minutes`)
	end)
end)

describe("waves", function()
	it("grows with the night and the team", function()
		assert(Waves.budget(5, 1) > Waves.budget(1, 1), "later nights should be bigger")
		assert(Waves.budget(3, 4) > Waves.budget(3, 1), "more players should mean more monsters")
		expect(Waves.multiplier(100)).toBe(Balance.Waves.Max)
	end)

	it("spends the budget exactly, on kinds that have arrived", function()
		for night = 1, Balance.LastNight do
			for _, players in { 1, 3, 8 } do
				local list = Waves.compose(night, players, roller(night * 31 + players))
				local spent = 0
				for _, kind in list do
					local enemy = Enemies.ById[kind]
					assert(enemy.From <= night, `{kind} came too early on night {night}`)
					assert(not enemy.Boss, "bosses are not bought with points")
					spent += enemy.Points
				end
				expect(spent).toBe(Waves.budget(night, players))
			end
		end
	end)

	it("only sends frostlings on the first night", function()
		for _, kind in Waves.compose(1, 4, roller(9)) do
			expect(kind).toBe("Frostling")
		end
	end)

	it("keeps at least half the budget for the small monsters", function()
		for night = 3, 12 do
			local big = 0
			for _, kind in Waves.compose(night, 8, roller(night)) do
				local enemy = Enemies.ById[kind]
				if enemy.Id ~= "Frostling" and enemy.Id ~= "SnowHound" then
					big += enemy.Points
				end
			end
			assert(big <= Waves.budget(night, 8) * 0.5, `night {night} is mostly big monsters`)
		end
	end)

	it("adds the bosses on their nights and spreads the arrivals", function()
		expect(Waves.boss(5)).toBe("Yeti")
		expect(Waves.boss(10)).toBe("ElderYeti")
		expect(Waves.boss(4)).toBe(nil)
		local list = Waves.compose(5, 2, roller(4))
		local spawns = Waves.schedule(list, "Yeti", Balance.Phases.Night, roller(5))
		expect(#spawns).toBe(#list + 1)
		local window = Balance.Phases.Night * Balance.Waves.SpawnWindow
		local last = 0
		for _, spawn in spawns do
			assert(spawn.At >= last, "spawns are in time order")
			assert(spawn.At <= window, "spawns come in the first part of the night")
			assert(spawn.Point >= 1 and spawn.Point <= 8, "spawn point in range")
			last = spawn.At
		end
	end)

	it("gives a solo boss less health than a full server's", function()
		assert(Waves.bossHealth("Yeti", 1) < Waves.bossHealth("Yeti", 8), "boss health scales")
	end)
end)

describe("stock", function()
	it("spends only what it can afford", function()
		local counts = Stock.empty()
		counts.Wood = 10
		expect(Stock.spend(counts, { Wood = 12 })).toBe(false)
		expect(counts.Wood).toBe(10)
		expect(Stock.spend(counts, { Wood = 6 })).toBe(true)
		expect(counts.Wood).toBe(4)
	end)

	it("rounds discounts up so nothing is free", function()
		expect(Stock.discount({ Wood = 3, Coal = 1 }, 0.25).Wood).toBe(3)
		expect(Stock.discount({ Wood = 3, Coal = 1 }, 0.25).Coal).toBe(1)
		expect(Stock.discount({ Wood = 8 }, 0.25).Wood).toBe(6)
	end)

	it("fills a backpack up to its size and says what fit", function()
		local pack = { Wood = 18 }
		local moved = Stock.fill(pack, 20, { Wood = 5 })
		expect(moved.Wood).toBe(2)
		expect(Stock.total(pack)).toBe(20)
	end)

	it("describes costs in the HUD's order", function()
		expect(Stock.describe({ Stone = 2, Wood = 6 })).toBe("6 Wood, 2 Stone")
		expect(Stock.describe({})).toBe("Free")
	end)
end)

describe("build grid", function()
	local function rules(built)
		return { HearthX = 0, HearthZ = 0, Keep = { { X = 20, Z = 24, R = 6 } }, Built = built or {} }
	end

	it("snaps to the grid and turns footprints", function()
		local rect = Grid.place("WoodWall", 21, -33, 1)
		expect(rect.X).toBe(20)
		expect(rect.Z).toBe(-32)
		expect(rect.HalfW).toBe(1)
		expect(rect.HalfD).toBe(4)
	end)

	it("keeps the hearth, the stations and the edge clear", function()
		expect((Grid.check(Grid.place("WoodWall", 4, 0, 0), rules()))).toBe(false)
		expect((Grid.check(Grid.place("WoodWall", 20, 24, 0), rules()))).toBe(false)
		expect((Grid.check(Grid.place("WoodWall", 200, 0, 0), rules()))).toBe(false)
		expect((Grid.check(Grid.place("WoodWall", 0, -40, 0), rules()))).toBe(true)
	end)

	it("lets walls meet end to end but not overlap", function()
		local first = Grid.place("WoodWall", 0, -40, 0)
		local beside = Grid.place("WoodWall", 8, -40, 0)
		local over = Grid.place("WoodWall", 4, -40, 0)
		expect((Grid.check(beside, rules({ first })))).toBe(true)
		expect((Grid.check(over, rules({ first })))).toBe(false)
	end)
end)

describe("snapshot codec", function()
	it("round-trips positions, kinds, poses and health", function()
		local data = Codec.encode({
			{ Id = 7, Kind = "SnowBrute", Action = "Attack", X = -120.5, Z = 64.25, Health = 0.5, Heading = math.pi },
			{ Id = 65535, Kind = "ElderYeti", Action = "Idle", X = 3, Z = -4, Health = 1, Heading = 0 },
		})
		local entries = Codec.decode(data)
		expect(#entries).toBe(2)
		expect(entries[1].Id).toBe(7)
		expect(entries[1].Kind).toBe("SnowBrute")
		expect(entries[1].Action).toBe("Attack")
		expect(entries[1].X).toBe(-120.5)
		expect(entries[1].Z).toBe(64.25)
		assert(math.abs(entries[1].Health - 0.5) < 0.01, "health survives")
		assert(math.abs(entries[1].Heading - math.pi) < 0.03, "heading survives")
		expect(entries[2].Id).toBe(65535)
		expect(entries[2].Kind).toBe("ElderYeti")
	end)

	it("ignores a short or broken buffer", function()
		expect(#Codec.decode(buffer.create(1))).toBe(0)
		local broken = buffer.create(4)
		buffer.writeu16(broken, 0, 3)
		expect(#Codec.decode(broken)).toBe(0)
	end)
end)

describe("warmth", function()
	it("warms at the hearth and cools faster at night", function()
		local at = Warmth.rate({ AtHearth = true, NearWarmth = false, Night = true, Resists = {} })
		local day = Warmth.rate({ AtHearth = false, NearWarmth = false, Night = false, Resists = {} })
		local night = Warmth.rate({ AtHearth = false, NearWarmth = false, Night = true, Resists = {} })
		assert(at > 0, "the hearth warms")
		assert(day < 0 and night < day, "night is colder than day")
	end)

	it("lets resists stack without ever making a player immune", function()
		local rate = Warmth.rate({ AtHearth = false, NearWarmth = false, Night = true, Resists = { 0.9, 0.9, 0.9 } })
		assert(rate < 0, "still gets cold")
		local coat = Warmth.rate({ AtHearth = false, NearWarmth = false, Night = true, Resists = { 0.25 } })
		local bare = Warmth.rate({ AtHearth = false, NearWarmth = false, Night = true, Resists = {} })
		assert(math.abs(coat - bare * 0.75) < 1e-9, "a 25% resist cuts the cold by 25%")
	end)

	it("gives a lone player time to explore by day", function()
		local seconds = Balance.Warmth.Max / Balance.Warmth.DrainDay
		assert(seconds > 240, `a full warmth bar lasts {seconds} seconds by day`)
	end)
end)
