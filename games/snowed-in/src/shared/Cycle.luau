--!strict
-- The run's clock: which phase follows which, how long each lasts, and what
-- time of day the sky shows. The server's RunService steps through these
-- and the clients read the phase and its end time from attributes.
--
--   Intermission -> Day -> Dusk -> Night -> Dawn -> Day -> ... -> Night N
--   -> Dawn -> Rescue (the train arrives) -> Won -> Intermission
--
-- The run is Lost the moment the hearth goes out, or at the dawn after
-- Balance.LastNight if the radio never called the train.

local Balance = require(script.Parent.Config.Balance)

export type Phase = "Waiting" | "Intermission" | "Day" | "Dusk" | "Night" | "Dawn" | "Rescue" | "Won" | "Lost"

export type State = {
	Phase: Phase,
	-- The night the run is on: 0 during the first day, 1 from the first
	-- dusk, and so on. The HUD shows "Night N of 10".
	Night: number,
	-- Whether the radio is fixed, so the train is coming.
	Called: boolean,
}

local Cycle = {}

Cycle.RESCUE_SECONDS = 14

-- Seconds the phase lasts. Waiting has no end.
function Cycle.length(phase: Phase, night: number): number
	local phases = Balance.Phases
	if phase == "Intermission" then
		return phases.Intermission
	elseif phase == "Day" then
		return if night == 0 then phases.FirstDay else phases.Day
	elseif phase == "Dusk" then
		return phases.Dusk
	elseif phase == "Night" then
		return phases.Night
	elseif phase == "Dawn" then
		return phases.Dawn
	elseif phase == "Rescue" then
		return Cycle.RESCUE_SECONDS
	elseif phase == "Won" or phase == "Lost" then
		return phases.Results
	end
	return math.huge
end

-- The phase after this one ends on its own (the hearth going out is
-- handled by the server, which jumps straight to Lost).
function Cycle.next(state: State): State
	local phase, night = state.Phase, state.Night
	if phase == "Waiting" or phase == "Intermission" then
		return { Phase = "Day", Night = 0, Called = false }
	elseif phase == "Day" then
		return { Phase = "Dusk", Night = night, Called = state.Called }
	elseif phase == "Dusk" then
		return { Phase = "Night", Night = night + 1, Called = state.Called }
	elseif phase == "Night" then
		return { Phase = "Dawn", Night = night, Called = state.Called }
	elseif phase == "Dawn" then
		if night >= Balance.Nights and state.Called then
			return { Phase = "Rescue", Night = night, Called = true }
		elseif night >= Balance.LastNight then
			return { Phase = "Lost", Night = night, Called = state.Called }
		end
		return { Phase = "Day", Night = night, Called = state.Called }
	elseif phase == "Rescue" then
		return { Phase = "Won", Night = night, Called = true }
	end
	-- Won or Lost: back to the start.
	return { Phase = "Intermission", Night = 0, Called = false }
end

-- Whether the monsters are out.
function Cycle.isDark(phase: Phase): boolean
	return phase == "Night"
end

-- Whether players are in a run (so gathering, building and so on work).
function Cycle.isPlaying(phase: Phase): boolean
	return phase == "Day" or phase == "Dusk" or phase == "Night" or phase == "Dawn"
end

-- The time of day for the sky (Lighting.ClockTime, 0 to 24), given the
-- phase and how far through it is (0 to 1). Days run from 7 to 17, dusk to
-- 19:30, nights through midnight to 5, and dawn back to 7.
function Cycle.clock(phase: Phase, progress: number): number
	local t = math.clamp(progress, 0, 1)
	if phase == "Day" then
		return 7 + 10 * t
	elseif phase == "Dusk" then
		return 17 + 2.5 * t
	elseif phase == "Night" then
		return (19.5 + 9.5 * t) % 24
	elseif phase == "Dawn" then
		return 5 + 2 * t
	elseif phase == "Rescue" or phase == "Won" then
		return 8
	elseif phase == "Lost" then
		return 21
	end
	return 9
end

return Cycle
