-- Prints whole runs from the deterministic model (tools/RunModel.luau) with
-- the numbers in Config: the night themes, every night for a steady team
-- of 4 (wave, boss, what the team can deal, the fire), the milestones and
-- outcome for 1, 2, 4 and 8 players at three radio paces, the roles side by
-- side and the snowflake economy. Run it from games/snowed-in with
-- `lune run tools/simulate_run`. A model, not a play-test: see the
-- assumptions printed at the end.

local RunModel = require("./RunModel")
local RobloxLoader = require("../tests/RobloxLoader")

local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Milestones = RobloxLoader.require("src/shared/Milestones")
local Waves = RobloxLoader.require("src/shared/Waves")

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local plan = Waves.plan(1225)
local themes = {}
for night = 1, Balance.LastNight do
	table.insert(themes, `{night} {plan[night].Id}`)
end
print("Night themes (seed 1225): " .. table.concat(themes, ", "))

print("\nA steady team of 4 (Scout, Builder, Cook, Scout), night by night:")
print(
	"night  starts  theme      wave hp  boss hp  can deal  pressure  flame lost  at dawn  hearth  turrets  best weapon"
)
local four = RunModel.run(RunModel.team(4), "Steady")
for _, entry in four.Nights do
	print(
		string.format(
			"%5d  %6s  %-9s  %7.0f  %7.0f  %8.0f  %8.2f  %10.1f  %7.1f  %6d  %7d  %s",
			entry.Night,
			clock(RunModel.nightStart(entry.Night)),
			entry.Theme,
			entry.WaveHealth,
			entry.BossHealth,
			entry.Capacity,
			entry.Pressure,
			entry.FlameLost,
			entry.FlameAtDawn,
			entry.Level,
			entry.Turrets,
			entry.BestWeapon
		)
	)
end

print("\nMilestones (minutes) and outcome by team size and radio pace:")
local header = { "players  pace    " }
for _, milestone in Milestones.List do
	table.insert(header, string.format("%9s", milestone.Id))
end
table.insert(header, "  outcome   peak  fuel share")
print(table.concat(header, ""))
local targets = { "target   design  " }
for _, milestone in Milestones.List do
	table.insert(targets, string.format("%9.1f", milestone.Minute))
end
print(table.concat(targets, ""))
for _, players in { 1, 2, 4, 8 } do
	for _, pace in { "Steady", "Eager", "Never" } do
		local result = RunModel.run(RunModel.team(players), pace)
		local row = { string.format("%7d  %-8s", players, pace) }
		for _, milestone in Milestones.List do
			local at = result.Milestones[milestone.Id]
			table.insert(row, if at then string.format("%9.1f", at) else "        -")
		end
		table.insert(
			row,
			string.format(
				"  %-8s  %.2f  %.2f",
				if result.Won then "won" else `lost {result.LostOn}`,
				RunModel.peak(result),
				result.Fuel / result.Gathered
			)
		)
		print(table.concat(row, ""))
	end
end

print("\nRoles side by side (team of 4, same conditions):")
print("role     price  gather/min  torch dps  sling dps  build discount  team uptime")
for _, row in RunModel.roleSheet() do
	print(
		string.format(
			"%-7s  %5d  %10.1f  %9.1f  %9.1f  %14.0f%%  %10.0f%%",
			row.Id,
			row.Price,
			row.GatherPerMinute,
			row.TorchDps,
			row.SlingDps,
			row.BuildDiscount * 100,
			row.TeamUptime * 100
		)
	)
end
local base = RunModel.peak(RunModel.run(RunModel.Compositions.Free, "Steady"))
print("\nTeam compositions of 4 (hardest night's pressure; lower is easier):")
local names = {}
for name in RunModel.Compositions do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local result = RunModel.run(RunModel.Compositions[name], "Steady")
	local peak = RunModel.peak(result)
	print(
		string.format(
			"%-12s %-32s %s  peak %.3f (%+.0f%% vs free)",
			name,
			table.concat(RunModel.Compositions[name], ","),
			if result.Won then "won " else "lost",
			peak,
			(peak - base) / base * 100
		)
	)
end

print("\nSnowflakes (a won run with 4, and a run lost on night 6 with 2 parts):")
local loss = RunModel.loss(6, 2, 30)
print(
	string.format(
		"a win pays %d, a loss %d; a win takes %.0f minutes",
		RunModel.flakes(four),
		RunModel.flakes(loss),
		RunModel.runMinutes(four)
	)
)
for _, rate in { 1, 0.5, 0.25 } do
	local economy = RunModel.economy(four, loss, rate)
	print(
		string.format(
			"winning %3.0f%%: %3.0f flakes a run; first role in %.1f runs (%.1f hours); pass in %.1f runs; everything (%d) in %.1f runs",
			rate * 100,
			economy.FlakesPerRun,
			economy.RunsToFirstRole,
			economy.HoursToFirstRole,
			economy.RunsToPass,
			economy.ShopTotal,
			economy.RunsToEverything
		)
	)
end

print("\nAssumptions (guesses about players, not game rules; see tools/RunModel.luau):")
local keys = {}
for key, value in RunModel.Assumptions do
	if type(value) == "number" then
		table.insert(keys, key)
	end
end
table.sort(keys)
local parts = {}
for _, key in keys do
	table.insert(parts, `{key} {RunModel.Assumptions[key]}`)
end
print(table.concat(parts, ", "))
