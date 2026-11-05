--!strict
-- Which mastery goals (Config/Mastery) a player met in a round. Pure, so
-- the tests can check every goal (tests/Recap.spec).

local MasteryConfig = require(script.Parent.Parent.Config.Mastery)

export type Facts = {
	Role: string,
	Won: boolean,
	Survived: boolean,
	BellRang: boolean,
	Misfired: boolean,
	Hero: boolean,
	Dawn: boolean,
	Takedown: boolean,
	Tags: number,
	Revives: number,
	Clues: number,
	BlackoutsUsed: number,
}

local Mastery = {}

local FLAGS = { "Won", "Survived", "BellRang", "Misfired", "Hero", "Dawn", "Takedown" }

function Mastery.meets(goal: MasteryConfig.Goal, facts: Facts): boolean
	if goal.Role ~= facts.Role then
		return false
	end
	local wanted = goal :: any
	local have = facts :: any
	for _, flag in FLAGS do
		if wanted[flag] ~= nil and wanted[flag] ~= have[flag] then
			return false
		end
	end
	for stat, least in goal.Min or {} do
		if (have[stat] or 0) < least then
			return false
		end
	end
	return true
end

-- The goals met, in the order Config/Mastery lists them.
function Mastery.earned(facts: Facts, list: { MasteryConfig.Goal }?): { MasteryConfig.Goal }
	local met = {}
	for _, goal in list or MasteryConfig.List do
		if Mastery.meets(goal, facts) then
			table.insert(met, goal)
		end
	end
	return met
end

-- Adds one to each goal's count in a save's Mastery table, and returns
-- what to show: each goal's name, text and new count.
function Mastery.record(
	saved: { [string]: number },
	met: { MasteryConfig.Goal }
): { { Id: string, Name: string, Text: string, Count: number } }
	local shown = {}
	for _, goal in met do
		local count = (tonumber(saved[goal.Id]) or 0) + 1
		saved[goal.Id] = count
		table.insert(shown, { Id = goal.Id, Name = goal.Name, Text = goal.Text, Count = count })
	end
	return shown
end

return Mastery
