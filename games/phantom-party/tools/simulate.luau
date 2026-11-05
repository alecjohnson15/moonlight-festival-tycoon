-- Prints the simulation tables for docs/AUTONOMOUS_UPGRADE_REPORT.md:
-- `lune run tools/simulate` from the games/phantom-party folder. Models,
-- not measurements (see tests/Models.luau for the assumptions).

local Loader = require("../tests/RobloxLoader")
local Models = require("../tests/Models")
local Rewards = Loader.require("src/shared/Config/Rewards")

local function pct(value: number): string
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

print("Role deal, 10,000 rounds per party size (share per player: lowest to highest, fair share; longest wait)")
print("| Players | Phantom share | Fair | Longest wait | Guardian share | Medic | Saboteur |")
print("| --- | --- | --- | --- | --- | --- | --- |")
for players = 1, Models.MaxPlayers do
	local r = Models.deal(players, 10000, 100 + players)
	local function span(line)
		if line.Fair == 0 then
			return "none"
		end
		return `{pct(line.Low)} to {pct(line.High)}`
	end
	print(
		`| {players} | {span(r.Phantom)} | {pct(r.Phantom.Fair)} | {r.Phantom.LongestWait} rounds | {span(r.Guardian)} | {span(
			r.Medic
		)} | {span(r.Saboteur)} |`
	)
end

print("")
print("Truth Bell, 3,000 modelled rounds per party size: new pacing vs the first version")
print(
	"| Players | Guests | Pages to fill | Rang at all | Rang in first minute | Rings a round | Median first ring | First version: rang in first minute | First version: rings a round |"
)
print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
for _, players in { 2, 3, 4, 5, 6, 8, 10, 12 } do
	local new = Models.bell(players, 3000, players)
	local old = Models.bell(players, 3000, players, Models.oldBell(Rewards.Bell))
	print(
		`| {players} | {new.Guests} | {new.Pages} | {pct(new.Rang)} | {pct(new.Early)} | {string.format(
			"%.2f",
			new.Rings
		)} | {math.floor(new.MedianFirst)} s | {pct(old.Early)} | {string.format("%.2f", old.Rings)} |`
	)
end
