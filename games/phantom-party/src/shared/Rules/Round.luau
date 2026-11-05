--!strict
-- When a round is over and who won: the single source of truth for every
-- way a round can end. RoundService asks Round.outcome four times a second
-- and nothing else decides a winner.
--
-- Each player in the round has a role and a state: Alive, Dazed (tagged, and
-- a Medic can still revive them) or Out. Left marks someone who left the
-- server mid-round (they are Out too).
--
-- The rules, in the order they are checked (the first that holds wins):
--
--   1. PhantomLeft  The Phantom left the server.          Guests win.
--   2. PhantomOut   The Phantom was zapped (Out).         Guests win.
--   3. GuestsLeft   Every guest left the server.          Shadows win.
--   4. AllTagged    No guest is still standing (Alive).   Shadows win.
--   5. Time         The clock ran out.                    Guests win.
--
-- So a zap on the Phantom beats a tag on the last guest in the same instant,
-- and a guest lying Dazed doesn't keep the round going: with nobody standing
-- there is no Medic left to revive them.
--
-- The other rules that settle arguments:
--   - The Phantom is never Dazed and never revived: a zapped Phantom is Out.
--   - The Saboteur is on the Phantom's team. The Phantom can't tag them, and
--     they can't tag anyone. A zap knocks them Out at once with no penalty
--     for the shooter. Whether they are standing doesn't matter to the
--     result: only the Phantom and the guests do.
--   - A Guardian who is knocked down drops the blaster. Any guest still
--     standing (never a Shadow) can pick it up and becomes the Hero: still a
--     guest, with the Guardian's blaster rules, misfire penalty included.
--   - A revived guest is Alive again, on the guests' team as before, with a
--     few seconds' shield (Game.Seconds.ReviveShield).

local Game = require(script.Parent.Parent.Config.Game)
local Roles = require(script.Parent.Parent.Config.Roles)

export type Entry = { Role: string, State: string, Left: boolean? }

local Round = {}

-- Every reason a round can end, and the team it hands the win to.
Round.REASONS = {
	PhantomLeft = "Guests",
	PhantomOut = "Guests",
	GuestsLeft = "Shadows",
	AllTagged = "Shadows",
	Time = "Guests",
}

-- The winning team ("Guests" or "Shadows") and why, or nil while the round
-- goes on. noPhantom is for a round dealt without a Phantom, which only the
-- clock can end (it never happens in play; kept so a broken deal can't hang
-- a server).
function Round.outcome(entries: { [any]: Entry }, timeLeft: number, noPhantom: boolean?): (string?, string?)
	if noPhantom then
		if timeLeft <= 0 then
			return "Guests", "Time"
		end
		return nil, nil
	end
	local phantomIn, phantomLeft = false, false
	local guests, guestsUp, guestsGone = 0, 0, 0
	for _, entry in entries do
		if entry.Role == "Phantom" then
			if entry.State ~= "Out" then
				phantomIn = true
			elseif entry.Left then
				phantomLeft = true
			end
		elseif Roles.team(entry.Role) == "Guests" then
			guests += 1
			if entry.State == "Alive" then
				guestsUp += 1
			elseif entry.Left then
				guestsGone += 1
			end
		end
	end
	if not phantomIn then
		return "Guests", if phantomLeft then "PhantomLeft" else "PhantomOut"
	elseif guestsUp == 0 then
		return "Shadows", if guests > 0 and guestsGone == guests then "GuestsLeft" else "AllTagged"
	elseif timeLeft <= 0 then
		return "Guests", "Time"
	end
	return nil, nil
end

-- How long a round with count players lasts.
function Round.length(count: number): number
	local extra = math.max(0, count - 8) * Game.Seconds.RoundPerExtraPlayer
	return Game.Seconds.Round + extra
end

-- Which ruleset a round with count real players uses, for the role card and
-- the Truth Bell's pacing:
--   Practice  one player, against stand-ins (pays nothing);
--   Duel      two players: the Phantom and the Guardian know who the other
--             is, so it's hide and seek, not a whodunit, and it says so;
--   Small     three or four: a short list of suspects;
--   Full      five or more: the whole social deduction game.
function Round.ruleset(count: number): string
	if count < Game.MinPlayers then
		return "Practice"
	elseif count == 2 then
		return "Duel"
	elseif count <= 4 then
		return "Small"
	end
	return "Full"
end

-- Whether a player of this role can tag one of that role.
function Round.canTag(attacker: string, target: string): boolean
	return attacker == "Phantom" and Roles.team(target) == "Guests"
end

-- What a blaster zap does: who it knocks out. A Shadow zapped is knocked
-- out; an innocent guest zapped is knocked out along with the shooter.
function Round.zap(target: string): { Target: boolean, Shooter: boolean }
	if Roles.team(target) == "Shadows" then
		return { Target = true, Shooter = false }
	end
	return { Target = true, Shooter = true }
end

-- Whether a player of this role may pick up a dropped blaster.
function Round.canPickUp(role: string, state: string): boolean
	return state == "Alive" and Roles.team(role) == "Guests"
end

-- Whether a Medic may revive a player of this role in this state. The
-- Phantom never lies dazed, so is never revived.
function Round.canRevive(role: string, state: string): boolean
	return state == "Dazed" and Roles.team(role) == "Guests"
end

-- How many players of each state, for the HUD.
function Round.census(entries: { [any]: Entry }): { Alive: number, Dazed: number, Out: number }
	local census = { Alive = 0, Dazed = 0, Out = 0 }
	for _, entry in entries do
		census[entry.State] = (census[entry.State] or 0) + 1
	end
	return census
end

return Round
