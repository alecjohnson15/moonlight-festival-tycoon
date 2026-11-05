-- Whole runs played out by the deterministic model (tools/RunModel): the
-- milestone timings against their design targets, difficulty over nights
-- 1 to 15, solo and small teams, role fairness and the snowflake economy,
-- for 1, 2, 4 and 8 players. These check the numbers hang together; they
-- say nothing about how a run feels, which needs real players.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")
local RunModel = require("../tools/RunModel")

local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Features = RobloxLoader.require("src/shared/Config/Features")
local Milestones = RobloxLoader.require("src/shared/Milestones")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SIZES = { 1, 2, 4, 8 }

-- How far a modelled milestone may land from its design target.
local function tolerance(minutes: number): number
	return math.max(3, minutes * 0.15)
end

describe("pacing", function()
	it("lands the milestones near their design targets for a steady team of four", function()
		local result = RunModel.run(RunModel.team(4), "Steady")
		for _, milestone in Milestones.List do
			local at = result.Milestones[milestone.Id]
			assert(at ~= nil, `{milestone.Id} is reached`)
			local off = math.abs(at - milestone.Minute)
			assert(
				off <= tolerance(milestone.Minute),
				`{milestone.Id} lands at {string.format("%.1f", at)} min, target {milestone.Minute}`
			)
		end
	end)

	it("reaches every milestone, in order, at every team size", function()
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Steady")
			expect(result.Won).toBe(true)
			local last = 0
			for _, milestone in Milestones.List do
				local at = result.Milestones[milestone.Id]
				assert(at ~= nil, `{players} players reach {milestone.Id}`)
				assert(at >= last - 0.01, `{players} players: {milestone.Id} comes in order`)
				assert(
					math.abs(at - milestone.Minute) <= tolerance(milestone.Minute),
					`{players} players: {milestone.Id} at {string.format("%.1f", at)} min`
				)
				last = at
			end
		end
	end)

	it("never leaves more than 15 minutes without a milestone or a new kind of night", function()
		local result = RunModel.run(RunModel.team(4), "Steady")
		local moments = { 0 }
		for _, at in result.Milestones do
			table.insert(moments, at)
		end
		-- A themed night the run hasn't had yet is something new too.
		local seen = {}
		for _, entry in result.Nights do
			if not seen[entry.Theme] then
				seen[entry.Theme] = true
				table.insert(moments, RunModel.nightStart(entry.Night) / 60)
			end
		end
		table.sort(moments)
		for index = 2, #moments do
			local gap = moments[index] - moments[index - 1]
			assert(gap <= 15, `a {string.format("%.1f", gap)} minute gap after minute {moments[index - 1]}`)
		end
	end)

	it("keeps a steady team on the catch-up schedule, and lets an eager team go faster", function()
		for _, players in SIZES do
			local steady = RunModel.run(RunModel.team(players), "Steady")
			for _, entry in steady.Nights do
				expect(entry.Behind).toBe(false)
			end
			local eager = RunModel.run(RunModel.team(players), "Eager")
			assert(eager.Milestones.Radio < steady.Milestones.Radio, `{players}: eager fixes the radio sooner`)
			expect(eager.Won).toBe(true)
		end
	end)

	it("fits every expedition inside a day, so a part never waits for the night", function()
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Eager")
			expect(result.Parts).toBe(4)
		end
	end)
end)

describe("difficulty", function()
	it("makes the boss nights the hardest of the ten", function()
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Steady")
			local peak = RunModel.peak(result)
			local hardest = 0
			for _, entry in result.Nights do
				if entry.Night <= Balance.Nights and entry.Pressure == peak then
					hardest = entry.Night
				end
			end
			assert(Balance.Bosses[hardest] ~= nil, `{players} players: night {hardest} is the hardest`)
		end
	end)

	it("sends more and more monsters, faster in overtime", function()
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Never")
			local function average(from: number, to: number): number
				local sum = 0
				for night = from, to do
					sum += result.Nights[night].WaveHealth
				end
				return sum / (to - from + 1)
			end
			assert(average(4, 6) > average(1, 3), `{players}: the middle nights outgrow the first`)
			assert(average(7, 9) > average(4, 6), `{players}: the late nights outgrow the middle`)
			assert(average(11, 15) > average(6, 10) * 1.4, `{players}: overtime gets much harder`)
		end
	end)

	it("ends a run without the radio at the last night, never before or after", function()
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Never")
			expect(result.Won).toBe(false)
			expect(result.LostOn).toBe(Balance.LastNight)
			expect(result.Milestones.Rescue).toBe(nil)
		end
	end)

	it("keeps every team able to clear its waves, with room to spare", function()
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Steady")
			assert(RunModel.peak(result) < 0.8, `{players} players: peak {RunModel.peak(result)}`)
			assert(RunModel.lowest(result) > 0, `{players} players: the fire never goes out`)
		end
	end)

	it("lets a team beat a boss sooner by hitting it while it is out of breath", function()
		-- The phases add help for the boss (its roars) but also openings
		-- (double damage after each slam); for every team size the openings
		-- win, so the Old Yeti goes down sooner than a plain health sponge.
		for _, players in SIZES do
			local with = RunModel.run(RunModel.team(players), "Steady")
			Features.BossPhases = false
			local ok, without = pcall(RunModel.run, RunModel.team(players), "Steady")
			Features.BossPhases = true
			assert(ok, without)
			assert(with.Milestones.Yeti ~= nil, `{players} players beat the Old Yeti`)
			assert(
				with.Milestones.Yeti < (without :: any).Milestones.Yeti,
				`{players} players beat it sooner with the openings`
			)
		end
	end)
end)

