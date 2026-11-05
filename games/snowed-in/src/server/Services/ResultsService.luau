-- Says what is happening as the run goes (the big banner at nightfall, the
-- cheer at dawn, tonight's threat), marks the run's milestones, and at the
-- end of a run works out each player's results, pays their snowflakes and
-- pass XP through ProfileService (once per run), and shows the results
-- screen with what they did and what to play for next.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Lib = script.Parent.Parent.Lib
local Analytics = require(Lib.Analytics)
local Celebrate = require(Lib.Celebrate)
local Net = require(Lib.Net)
local RunStats = require(Lib.RunStats)
local GameLoop = require(script.Parent.GameLoop)
local ProfileService = require(script.Parent.ProfileService)

local State = ReplicatedStorage.State :: Configuration

local ResultsService = {}

local function tonight(): string
	local name = State:GetAttribute("TonightName")
	local tip = State:GetAttribute("TonightTip")
	if type(name) == "string" and name ~= "" then
		return ` Tonight: {name}. {tip or ""}`
	end
	return ""
end

local function announce(phase: string, night: number)
	if phase == "Intermission" then
		Net.notice(nil, "A new run starts soon. Pick your role!", "Big")
	elseif phase == "Day" then
		if night == 0 then
			Net.notice(nil, "Day 1. Chop wood, feed the hearth and find the radio parts!", "Big")
		elseif night >= Balance.Nights and State:GetAttribute("Called") ~= true then
			Net.notice(nil, `Day {night + 1}. The train can't find you! Fix the radio!`, "Big")
		else
			Net.notice(nil, `Day {night + 1}. Gather, build and find the radio parts!`, "Big")
		end
	elseif phase == "Dusk" then
		Net.notice(nil, `Night is coming! Get back to the hearth.{tonight()}`, "Big")
	elseif phase == "Night" then
		Net.notice(nil, `Night {night} of {Balance.Nights}. Keep the fire burning!`, "Big")
	elseif phase == "Dawn" then
		Net.notice(nil, `You survived night {night}!`, "Big")
	elseif phase == "Rescue" then
		Net.notice(nil, "The rescue train is here! All aboard!", "Big")
	end
end

-- The player who did the most of something this run, by a count function.
local function best(count: (Player) -> number): (string?, number)
	local name, top = nil, 0
	for _, player in Players:GetPlayers() do
		local value = count(player)
		if value > top then
			name, top = player.DisplayName, value
		end
	end
	return name, top
end

local function finish(won: boolean, night: number)
	local team = RunStats.team()
	local runId = RunStats.runId()
	local topKnockouts, knockouts = best(RunStats.knockoutsFor)
	local topThaws, thaws = best(RunStats.thawsFor)
	for _, player in Players:GetPlayers() do
		local present = GameLoop.nightsFor(player)
		local wonCredit, partsCredit = Profile.credit(present, won, team.Parts)
		local stats = {
			Nights = present,
			Parts = partsCredit,
			Won = wonCredit,
			Knockouts = RunStats.knockoutsFor(player),
		}
		local flakes, given, nextGoal =
			ProfileService.finishRun(player, stats, RunStats.sawYeti(player) and present >= 1, runId)
		Analytics.step(player, "FinishedRun")
		if won then
			Analytics.step(player, "Rescued")
		end
		Analytics.event(player, if won then "RunWon" else "RunLost", night)
		Net.remote("Results"):FireClient(player, {
			Won = won,
			Night = night,
			Nights = stats.Nights,
			Parts = team.Parts,
			Knockouts = stats.Knockouts,
			Flakes = flakes,
			Xp = flakes * Balance.Rewards.XpPerFlake,
			Given = given,
			Gathered = team.Gathered,
			Built = team.Built,
			BeatYeti = team.BeatYeti,
			TopKnockouts = topKnockouts,
			TopKnockoutsCount = knockouts,
			TopThaws = topThaws,
			TopThawsCount = thaws,
			Mine = RunStats.contribution(player),
			Milestones = table.clone(team.Milestones),
			Late = won and not wonCredit,
			NextGoal = nextGoal,
		})
	end
end

local function everyone(step: string)
	for _, player in Players:GetPlayers() do
		Analytics.step(player, step)
	end
end

function ResultsService.init()
	GameLoop.onPhase(function(phase, night)
		announce(phase, night)
		if phase == "Day" and night == 0 then
			RunStats.reset()
			Analytics.newRun(RunStats.runId())
			everyone("Started")
		elseif phase == "Dawn" then
			if night == 1 then
				Celebrate.milestone("Night1")
				everyone("SurvivedNight1")
			elseif night == 5 then
				everyone("Night5")
			end
		elseif phase == "Rescue" then
			Celebrate.milestone("Rescue")
		elseif phase == "Won" then
			finish(true, night)
		elseif phase == "Lost" then
			finish(false, night)
		end
	end)
	-- Late joiners join the run's funnel from where it is.
	Players.PlayerAdded:Connect(function(player)
		if GameLoop.isPlaying() then
			Analytics.step(player, "Started")
		end
	end)
	State:GetAttributeChangedSignal("Called"):Connect(function()
		if State:GetAttribute("Called") == true then
			Celebrate.milestone("Radio")
			everyone("RadioFixed")
		end
	end)
end

return ResultsService
