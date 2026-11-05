-- Reports how players get on to Roblox's analytics, so changes can be
-- measured in the Creator Dashboard:
--   - the first-time funnel: joined, had a role revealed, finished a
--     round, finished a second round, equipped or bought something. Each
--     step is logged once per player, ever, in order.
--   - custom events: RoundPlayed (by role, won or lost), CrateOpened (which
--     crate and the rarity), Traded (items each way) and PassClaimed.
-- Nothing here changes the game; a failed call is skipped.

local AnalyticsService = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)

local STEPS = { "Joined", "RoleRevealed", "FinishedRound", "SecondRound", "Equipped" }

local Analytics = {}

local function field(index: number): string
	return (Enum.AnalyticsCustomFieldKeys :: any)[string.format("CustomField%02d", index)].Name
end

local function event(player: Player, name: string, value: number?, fields: { string }?)
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
	for _, player in players do
		Analytics.step(player, "RoleRevealed")
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
	event(player, "RoundPlayed", 1, { role, if won then "Won" else "Lost" })
end

function Analytics.crateOpened(player: Player, crateId: string, rarity: string)
	event(player, "CrateOpened", 1, { crateId, rarity })
end

function Analytics.traded(player: Player, gave: number, got: number)
	event(player, "Traded", gave + got, { tostring(gave), tostring(got) })
end

function Analytics.init()
	DataService.onLoaded(function(player)
		Analytics.step(player, "Joined")
	end)
end

return Analytics
