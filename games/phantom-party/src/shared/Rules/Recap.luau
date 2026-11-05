--!strict
-- The results card's story of the round, worked out on the server from what
-- happened (RoundService keeps the moments) and sent to everyone:
--   - the decisive moment, one line: who caught the Phantom and with how
--     long to spare, who tagged the last guest, or how many saw dawn;
--   - the party star: the guest-side player who helped most without
--     catching anyone (revives, clue pages, staying up, picking up the
--     blaster), so a round has a hero even when nobody lands the catch.
-- Pure (tests/Recap.spec). Roles are already public on the results card,
-- so naming them here gives nothing away.

local Format = require(script.Parent.Parent.Format)
local Rewards = require(script.Parent.Parent.Config.Rewards)
local Roles = require(script.Parent.Parent.Config.Roles)

export type Entry = {
	UserId: number,
	Name: string,
	Role: string,
	State: string,
	Hero: boolean,
	Takedown: boolean,
	Tags: number,
	Revives: number,
	Clues: number,
}

export type Moments = {
	-- The last guest knocked down: by whom (nil for a misfire's kickback),
	-- who, and how (Swing, Throw, Zap or Misfire).
	LastDown: { By: string?, Target: string, How: string }?,
	-- Who caught the Phantom, and how (Zap, or the Hero's blaster).
	Catch: { By: string, Hero: boolean }?,
}

export type Star = { Name: string, Role: string, Score: number, Why: string }

local Recap = {}

-- How much each kind of help counts toward the party star.
Recap.STAR = { Revive = 3, Clue = 1, Survived = 4, Hero = 2 }

local function phantomName(entries: { Entry }): string
	for _, entry in entries do
		if entry.Role == "Phantom" then
			return entry.Name
		end
	end
	return "the Phantom"
end

local function standing(entries: { Entry }): number
	local count = 0
	for _, entry in entries do
		if Roles.team(entry.Role) == "Guests" and entry.State == "Alive" then
			count += 1
		end
	end
	return count
end

-- One line on what decided the round.
function Recap.decisive(reason: string, timeLeft: number, entries: { Entry }, moments: Moments): string
	local phantom = phantomName(entries)
	if reason == "PhantomOut" then
		local spare = Format.clock(math.max(0, timeLeft))
		local catcher = moments.Catch
		if not catcher then
			for _, entry in entries do
				if entry.Takedown then
					catcher = { By = entry.Name, Hero = entry.Hero }
				end
			end
		end
		if catcher then
			local how = if catcher.Hero then " with a borrowed blaster" else ""
			return `{catcher.By} unmasked {phantom}{how}, with {spare} to spare!`
		end
		return `{phantom} was knocked out with {spare} to spare!`
	elseif reason == "PhantomLeft" then
		return `{phantom} slipped out of the party, so the guests win.`
	elseif reason == "AllTagged" then
		local last = moments.LastDown
		if last and (last.How == "Zap" or last.How == "Misfire") then
			return "A misfired zap knocked out the last guests standing."
		elseif last and last.By then
			return `{last.By} tagged {last.Target}, the last guest standing.`
		end
		return `{phantom} tagged every guest.`
	elseif reason == "GuestsLeft" then
		return "Every guest left the party."
	elseif reason == "Time" then
		local count = standing(entries)
		if count == 1 then
			return "Dawn broke with one guest still standing!"
		end
		return `Dawn broke with {count} guests still standing!`
	end
	return ""
end

-- How much a guest-side player helped, not counting the catch itself.
function Recap.score(entry: Entry): number
	local star = Recap.STAR
	return entry.Revives * star.Revive
		+ math.min(entry.Clues, Rewards.ClueCap) * star.Clue
		+ (if entry.State == "Alive" then star.Survived else 0)
		+ (if entry.Hero then star.Hero else 0)
end

local function why(entry: Entry): string
	local parts = {}
	if entry.Revives > 0 then
		table.insert(parts, if entry.Revives == 1 then "1 revive" else `{entry.Revives} revives`)
	end
	if entry.Clues > 0 then
		table.insert(parts, if entry.Clues == 1 then "1 clue page" else `{entry.Clues} clue pages`)
	end
	if entry.Hero then
		table.insert(parts, "picked up the blaster")
	end
	if entry.State == "Alive" then
		table.insert(parts, "made it through")
	end
	return table.concat(parts, ", ")
end

-- The party star, or nil if no guest-side player did anything beyond
-- staying up (practice stand-ins, with negative ids, never count).
function Recap.star(entries: { Entry }): Star?
	local best: Entry? = nil
	local bestScore = 0
	for _, entry in entries do
		if entry.UserId <= 0 or Roles.team(entry.Role) ~= "Guests" then
			continue
		end
		if entry.Revives <= 0 and entry.Clues <= 0 and not entry.Hero then
			continue
		end
		local score = Recap.score(entry)
		local better = best == nil
			or score > bestScore
			or (score == bestScore and entry.Revives > (best :: Entry).Revives)
			or (score == bestScore and entry.Revives == (best :: Entry).Revives and entry.Name < (best :: Entry).Name)
		if better then
			best = entry
			bestScore = score
		end
	end
	if not best then
		return nil
	end
	return { Name = best.Name, Role = best.Role, Score = bestScore, Why = why(best) }
end

return Recap
