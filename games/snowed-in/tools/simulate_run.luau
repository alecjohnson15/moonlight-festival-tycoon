-- Prints a whole run night by night with the numbers in Config/Balance:
-- how long it has taken, how much the hearth burns, how many monsters come
-- for a team of 1, 4 and 8, and which bosses turn up. Run it from
-- games/snowed-in with `lune run tools/simulate_run`.

local RobloxLoader = require("../tests/RobloxLoader")

local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Waves = RobloxLoader.require("src/shared/Waves")

-- A repeatable roll, so the printout is the same every time.
local seed = 1225
local function roll(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local phases = Balance.Phases
local hearth = Balance.Hearth
local elapsed = phases.Intermission

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function crowd(night: number, players: number): string
	local counts = {}
	for _, kind in Waves.compose(night, players, roll) do
		counts[kind] = (counts[kind] or 0) + 1
	end
	local parts = {}
	for kind, count in counts do
		table.insert(parts, `{count} {kind}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

print("night  starts   burn  budget 1/4/8   crowd for 4 players")
for night = 1, Balance.Nights do
	local day = if night == 1 then phases.FirstDay else phases.Day
	elapsed += day + phases.Dusk
	local burn = (day + phases.Dusk + phases.Dawn) * hearth.BurnPerSecondDay + phases.Night * hearth.BurnPerSecondNight
	local boss = Balance.Bosses[night]
	print(
		string.format(
			"%5d  %6s  %5.1f  %3d/%3d/%3d   %s%s",
			night,
			clock(elapsed),
			burn,
			Waves.budget(night, 1),
			Waves.budget(night, 4),
			Waves.budget(night, 8),
			crowd(night, 4),
			if boss then ` + {boss}` else ""
		)
	)
	elapsed += phases.Night + phases.Dawn
end
elapsed += 14
print(`\nThe train arrives at {clock(elapsed)} if the radio was fixed.`)
print(
	`Unfed, the hearth ({hearth.StartFlame}) burns {string.format("%.0f", hearth.BurnPerSecondDay * 60)} a minute by day and {string.format(
		"%.0f",
		hearth.BurnPerSecondNight * 60
	)} a minute by night.`
)
