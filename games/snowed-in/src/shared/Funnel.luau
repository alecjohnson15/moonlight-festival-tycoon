--!strict
-- The steps the game reports to Roblox's analytics (server/Lib/Analytics),
-- so a dashboard can show where players stop: the first-time path for a
-- brand new player, and the path through each run for everyone. Each step
-- is reported once per record; a step reached early (someone fits a part
-- before they ever fed the fire) is still reported once, with its own
-- number, so the funnel shows it.

export type Record = { Steps: { string }, Done: { [string]: boolean } }

local Funnel = {}

-- A new player's first session, in the order the guide walks them.
Funnel.Onboarding = {
	"Joined",
	"PickedRole",
	"Gathered",
	"DroppedOff",
	"FedHearth",
	"SurvivedNight1",
	"FoundPart",
	"FittedPart",
	"FinishedRun",
}

-- Every run, for every player in it.
Funnel.Run = {
	"Started",
	"SurvivedNight1",
	"FoundPart",
	"FittedPart",
	"Night5",
	"RadioFixed",
	"Rescued",
}

function Funnel.new(steps: { string }): Record
	return { Steps = steps, Done = {} }
end

-- Marks a step done. Returns its number (from 1) the first time, and nil
-- if it was already done or isn't a step of this funnel.
function Funnel.mark(record: Record, step: string): number?
	local index = table.find(record.Steps, step)
	if not index or record.Done[step] then
		return nil
	end
	record.Done[step] = true
	return index
end

return Funnel
