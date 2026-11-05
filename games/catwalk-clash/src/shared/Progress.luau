--!strict
-- Progress that lives in the save: the Style Pass, daily challenges and the
-- login streak. Pure logic over plain tables, tested in tests/Progress.spec.

local Progress = {}

-- Style Pass ---------------------------------------------------------------

export type PassState = {
	Id: string,
	Xp: number,
	-- Claimed tiers, keyed by the tier number as a string (DataStores can't
	-- store tables with gaps in their number keys).
	Free: { [string]: boolean },
	Premium: { [string]: boolean },
}

export type SeasonInfo = { Id: string, XpPerTier: number, Tiers: { any }, Starts: number, Ends: number }

function Progress.newPass(seasonId: string): PassState
	return { Id = seasonId, Xp = 0, Free = {}, Premium = {} }
end

-- A fresh pass when a new season has started; rewards already claimed stay
-- owned in the save's Owned lists.
function Progress.passFor(state: PassState?, season: SeasonInfo): PassState
	if state == nil or state.Id ~= season.Id then
		return Progress.newPass(season.Id)
	end
	return state
end

function Progress.tier(season: SeasonInfo, xp: number): number
	return math.min(#season.Tiers, xp // season.XpPerTier)
end

function Progress.seasonOpen(season: SeasonInfo, now: number): boolean
	return now >= season.Starts and now < season.Ends
end

-- Adds XP while the season is open; returns the tiers newly reached.
function Progress.addXp(state: PassState, season: SeasonInfo, amount: number, now: number): { number }
	if amount <= 0 or not Progress.seasonOpen(season, now) then
		return {}
	end
	local before = Progress.tier(season, state.Xp)
	state.Xp += math.floor(amount)
	local after = Progress.tier(season, state.Xp)
	local reached = {}
	for tier = before + 1, after do
		table.insert(reached, tier)
	end
	return reached
end

-- Whether a tier's reward on a track ("Free" or "Premium") may be claimed.
function Progress.canClaim(
	state: PassState,
	season: SeasonInfo,
	tier: any,
	track: any,
	hasPremium: boolean
): (boolean, string?)
	if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > #season.Tiers then
		return false, "NoTier"
	end
	if track ~= "Free" and track ~= "Premium" then
		return false, "NoTrack"
	end
	if track == "Premium" and not hasPremium then
		return false, "NeedPass"
	end
	if Progress.tier(season, state.Xp) < tier then
		return false, "Locked"
	end
	if state[track][tostring(tier)] then
		return false, "Claimed"
	end
	return true, nil
end

-- Daily challenges -----------------------------------------------------------

export type QuestState = {
	Day: number,
	Ids: { string },
	Progress: { number },
	Done: { boolean },
}

export type QuestInfo = { Id: string, Event: string, Goal: number }

-- A small seeded random number generator, so every server picks the same
-- challenges for the same day.
local function seeded(seed: number): (number) -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(n: number): number
		state = (state * 48271) % 2147483647
		return state % n + 1
	end
end

-- The day's challenges: count distinct quests from the pool.
function Progress.questsFor(pool: { QuestInfo }, day: number, count: number): { string }
	local rng = seeded(day * 7919 + 17)
	local indices = {}
	for index = 1, #pool do
		indices[index] = index
	end
	local ids = {}
	for _ = 1, math.min(count, #pool) do
		local pick = table.remove(indices, rng(#indices)) :: number
		table.insert(ids, pool[pick].Id)
	end
	return ids
end

-- Today's challenge state, starting over on a new day.
function Progress.questsToday(state: QuestState?, pool: { QuestInfo }, day: number): QuestState
	if state and state.Day == day and #state.Ids > 0 then
		return state
	end
	local ids = Progress.questsFor(pool, day, 3)
	return { Day = day, Ids = ids, Progress = table.create(#ids, 0), Done = table.create(#ids, false) }
end

-- Counts an event; returns the quests it completed.
function Progress.recordQuest(state: QuestState, pool: { QuestInfo }, event: string, amount: number): { QuestInfo }
	local completed = {}
	for index, id in state.Ids do
		if not state.Done[index] then
			for _, quest in pool do
				if quest.Id == id and quest.Event == event then
					state.Progress[index] = math.min(quest.Goal, state.Progress[index] + amount)
					if state.Progress[index] >= quest.Goal then
						state.Done[index] = true
						table.insert(completed, quest)
					end
				end
			end
		end
	end
	return completed
end

-- Login streak ---------------------------------------------------------------

export type StreakState = { LastDay: number, Count: number }

-- Claims today's login reward. Returns the streak day (1, 2, ...) to pay
-- out, or nil if today was already claimed. Missing a day starts over.
function Progress.claimStreak(state: StreakState, today: number): number?
	if state.LastDay == today then
		return nil
	end
	if state.LastDay == today - 1 then
		state.Count += 1
	else
		state.Count = 1
	end
	state.LastDay = today
	return state.Count
end

-- The reward for a streak day from a list whose last value repeats.
function Progress.streakReward(rewards: { number }, streakDay: number): number
	return rewards[math.min(streakDay, #rewards)]
end

return Progress
