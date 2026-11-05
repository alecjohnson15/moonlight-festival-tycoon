-- Reports what players do to Roblox's analytics (Creator Dashboard >
-- Analytics), so the first play-tests and the launch can show where people
-- stop, without guessing: the onboarding funnel for brand new players, a
-- funnel through every run, and a custom event for how each run ends
-- (RunWon or RunLost, with the night reached). The steps are listed in
-- shared/Funnel.
--
-- Nothing personal is sent: Roblox ties events to the player itself, and
-- the only extra field is the player's role. Every call is wrapped, so an
-- analytics hiccup (or Studio, where it is off) never breaks the game.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Funnel = require(ReplicatedStorage.Shared.Funnel)

local Analytics = {}

type Entry = { Onboarding: Funnel.Record?, Run: Funnel.Record, RunId: string }

local entries: { [Player]: Entry } = {}
local runId = "none"

local function fields(player: Player): { [any]: string }
	local role = player:GetAttribute("Role")
	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = if type(role) == "string" and role ~= ""
			then role
			else "None",
	}
end

local function call(callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn(`Analytics: {err}`)
	end
end

local function entry(player: Player): Entry
	local found = entries[player]
	if not found then
		found = { Onboarding = nil, Run = Funnel.new(Funnel.Run), RunId = runId }
		entries[player] = found
	end
	if found.RunId ~= runId then
		found.Run = Funnel.new(Funnel.Run)
		found.RunId = runId
	end
	return found
end

-- A player's save has loaded. New players (no runs yet) get the onboarding
-- funnel.
function Analytics.joined(player: Player, isNew: boolean)
	local found = entry(player)
	if isNew and not found.Onboarding then
		found.Onboarding = Funnel.new(Funnel.Onboarding)
	end
	Analytics.step(player, "Joined")
end

-- A new run started: everyone's run funnel starts over.
function Analytics.newRun(id: string)
	runId = id
end

-- A player reached a step. Steps not in a funnel are ignored by it.
function Analytics.step(player: Player, step: string)
	local found = entry(player)
	if found.Onboarding then
		local index = Funnel.mark(found.Onboarding, step)
		if index then
			call(function()
				AnalyticsService:LogOnboardingFunnelStepEvent(player, index, step, fields(player))
			end)
		end
	end
	local index = Funnel.mark(found.Run, step)
	if index then
		call(function()
			AnalyticsService:LogFunnelStepEvent(player, "Run", runId, index, step, fields(player))
		end)
	end
end

-- A one-off event with a number, such as "RunWon" with the night reached.
function Analytics.event(player: Player, name: string, value: number?)
	call(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields(player))
	end)
end

function Analytics.forget(player: Player)
	entries[player] = nil
end

return Analytics
