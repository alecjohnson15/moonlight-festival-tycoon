-- The monster sim and the weapons: who walks where, who hits what, and
-- that a defended hearth outlasts a night while an empty one doesn't.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Combat = RobloxLoader.require("src/shared/Combat")
local EnemySim = RobloxLoader.require("src/shared/EnemySim")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function world()
	return EnemySim.newWorld(0, 0, 5, {})
end

local function run(sim, seconds: number): { any }
	local all = {}
	for _ = 1, math.floor(seconds * 10) do
		for _, event in EnemySim.step(sim, 0.1) do
			table.insert(all, event)
		end
	end
	return all
end

local function count(events, kind: string): number
	local n = 0
	for _, event in events do
		if event.Type == kind then
			n += 1
		end
	end
	return n
end

describe("monster sim", function()
	it("walks a frostling to the hearth and douses it", function()
		local sim = world()
		local frostling = EnemySim.spawn(sim, "Frostling", 0, -100)
		local events = run(sim, 12)
		assert(math.abs(frostling.Z) < 12, `frostling stopped at z={frostling.Z}`)
		assert(count(events, "Douse") > 0, "it should hit the hearth")
	end)

	it("stops at a wall and smashes it instead", function()
		local sim = world()
		EnemySim.addStructure(sim, 1, "WoodWall", 0, -40, 0)
		local frostling = EnemySim.spawn(sim, "Frostling", 0, -100)
		local events = run(sim, 10)
		assert(frostling.Z < -40, "the wall holds it back")
		expect(count(events, "Douse")).toBe(0)
		assert(count(events, "Smash") > 0, "it hits the wall")
	end)

	it("lets wisps fly over walls", function()
		local sim = world()
		EnemySim.addStructure(sim, 1, "StoneWall", 0, -40, 0)
		local wisp = EnemySim.spawn(sim, "IceWisp", 0, -100)
		run(sim, 12)
		assert(wisp.Z > -40, "a wisp passes the wall")
	end)

	it("sends hounds after players and hits them", function()
		local sim = world()
		sim.Players.alex = { X = 30, Z = -60, Frozen = false }
		local hound = EnemySim.spawn(sim, "SnowHound", 0, -100)
		local events = run(sim, 5)
		local hits = 0
		for _, event in events do
			if event.Type == "Hit" and event.Player == "alex" then
				hits += 1
			end
		end
		assert(hits > 0, "the hound should reach the player")
		assert(math.abs(hound.X - 30) < 8, "and stay on them")
	end)

	it("leaves frozen players alone", function()
		local sim = world()
		sim.Players.sam = { X = 0, Z = -60, Frozen = true }
		EnemySim.spawn(sim, "SnowHound", 0, -70)
		local events = run(sim, 3)
		for _, event in events do
			assert(not (event.Type == "Hit" and event.Player == "sam"), "a frozen player is not hit")
		end
	end)

	it("sends brutes at buildings first", function()
		local sim = world()
		EnemySim.addStructure(sim, 9, "EmberTurret", 30, -60, 0)
		local brute = EnemySim.spawn(sim, "SnowBrute", 30, -95)
		sim.Structures[9].Cooldown = math.huge
		local events = run(sim, 8)
		local smashed = false
		for _, event in events do
			if event.Type == "Smash" and event.Structure == 9 then
				smashed = true
			end
		end
		assert(smashed, `brute at {brute.X},{brute.Z} should smash the turret`)
	end)

	it("keeps guards near home", function()
		local sim = world()
		local guard = EnemySim.spawnGuard(sim, "Frostling", 200, 200, 30)
		sim.Players.kim = { X = 200, Z = 215, Frozen = false }
		run(sim, 2)
		assert(math.abs(guard.Z - 215) < 6, "the guard goes for a nearby player")
		sim.Players.kim = { X = 0, Z = 0, Frozen = false }
		run(sim, 6)
		assert(math.abs(guard.X - 200) < 4 and math.abs(guard.Z - 200) < 4, "and goes home when they leave")
	end)

	it("spreads a crowd out", function()
		local sim = world()
		local a = EnemySim.spawn(sim, "Frostling", 50, 50)
		local b = EnemySim.spawn(sim, "Frostling", 50, 50)
		EnemySim.step(sim, 0.1)
		assert(math.abs(a.X - b.X) + math.abs(a.Z - b.Z) > 0.5, "two monsters don't share a spot")
	end)

	it("walks round obstacles", function()
		local sim = EnemySim.newWorld(0, 0, 5, { { X = 0, Z = -50, R = 10 } })
		local frostling = EnemySim.spawn(sim, "Frostling", 0, -100)
		for _ = 1, 120 do
			EnemySim.step(sim, 0.1)
			local d = math.sqrt(frostling.X ^ 2 + (frostling.Z + 50) ^ 2)
			assert(d >= 10 + frostling.Def.Radius - 0.01, "never inside the obstacle")
		end
	end)

	it("lets turrets and traps knock monsters out", function()
		local sim = world()
		EnemySim.addStructure(sim, 1, "EmberTurret", 0, -20, 0)
		EnemySim.addStructure(sim, 2, "EmberTrap", 20, -30, 0)
		EnemySim.spawn(sim, "Frostling", 0, -50)
		EnemySim.spawn(sim, "Frostling", 20, -31)
		local events = run(sim, 10)
		expect(count(events, "Down")).toBe(2)
	end)

	it("lets a boss slam everything around it", function()
		local sim = world()
		sim.Players.a = { X = 0, Z = -14, Frozen = false }
		sim.Players.b = { X = 6, Z = -12, Frozen = false }
		EnemySim.spawn(sim, "Yeti", 0, -22)
		local events = run(sim, 2)
		assert(count(events, "Slam") >= 1, "the yeti slams")
		local hitA, hitB = false, false
		for _, event in events do
			if event.Type == "Hit" then
				hitA = hitA or event.Player == "a"
				hitB = hitB or event.Player == "b"
			end
		end
		assert(hitA and hitB, "both players are caught in the slam")
	end)

	it("clears the night's monsters at dawn but keeps the guards", function()
		local sim = world()
		EnemySim.spawn(sim, "Frostling", 0, -50)
		EnemySim.spawnGuard(sim, "Frostling", 100, 100, 20)
		expect(#EnemySim.clear(sim, true)).toBe(1)
		expect(EnemySim.count(sim)).toBe(1)
	end)
end)

describe("weapons", function()
	it("swings the torch at everything close in front", function()
		local sim = world()
		local front = EnemySim.spawn(sim, "Frostling", 0, -6)
		EnemySim.spawn(sim, "Frostling", 0, 8)
		local result = Combat.resolve(sim, "Torch", 0, 0, 0, -20, 1)
		expect(#result.Hits).toBe(1)
		expect(result.Hits[1].Id).toBe(front.Id)
	end)

	it("hits the first monster along a shot, with a little aim assist", function()
		local sim = world()
		local near = EnemySim.spawn(sim, "Frostling", 2, -30)
		EnemySim.spawn(sim, "Frostling", 0, -50)
		local result = Combat.resolve(sim, "EmberSling", 0, 0, 0, -100, 1)
		expect(#result.Hits).toBe(1)
		expect(result.Hits[1].Id).toBe(near.Id)
	end)

	it("misses what is out of range", function()
		local sim = world()
		EnemySim.spawn(sim, "Frostling", 0, -120)
		expect(#Combat.resolve(sim, "EmberSling", 0, 0, 0, -200, 1).Hits).toBe(0)
	end)

	it("bursts a flare over a group", function()
		local sim = world()
		EnemySim.spawn(sim, "Frostling", 0, -40)
		EnemySim.spawn(sim, "Frostling", 4, -44)
		EnemySim.spawn(sim, "Frostling", -5, -42)
		EnemySim.spawn(sim, "Frostling", 30, -40)
		local result = Combat.resolve(sim, "FlarePistol", 0, 0, 0, -60, 1)
		expect(#result.Hits).toBe(3)
	end)

	it("adds the player's damage bonus", function()
		local sim = world()
		EnemySim.spawn(sim, "Frostling", 0, -6)
		local result = Combat.resolve(sim, "Torch", 0, 0, 0, -10, 1.25)
		expect(result.Hits[1].Damage).toBe(15)
	end)

	it("knocks out and reports who did it", function()
		local sim = world()
		local frostling = EnemySim.spawn(sim, "Frostling", 0, -6)
		local events = {}
		EnemySim.damage(sim, frostling.Id, 100, "alex", events)
		expect(events[1].Type).toBe("Down")
		expect(events[1].By).toBe("alex")
		expect(EnemySim.count(sim)).toBe(0)
	end)
end)
