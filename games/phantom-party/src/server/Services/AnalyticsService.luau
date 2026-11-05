-- Reports how players get on to Roblox's analytics, so changes can be
-- measured in the Creator Dashboard:
--   - the first-time funnel: joined, had a role revealed, finished a
--     round, finished a second round, equipped or bought something. Each
--     step is logged once per player, ever, in order.
--   - custom events, only those listed in Config/Telemetry, each cleaned
--     by Rules/Telemetry (listed values only, no names or ids, capped
--     numbers) and limited per player per minute: RoundPlayed, FirstAction,
--     ClueFound, FirstElimination, GuardianAction, LeadSeen, Replay,
--     CosmeticEquip, CrateOpened, TradeInitiated and TradeCompleted.
-- The round events come from Match's events, so the services that run the
-- round don't need to know about analytics. Nothing here changes the game;
-- a failed call is skipped.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Telemetry = require(ReplicatedStorage.Shared.Rules.Telemetry)
local Match = require(script.Parent.Parent.Lib.Match)
local DataService = require(script.Parent.DataService)

local STEPS = { "Joined", "RoleRevealed", "FinishedRound", "SecondRound", "Equipped" }

local Analytics = {}

local limiters: { [Player]: Telemetry.Limiter } = {}
-- Rounds started this visit, for Replay.
local visitRounds: { [Player]: number } = {}
-- Per round: who has done something yet, and whether anyone's been knocked down.
local acted: { [any]: boolean } = {}
local firstDown = false

local function field(index: number): string
	return (Enum.AnalyticsCustomFieldKeys :: any)[string.format("CustomField%02d", index)].Name
end

-- Sends one custom event if Config/Telemetry lists it and the player's
-- limit allows; the fields are cleaned to listed values first.
function Analytics.track(player: Player?, name: string, value: number?, fields: { any }?)
	if not player or not player.Parent then
		return
	end
	local ok, number, clean = Telemetry.clean(name, value, fields)
	if not ok then
		return
	end
	local limiter = limiters[player]
	if not limiter then
		limiter = Telemetry.limiter()
		limiters[player] = limiter
	end
	if not Telemetry.allow(limiter, os.clock()) then
		return
	end
	local custom = nil
	if #clean > 0 then
		custom = {}
		for index, text in clean do
			custom[field(index)] = text
		end
	end
	local sent, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, number, custom)
	end)
	if not sent then
		warn(`Couldn't log {name}: {err}`)
	end
end

-- Logs a funnel step if it's the next one this player hasn't reached.
function Analytics.step(player: Player, name: string)
	local data = DataService.get(player)
	local index = table.find(STEPS, name)
	if not data or not index or data.Onboarding ~= index - 1 then
		return
	end
	data.Onboarding = index
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name)
	end)
end

function Analytics.roleDealt(players: { Player })
	acted = {}
	firstDown = false
	for _, player in players do
		Analytics.step(player, "RoleRevealed")
		visitRounds[player] = (visitRounds[player] or 0) + 1
		if visitRounds[player] >= 2 then
			Analytics.track(player, "Replay", visitRounds[player], { Match.Ruleset })
		end
	end
end

function Analytics.roundPlayed(player: Player, role: string, won: boolean, practice: boolean)
	if practice then
		return
	end
	local data = DataService.get(player)
	if data and data.Stats.Rounds >= 2 then
		Analytics.step(player, "FinishedRound")
		Analytics.step(player, "SecondRound")
	else
		Analytics.step(player, "FinishedRound")
	end
	Analytics.track(player, "RoundPlayed", 1, { role, if won then "Won" else "Lost" })
end

function Analytics.crateOpened(player: Player, crateId: string, rarity: string)
	Analytics.track(player, "CrateOpened", 1, { crateId, rarity })
end

function Analytics.equipped(player: Player, kind: string)
	Analytics.track(player, "CosmeticEquip", 1, { kind })
end

function Analytics.tradeOpened(a: Player, b: Player)
	Analytics.track(a, "TradeInitiated", 1)
	Analytics.track(b, "TradeInitiated", 1)
end

function Analytics.traded(player: Player, gave: number, got: number)
	Analytics.track(player, "TradeCompleted", gave + got, { gave, got })
end

local function secondsIn(): number
	return math.max(0, math.floor(os.clock() - Match.PlayingSince))
end

-- The first thing each participant does in a round.
local function action(participant: any, name: string)
	if Match.State ~= "Playing" or not participant or acted[participant.Key] then
		return
	end
	acted[participant.Key] = true
	Analytics.track(participant.Player, "FirstAction", secondsIn(), { participant.Role, name, Match.Ruleset })
end

function Analytics.init()
	DataService.onLoaded(function(player)
		Analytics.step(player, "Joined")
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiters[player] = nil
		visitRounds[player] = nil
	end)
	Match.on("Drawn", function(participant)
		action(participant, "Draw")
	end)
	Match.on("ThrowLanded", function(participant)
		action(participant, "Throw")
	end)
	Match.on("Blackout", function(participant)
		action(participant, "Blackout")
	end)
	Match.on("Torn", function(participant)
		action(participant, "Tear")
	end)
	Match.on("Revived", function(_target, medic)
		action(medic, "Revive")
	end)
	Match.on("Page", function(participant)
		action(participant, "Page")
		if participant and Match.State == "Playing" then
			Analytics.track(participant.Player, "ClueFound", secondsIn(), { participant.Role, Match.MapId })
		end
	end)
	Match.on("Shot", function(participant, result)
		action(participant, "Shot")
		if participant and Match.State == "Playing" then
			Analytics.track(participant.Player, "GuardianAction", 1, { result, Match.Ruleset })
		end
	end)
	Match.on("Down", function(target, _by, how)
		if firstDown or Match.State ~= "Playing" or not target then
			return
		end
		firstDown = true
		Analytics.track(target.Player, "FirstElimination", secondsIn(), { how, Match.Ruleset, Match.MapId })
	end)
	Match.on("Lead", function(participant, family)
		if participant then
			Analytics.track(participant.Player, "LeadSeen", 1, { family })
		end
	end)
end

return Analytics
