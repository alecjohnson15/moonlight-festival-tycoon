-- Reports how players get on to Roblox's analytics, so every change to the
-- first minutes can be measured in the Creator Dashboard:
--   - the onboarding funnel (server/Lib/Funnel): joined, spawned, reached a
--     gate, claimed a plot, built the stall, earned coins, bought an
--     upgrade, built an attraction, picked a path. Each step is logged once
--     per player, ever, in order; the save keeps the last one logged.
--   - custom events: GhostCatcherRound (wisps caught), PathPicked (the
--     building and path), ParadeJoined (lanterns caught) and ReturnSession
--     (how many sessions the player has had, from their second on).
-- Retention (D1, D7) the dashboard works out for itself. Nothing here
-- changes the game; a failed call is skipped.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Funnel = require(script.Parent.Parent.Lib.Funnel)
local ActivityService = require(script.Parent.ActivityService)
local DataService = require(script.Parent.DataService)
local ParadeService = require(script.Parent.ParadeService)

-- Close enough to a free gate to count as having found one.
local GATE_REACH = 40
local CHECK_SECONDS = 1

type Tracked = { Spawned: boolean, NearGate: boolean, Paths: { [string]: string } }

local Analytics = {}

local tracked: { [Player]: Tracked } = {}

local function field(index: number): string
	return (Enum.AnalyticsCustomFieldKeys :: any)[string.format("CustomField%02d", index)].Name
end

local function logEvent(player: Player, name: string, value: number?, fields: { string }?)
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

local function nearFreeGate(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local plots = Workspace:FindFirstChild("Plots")
	if not root or not root:IsA("BasePart") or not plots then
		return false
	end
	for _, plot in plots:GetChildren() do
		local gate = plot:FindFirstChild("Gate")
		if plot:GetAttribute("OwnerUserId") == nil and gate and gate:IsA("BasePart") then
			if (gate.Position - root.Position).Magnitude <= GATE_REACH then
				return true
			end
		end
	end
	return false
end

local function check(player: Player)
	local data = DataService.get(player)
	local state = tracked[player]
	if not data or not state then
		return
	end
	state.NearGate = state.NearGate or nearFreeGate(player)
	local steps = Funnel.toLog(data.Onboarding, {
		Spawned = state.Spawned,
		NearGate = state.NearGate,
		HasPlot = player:GetAttribute("HasPlot") == true,
		Owned = data.Owned,
		LifetimeCoins = data.LifetimeCoins,
	}, Balance.Upgrades)
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

	local chosen = Progression.chosenPaths(data.Owned, Balance.Upgrades)
	for _, picked in Funnel.newPaths(state.Paths, chosen) do
		logEvent(player, "PathPicked", 1, { picked.Building, picked.Path })
	end
	state.Paths = chosen
end

local function onLoaded(player: Player, data)
	tracked[player] = {
		Spawned = player.Character ~= nil,
		NearGate = false,
		-- Paths picked in an earlier session were logged then.
		Paths = Progression.chosenPaths(data.Owned, Balance.Upgrades),
	}
	data.Sessions += 1
	if data.Sessions >= 2 then
		logEvent(player, "ReturnSession", data.Sessions)
	end
	player.CharacterAdded:Connect(function()
		local state = tracked[player]
		if state then
			state.Spawned = true
		end
	end)
	check(player)
end

function Analytics.init()
	DataService.onLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		tracked[player] = nil
	end)
	ActivityService.onRoundEnded(function(player, caught)
		logEvent(player, "GhostCatcherRound", caught)
	end)
	ParadeService.onJoined(function(player, result)
		logEvent(player, "ParadeJoined", result.Caught, { if result.Filled then "Filled" else "Not filled" })
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
