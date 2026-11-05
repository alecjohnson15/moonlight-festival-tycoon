--!strict
-- When a round is over and who won. Each player in the round has a role and
-- a state: Alive, Dazed (tagged, and a Medic can still revive them) or Out.
-- The Phantom is never dazed: a Phantom who is knocked out is out.

local Game = require(script.Parent.Parent.Config.Game)
local Roles = require(script.Parent.Parent.Config.Roles)

export type Entry = { Role: string, State: string }

local Round = {}

-- The winning team ("Guests" or "Shadows") and why, or nil while the round
-- goes on. In practice (a lone tester in Studio) only the clock ends it.
function Round.outcome(entries: { [any]: Entry }, timeLeft: number, practice: boolean?): (string?, string?)
	if practice then
		if timeLeft <= 0 then
			return "Guests", "Time"
		end
		return nil, nil
	end
	local phantomIn = false
	local guestsUp = 0
	for _, entry in entries do
		if entry.Role == "Phantom" then
			if entry.State ~= "Out" then
				phantomIn = true
			end
		elseif Roles.team(entry.Role) == "Guests" and entry.State == "Alive" then
			guestsUp += 1
		end
	end
	if not phantomIn then
		return "Guests", "PhantomOut"
	elseif guestsUp == 0 then
		return "Shadows", "AllTagged"
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

-- How many players of each state, for the HUD.
function Round.census(entries: { [any]: Entry }): { Alive: number, Dazed: number, Out: number }
	local census = { Alive = 0, Dazed = 0, Out = 0 }
	for _, entry in entries do
		census[entry.State] = (census[entry.State] or 0) + 1
	end
	return census
end

return Round
