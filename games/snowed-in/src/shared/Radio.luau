--!strict
-- The rules of the rescue radio, as plain data so the tests can play every
-- case out: four parts, each Frozen at its landmark, then Loose on the
-- ground, Carried by one player, and Fitted at the radio tower. When all
-- four are fitted the radio calls the train. The server (ObjectiveService)
-- keeps one Radio, asks it before doing anything, and only moves models
-- around to match.
--
-- The rules that keep a run winnable:
--   * a player carries one part at most, and a part has one carrier;
--   * a carrier who freezes, leaves or falls drops the part where they were;
--   * a part left loose for Balance.Radio.LooseReturnSeconds goes back to
--     its landmark (unfrozen), so it can't be lost out of reach;
--   * parts are only freed, picked up and fitted while a run is on;
--   * the count of fitted parts is worked out from the parts, never kept on
--     the side, so it can't drift, and fitting twice does nothing.

local Balance = require(script.Parent.Config.Balance)
local Features = require(script.Parent.Config.Features)
local Map = require(script.Parent.Config.Map)

export type PartState = "Frozen" | "Loose" | "Carried" | "Fitted"

export type Part = {
	Id: string,
	Landmark: Map.Landmark,
	State: PartState,
	Carrier: any?,
	-- When it was last left lying loose (server seconds).
	LooseSince: number,
	-- Turns of its landmark's trial done so far.
	Progress: number,
}

