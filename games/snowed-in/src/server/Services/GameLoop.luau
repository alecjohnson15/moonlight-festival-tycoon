-- Runs the run: waits for players, counts down the intermission, then steps
-- through days and nights (shared/Cycle) until the train comes or the
-- hearth goes out, shows the results, resets the town and starts again.
--
-- The phase, the night and when the phase ends (server time) are attributes
-- on ReplicatedStorage.State, so every client's clock, sky and HUD follow
-- the server without being sent anything. Other services hook phase changes
-- with GameLoop.onPhase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cycle = require(ReplicatedStorage.Shared.Cycle)

local State = ReplicatedStorage.State :: Configuration

local GameLoop = {}

local state: Cycle.State = { Phase = "Waiting", Night = 0, Called = false }
local phaseEnds = math.huge
local callbacks: { (phase: string, night: number, previous: string) -> () } = {}
-- Set by end(): the phase to jump to at the next tick.
local forced: string? = nil
-- Players who were in the run when it ended get the rewards; this counts
-- nights each player was there for.
local nightsPresent: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish()
	State:SetAttribute("Phase", state.Phase)
	State:SetAttribute("Night", state.Night)
	State:SetAttribute("Called", state.Called)
	State:SetAttribute("PhaseEnds", if phaseEnds == math.huge then 0 else phaseEnds)
end

local function enter(next: Cycle.State)
	local previous = state.Phase
	state = next
	local length = Cycle.length(state.Phase, state.Night)
	phaseEnds = if length == math.huge then math.huge else now() + length
	publish()
	if state.Phase == "Dawn" then
		for _, player in Players:GetPlayers() do
			nightsPresent[player] = (nightsPresent[player] or 0) + 1
		end
	elseif state.Phase == "Day" and state.Night == 0 then
		table.clear(nightsPresent)
	end
	for _, callback in callbacks do
		task.spawn(callback, state.Phase, state.Night, previous)
	end
end

-- Runs callback(phase, night, previousPhase) at the start of every phase.
function GameLoop.onPhase(callback: (phase: string, night: number, previous: string) -> ())
	table.insert(callbacks, callback)
end

function GameLoop.phase(): string
	return state.Phase
end

function GameLoop.night(): number
	return state.Night
end

function GameLoop.isPlaying(): boolean
	return Cycle.isPlaying(state.Phase :: any)
end

function GameLoop.isNight(): boolean
	return state.Phase == "Night"
end

-- Seconds since the current phase started.
function GameLoop.elapsed(): number
	local length = Cycle.length(state.Phase, state.Night)
	if phaseEnds == math.huge then
		return 0
	end
	return length - (phaseEnds - now())
end

-- The radio has called the train: it comes at the dawn after the last
-- night (or the next dawn, if that has passed).
function GameLoop.callTrain()
	state.Called = true
	publish()
end

-- Ends the run now, with "Lost" (the hearth went out).
function GameLoop.lose()
	if Cycle.isPlaying(state.Phase :: any) then
		forced = "Lost"
	end
end

-- How many nights a player was there for this run.
function GameLoop.nightsFor(player: Player): number
	return nightsPresent[player] or 0
end

function GameLoop.init()
	publish()
	Players.PlayerRemoving:Connect(function(player)
		nightsPresent[player] = nil
	end)
end

function GameLoop.start()
	while true do
		task.wait(0.25)
		local count = #Players:GetPlayers()
		if count == 0 and state.Phase ~= "Waiting" then
			-- Everyone left: tidy up and wait for the next player.
			forced = nil
			enter({ Phase = "Waiting", Night = 0, Called = false })
		elseif state.Phase == "Waiting" and count > 0 then
			enter({ Phase = "Intermission", Night = 0, Called = false })
		elseif forced then
			local phase = forced
			forced = nil
			enter({ Phase = phase :: any, Night = state.Night, Called = state.Called })
		elseif now() >= phaseEnds then
			enter(Cycle.next(state))
		end
	end
end

return GameLoop
