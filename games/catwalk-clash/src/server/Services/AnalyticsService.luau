-- Reports how players get on to Roblox's analytics, so every change can be
-- measured in the Creator Dashboard:
--   - the onboarding funnel (server/Lib/Funnel): joined, spawned, changed
--     outfit, walked, voted, finished a show, won a matchup, saved an
--     outfit, came back. Each step is logged once per player, ever.
--   - custom events: ShowFinished (placing), ThemePlayed (which theme won
--     the vote), ReturnSession (sessions so far, from the second on),
--     ReadyPressed (seconds of dressing left), MatchWalked (1 for a win,
--     with the round), OutfitSaved (outfits in the closet), CatalogSearch
--     (results on the first page, with the category), CatalogBuyPrompt and
--     JoinedMidShow. None carries names or anything a player typed.
-- Nothing here changes the game; a failed call is skipped.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Funnel = require(script.Parent.Parent.Lib.Funnel)
local PlayerHooks = require(script.Parent.Parent.Lib.PlayerHooks)
local DataService = require(script.Parent.DataService)

local CHECK_SECONDS = 2

local Analytics = {}

local spawned: { [Player]: boolean } = {}
local tracked: { [Player]: boolean } = {}

local function field(index: number): string
	return (Enum.AnalyticsCustomFieldKeys :: any)[string.format("CustomField%02d", index)].Name
end

-- Logs a custom event; fields fill the custom fields in order.
function Analytics.event(player: Player, name: string, value: number?, fields: { string }?)
	local custom = nil
	if fields then
		custom = {}
		for index, text in fields do
			custom[field(index)] = text
		end
	end
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, custom)
	end)
	if not ok then
		warn(`Couldn't log {name}: {err}`)
	end
end

local function check(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local steps = Funnel.toLog(data.Onboarding, {
		Spawned = spawned[player] == true,
		Dressed = player:GetAttribute("Dressed") == true,
		Walks = data.Stats.Walks,
		Votes = data.Stats.Votes,
		Shows = data.Stats.Shows,
		Wins = data.Stats.Wins,
		SavedLooks = #data.Looks,
		Sessions = data.Sessions,
	})
	for _, step in steps do
		local ok, err = pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, Funnel.Steps[step].Name)
		end)
		if not ok then
			warn(`Couldn't log onboarding step {step}: {err}`)
			return
		end
		data.Onboarding = step
	end
end

function Analytics.init()
	DataService.onLoaded(function(player, data)
		tracked[player] = true
		if data.Sessions >= 2 then
			Analytics.event(player, "ReturnSession", data.Sessions)
		end
	end)
	PlayerHooks.eachCharacter(function(player)
		spawned[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		spawned[player] = nil
		tracked[player] = nil
	end)
end

function Analytics.start()
	while true do
		for player in tracked do
			check(player)
		end
		task.wait(CHECK_SECONDS)
	end
end

return Analytics