describe("solo and small teams", function()
	it("lets one player win at the steady pace", function()
		local solo = RunModel.run(RunModel.team(1), "Steady")
		expect(solo.Won).toBe(true)
		expect(solo.BeatYeti).toBe(true)
	end)

	it("keeps the fire from eating a solo player's whole day", function()
		local with = RunModel.run(RunModel.team(1), "Steady")
		Features.SoloAssist = false
		local ok, without = pcall(RunModel.run, RunModel.team(1), "Steady")
		Features.SoloAssist = true
		assert(ok, without)
		local share = with.Fuel / with.Gathered
		assert(share < 0.25, `a solo player burns {share} of what they gather`)
		assert(share < (without :: any).Fuel / (without :: any).Gathered, "the assist lightens the chore")
	end)

	it("gives everyone something to do: a big team's fuel is a small share", function()
		local share = {}
		for _, players in SIZES do
			local result = RunModel.run(RunModel.team(players), "Steady")
			share[players] = result.Fuel / result.Gathered
		end
		assert(share[8] < share[4] and share[4] < share[1], "the fire is a smaller chore with more hands")
	end)
end)

describe("roles", function()
	local base = RunModel.peak(RunModel.run(RunModel.Compositions.Free, "Steady"))

	it("lets every composition win, so no role is ever required", function()
		for name, roles in RunModel.Compositions do
			local result = RunModel.run(roles, "Steady")
			assert(result.Won, `{name} wins`)
		end
		for _, players in SIZES do
			assert(RunModel.run(RunModel.team(players), "Steady").Won, `free roles win with {players}`)
		end
	end)

	it("keeps a paid role's edge to the team small", function()
		-- Ranger and Medic can be bought early with a pass or earned with
		-- snowflakes. They do help a team (the model says so, and the docs
		-- say so); this keeps that help small next to the team's own play.
		for _, name in { "FreeRanger", "FreeMedic" } do
			local peak = RunModel.peak(RunModel.run(RunModel.Compositions[name], "Steady"))
			local edge = (base - peak) / base
			assert(edge < 0.15, `{name} eases the hardest night by {string.format("%.0f%%", edge * 100)}`)
		end
	end)

	it("keeps a team of one role within reach of a mixed team", function()
		for _, name in { "AllScouts", "AllBuilders", "AllCooks", "AllRangers", "AllMedics" } do
			local peak = RunModel.peak(RunModel.run(RunModel.Compositions[name], "Steady"))
			local off = math.abs(peak - base) / base
			assert(off < 0.25, `{name} is {string.format("%.0f%%", off * 100)} off a mixed team`)
		end
	end)

	it("gives every role something it does best", function()
		local sheet = {}
		local bestGather, bestDps = 0, 0
		for _, row in RunModel.roleSheet() do
			sheet[row.Id] = row
			bestGather = math.max(bestGather, row.GatherPerMinute)
			bestDps = math.max(bestDps, row.TorchDps)
		end
		expect(sheet.Scout.GatherPerMinute).toBe(bestGather)
		expect(sheet.Ranger.TorchDps).toBe(bestDps)
		assert(sheet.Builder.BuildDiscount > 0, "the Builder builds cheaper")
		assert(sheet.Cook.TeamUptime > 0 and sheet.Medic.TeamUptime > 0, "the Cook and Medic keep the team going")
	end)
end)

describe("snowflakes", function()
	local win = RunModel.run(RunModel.team(4), "Steady")
	local loss = RunModel.loss(6, 2, 30)

	it("puts the first earned role a few wins and a few hours away", function()
		local always = RunModel.economy(win, loss, 1)
		assert(always.RunsToFirstRole >= 2 and always.RunsToFirstRole <= 6, `{always.RunsToFirstRole} wins`)
		local half = RunModel.economy(win, loss, 0.5)
		assert(half.HoursToFirstRole >= 1 and half.HoursToFirstRole <= 6, `{half.HoursToFirstRole} hours`)
	end)

	it("takes several runs to finish the pass and many to buy everything", function()
		local half = RunModel.economy(win, loss, 0.5)
		assert(half.RunsToPass >= 4 and half.RunsToPass <= 15, `{half.RunsToPass} runs for the pass`)
		assert(half.RunsToEverything >= 10, `{half.RunsToEverything} runs to buy everything`)
	end)

	it("still pays a lost run", function()
		assert(RunModel.flakes(loss) > 0, "a loss pays")
		assert(RunModel.flakes(win) > 2 * RunModel.flakes(loss), "a win pays much more")
	end)
end)