export type Radio = {
	Parts: { [string]: Part },
	-- Part ids in the order the landmarks are listed (the radio's sockets).
	Order: { string },
}

-- What a player brings to a trial: who they are, the tool in their hand,
-- and what is in their backpack.
export type Attempt = {
	Who: any,
	Tool: string?,
	Pack: { [string]: number },
}

-- What came of a turn at a trial. Take is what to remove from the
-- player's backpack when Freed or progressed.
export type Outcome = {
	Ok: boolean,
	Freed: boolean,
	Reason: string?,
	Take: { [string]: number }?,
	Progress: number,
	Needed: number,
}

local Radio = {}

local BREAK: Map.Trial = {
	Kind = "Saw",
	Times = 1,
	Seconds = Balance.Radio.BreakSeconds,
	Action = "Break the ice",
	Hint = "It's frozen in a block of ice. Monsters guard it, so go together!",
}

function Radio.new(): Radio
	local radio: Radio = { Parts = {}, Order = {} }
	for _, landmark in Map.Landmarks do
		radio.Parts[landmark.Part] = {
			Id = landmark.Part,
			Landmark = landmark,
			State = "Frozen",
			Carrier = nil,
			LooseSince = 0,
			Progress = 0,
		}
		table.insert(radio.Order, landmark.Part)
	end
	return radio
end

-- Freezes every part back at its landmark, for a new run. Returns whoever
-- was carrying one, so the server can tidy them up.
function Radio.reset(radio: Radio): { any }
	local carriers = {}
	for _, part in radio.Parts do
		if part.Carrier ~= nil then
			table.insert(carriers, part.Carrier)
		end
		part.State = "Frozen"
		part.Carrier = nil
		part.LooseSince = 0
		part.Progress = 0
	end
	return carriers
end

function Radio.count(radio: Radio, state: PartState): number
	local count = 0
	for _, part in radio.Parts do
		if part.State == state then
			count += 1
		end
	end
	return count
end

function Radio.fitted(radio: Radio): number
	return Radio.count(radio, "Fitted")
end

-- Whether every part is in, so the train is called.
function Radio.complete(radio: Radio): boolean
	return Radio.fitted(radio) == #radio.Order
end

function Radio.carriedBy(radio: Radio, who: any): Part?
	for _, part in radio.Parts do
		if part.State == "Carried" and part.Carrier == who then
			return part
		end
	end
	return nil
end

-- The trial that frees a part: its landmark's, or a plain break.
function Radio.trial(part: Part): Map.Trial
	if Features.LandmarkTrials then
		return part.Landmark.Trial
	end
	return BREAK
end

-- How many turns a trial takes.
function Radio.turns(trial: Map.Trial): number
	return if trial.Kind == "Saw" then trial.Times or 1 else 1
end

-- What the guide says about a landmark whose part is still frozen.
function Radio.hint(landmark: Map.Landmark): string
	if Features.LandmarkTrials then
		return landmark.Trial.Hint
	end
	return BREAK.Hint
end

-- One go at freeing a frozen part. Melt needs a tool in hand, Bring needs
-- the resource in the backpack (and takes it), Saw just counts turns.
function Radio.work(radio: Radio, id: string, attempt: Attempt, playing: boolean): Outcome
	local part = radio.Parts[id]
	local trial = if part then Radio.trial(part) else BREAK
	local needed = Radio.turns(trial)
	local function fail(reason: string): Outcome
		return {
			Ok = false,
			Freed = false,
			Reason = reason,
			Progress = if part then part.Progress else 0,
			Needed = needed,
		}
	end
	if not part or part.State ~= "Frozen" then
		return fail("It isn't frozen any more.")
	end
	if not playing then
		return fail("Wait for the run to start.")
	end
	local take: { [string]: number }? = nil
	if trial.Kind == "Melt" then
		if not attempt.Tool then
			return fail("Hold your torch (or any fire tool) out to melt the ice.")
		end
	elseif trial.Kind == "Bring" then
		local resource = trial.Resource :: string
		local amount = trial.Amount or 1
		local have = attempt.Pack[resource] or 0
		if have < amount then
			return fail(`Bring {amount} {string.lower(resource)} in your backpack (you have {have}).`)
		end
		take = { [resource] = amount }
	end
	part.Progress += 1
	if part.Progress >= needed then
		part.State = "Loose"
		part.LooseSince = math.huge
		return { Ok = true, Freed = true, Take = take, Progress = part.Progress, Needed = needed }
	end
	return { Ok = true, Freed = false, Take = take, Progress = part.Progress, Needed = needed }
end

function Radio.pickUp(radio: Radio, id: string, who: any, playing: boolean): (boolean, string?)
	local part = radio.Parts[id]
	if not part or part.State ~= "Loose" then
		return false, nil
	end
	if not playing then
		return false, nil
	end
	if Radio.carriedBy(radio, who) then
		return false, "You can only carry one radio part at a time."
	end
	part.State = "Carried"
	part.Carrier = who
	return true, nil
end

-- The carrier lets go (froze, left, fell). Returns the part, if they had
-- one.
function Radio.drop(radio: Radio, who: any, now: number): Part?
	local part = Radio.carriedBy(radio, who)
	if not part then
		return nil
	end
	part.State = "Loose"
	part.Carrier = nil
	part.LooseSince = now
	return part
end

-- The carrier reached the radio. Returns the part fitted (nil if they had
-- none, or the run is over) and whether that was the last one.
function Radio.fit(radio: Radio, who: any, playing: boolean): (Part?, boolean)
	if not playing then
		return nil, false
	end
	local part = Radio.carriedBy(radio, who)
	if not part then
		return nil, false
	end
	part.State = "Fitted"
	part.Carrier = nil
	return part, Radio.complete(radio)
end

-- Loose parts that have lain untouched for too long. The server moves each
-- back to its landmark and calls Radio.sendHome.
function Radio.stale(radio: Radio, now: number): { Part }
	local list = {}
	for _, id in radio.Order do
		local part = radio.Parts[id]
		if part.State == "Loose" and now - part.LooseSince >= Balance.Radio.LooseReturnSeconds then
			table.insert(list, part)
		end
	end
	return list
end

-- A loose part is back at its landmark: it lies there (not frozen again),
-- and won't be sent home again until someone drops it somewhere else.
function Radio.sendHome(part: Part)
	part.LooseSince = math.huge
end

-- How many parts a team should have fitted by this night, for catch-up.
function Radio.expected(night: number): number
	local from, every = Balance.Radio.CatchUpFrom, Balance.Radio.CatchUpEvery
	if night < from then
		return 0
	end
	return math.min(#Map.Landmarks, 1 + (night - from) // every)
end

-- Whether a team is behind on the radio and gets help finding the rest.
function Radio.behind(night: number, fitted: number): boolean
	return Features.RadioCatchUp and fitted < Radio.expected(night) and fitted < #Map.Landmarks
end

return Radio
