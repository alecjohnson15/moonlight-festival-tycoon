--!strict
-- The saved side of a player: what they own, what a run pays them and how
-- the Expedition Pass grows. Kept free of Roblox calls so the tests can
-- check every rule. The server (ProfileService) owns the save and calls
-- these; the client uses the same functions to show what is locked and why.

local Balance = require(script.Parent.Config.Balance)
local Cosmetics = require(script.Parent.Config.Cosmetics)
local Decor = require(script.Parent.Config.Decor)
local Expedition = require(script.Parent.Config.Expedition)
local Roles = require(script.Parent.Config.Roles)

export type Save = {
	SchemaVersion: number,
	Flakes: number,
	Xp: number,
	-- Items bought with snowflakes or earned on the pass, by id.
	Owned: { [string]: boolean },
	-- Roles bought with snowflakes.
	Roles: { [string]: boolean },
	-- Trophies earned in runs: "Yeti" (beat the night 5 boss), "Rescue"
	-- (won a run).
	Trophies: { [string]: boolean },
	-- The cosmetic worn in each slot (Config/Cosmetics.Slots), if any.
	Equipped: { [string]: string },
	-- The decoration on each cabin spot (Config/Decor.Spots).
	Cabin: { [string]: string },
	-- Expedition Pass tiers already paid out on each track, and bonus
	-- payouts after the track is finished.
	ClaimedFree: number,
	ClaimedPremium: number,
	BonusClaimed: number,
	LastRole: string,
	-- The last run paid out, so a run is never paid twice.
	LastRunId: string,
	-- The player's settings (Profile.setSetting checks them).
	Settings: { Music: boolean, Sfx: number, ReduceMotion: boolean },
	Stats: {
		Runs: number,
		Wins: number,
		BestNight: number,
		Knockouts: number,
		Parts: number,
		Thaws: number,
	},
	Receipts: { Ids: { [string]: number }, Order: { string } },
}

-- What a player's game passes grant, gathered from Config/Catalog.
export type Grants = {
	Roles: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	Decor: { [string]: boolean },
	Premium: boolean,
}

-- What one player did in one run.
export type RunStats = {
	Nights: number,
	Parts: number,
	Won: boolean,
	Knockouts: number,
}

local Profile = {}

function Profile.noGrants(): Grants
	return { Roles = {}, Cosmetics = {}, Decor = {}, Premium = false }
end

function Profile.ownsRole(save: Save, grants: Grants, roleId: string): boolean
	local role = Roles.ById[roleId]
	if not role then
		return false
	end
	return role.Price == 0 or save.Roles[roleId] == true or grants.Roles[roleId] == true
end

local function ownsBySource(save: Save, grants: Grants, item: any, isDecor: boolean): boolean
	local source = item.Source
	if source == "Starter" then
		return true
	elseif source == "Shop" or source == "Tier" then
		return save.Owned[item.Id] == true
	elseif source == "Trophy" then
		return save.Trophies[item.Trophy] == true
	elseif source == "Pass" then
		return grants.Cosmetics[item.Id] == true
	elseif source == "Pack" then
		return isDecor and grants.Decor[item.Id] == true
	end
	return false
end

function Profile.ownsCosmetic(save: Save, grants: Grants, id: string): boolean
	local item = Cosmetics.ById[id]
	return item ~= nil and ownsBySource(save, grants, item, false)
end

function Profile.ownsDecor(save: Save, grants: Grants, id: string): boolean
	local item = Decor.ById[id]
	return item ~= nil and ownsBySource(save, grants, item, true)
end

-- How a locked item is unlocked, in words for the shop.
function Profile.howToGet(item: any): string
	local source = item.Source
	if source == "Shop" then
		return `{item.Price} snowflakes`
	elseif source == "Tier" then
		return "Expedition Pass reward"
	elseif source == "Trophy" then
		return if item.Trophy == "Yeti" then "Beat the Old Yeti on night 5" else "Get rescued by the train"
	elseif source == "Pass" or source == "Pack" then
		return "Game pass"
	end
	return ""
end

-- What a player who was there for present nights of a run gets credit
-- for: the win (and its trophy) only after Balance.Rewards.WinMinNights
-- nights, and the team's radio parts after one night. Someone who drops in
-- for the train still gets their nights and their knockouts.
function Profile.credit(present: number, won: boolean, parts: number): (boolean, number)
	local wonCredit = won and present >= Balance.Rewards.WinMinNights
	local partsCredit = if present >= 1 then parts else 0
	return wonCredit, partsCredit
end

-- Snowflakes for one run. Everyone who was there shares the team's nights
-- and radio parts; knockouts are their own.
function Profile.runFlakes(stats: RunStats): number
	local rewards = Balance.Rewards
	local flakes = rewards.PerNight * stats.Nights + rewards.PerPart * stats.Parts
	if stats.Won then
		flakes += rewards.Win
	end
	flakes += math.floor(stats.Knockouts / rewards.KnockoutsPerFlake)
	return flakes
end

-- The pass tier reached with this much XP (0 to the number of tiers).
function Profile.tier(xp: number): number
	return math.min(#Expedition.Tiers, math.floor(xp / Expedition.TierXp))
end

local function grantReward(save: Save, reward: Expedition.Reward): string?
	if reward.Flakes then
		save.Flakes += reward.Flakes
		return `+{reward.Flakes} snowflakes`
	elseif reward.Item then
		save.Owned[reward.Item] = true
		local item = Cosmetics.ById[reward.Item] or Decor.ById[reward.Item]
		return if item then item.Name else reward.Item
	end
	return nil
end

-- Pays out every pass reward the player has reached and not yet had, on the
-- free track and (with premium) the premium track, plus bonus snowflakes
-- past the end. Returns the names of what was given, for the HUD.
function Profile.claim(save: Save, premium: boolean): { string }
	local given = {}
	local reached = Profile.tier(save.Xp)
	while save.ClaimedFree < reached do
		save.ClaimedFree += 1
		local name = grantReward(save, Expedition.Tiers[save.ClaimedFree].Free)
		if name then
			table.insert(given, name)
		end
	end
	if premium then
		while save.ClaimedPremium < reached do
			save.ClaimedPremium += 1
			local name = grantReward(save, Expedition.Tiers[save.ClaimedPremium].Premium)
			if name then
				table.insert(given, name)
			end
		end
	end
	local tiers = #Expedition.Tiers
	local beyond = math.floor(save.Xp / Expedition.TierXp) - tiers
	while save.BonusClaimed < beyond do
		save.BonusClaimed += 1
		save.Flakes += Expedition.BonusFlakes
		table.insert(given, `+{Expedition.BonusFlakes} snowflakes`)
	end
	return given
end

-- Records a finished run in the save: snowflakes, XP, trophies and stats.
-- Returns the snowflakes earned. A run already paid (the same runId as the
-- last one) pays nothing again.
function Profile.finishRun(save: Save, stats: RunStats, beatYeti: boolean, runId: string?): number
	if runId and runId ~= "" then
		if save.LastRunId == runId then
			return 0
		end
		save.LastRunId = runId
	end
	local flakes = Profile.runFlakes(stats)
	save.Flakes += flakes
	save.Xp += flakes * Balance.Rewards.XpPerFlake
	save.Stats.Runs += 1
	save.Stats.BestNight = math.max(save.Stats.BestNight, stats.Nights)
	save.Stats.Knockouts += stats.Knockouts
	save.Stats.Parts += stats.Parts
	if stats.Won then
		save.Stats.Wins += 1
		save.Trophies.Rescue = true
	end
	if beatYeti then
		save.Trophies.Yeti = true
	end
	return flakes
end

-- The next thing to play for, in words, for the results screen: the
-- cheapest role still locked, then the next pass tier, then the trophies.
function Profile.nextGoal(save: Save, grants: Grants): string
	local cheapest = nil
	for _, role in Roles.List do
		if not Profile.ownsRole(save, grants, role.Id) and (not cheapest or role.Price < cheapest.Price) then
			cheapest = role
		end
	end
	if cheapest then
		local short = cheapest.Price - save.Flakes
		if short <= 0 then
			return `You can unlock the {cheapest.Name} now! Open the shop.`
		end
		return `{short} more snowflakes to unlock the {cheapest.Name}.`
	end
	local tier = Profile.tier(save.Xp)
	if tier < #Expedition.Tiers then
		local need = (tier + 1) * Expedition.TierXp - save.Xp
		return `{need} more XP to Expedition Pass tier {tier + 1}.`
	end
	if not save.Trophies.Rescue then
		return "Catch the rescue train to earn the Rescue trophy."
	end
	if not save.Trophies.Yeti then
		return "Beat the Old Yeti on night 5 to earn its trophy."
	end
	return "Every reward is yours. Try for a run where nobody freezes!"
end

-- Changes one setting. Returns false for an unknown setting or a bad value.
function Profile.setSetting(save: Save, key: string, value: any): boolean
	local settings = save.Settings
	if key == "Music" or key == "ReduceMotion" then
		if type(value) ~= "boolean" then
			return false
		end
		settings[key] = value
		return true
	elseif key == "Sfx" then
		if type(value) ~= "number" or value ~= value then
			return false
		end
		settings.Sfx = math.clamp(math.floor(value * 10 + 0.5) / 10, 0, 1)
		return true
	end
	return false
end

-- Buys a shop item or a role with snowflakes. Returns false and why if it
-- can't.
function Profile.buy(save: Save, grants: Grants, id: string): (boolean, string?)
	local role = Roles.ById[id]
	if role then
		if Profile.ownsRole(save, grants, id) then
			return false, "You already have this role"
		end
		if save.Flakes < role.Price then
			return false, "Not enough snowflakes"
		end
		save.Flakes -= role.Price
		save.Roles[id] = true
		return true, nil
	end
	local item: any = Cosmetics.ById[id] or Decor.ById[id]
	if not item or item.Source ~= "Shop" then
		return false, "That can't be bought with snowflakes"
	end
	if save.Owned[id] then
		return false, "You already have this"
	end
	if save.Flakes < item.Price then
		return false, "Not enough snowflakes"
	end
	save.Flakes -= item.Price
	save.Owned[id] = true
	return true, nil
end

-- Puts on a cosmetic (or takes off the slot's item with id ""). Returns
-- false if they don't own it.
function Profile.equip(save: Save, grants: Grants, slot: string, id: string): boolean
	if not table.find(Cosmetics.Slots, slot) then
		return false
	end
	if id == "" then
		save.Equipped[slot] = nil
		return true
	end
	local item = Cosmetics.ById[id]
	if not item or item.Slot ~= slot or not Profile.ownsCosmetic(save, grants, id) then
		return false
	end
	save.Equipped[slot] = id
	return true
end

function Profile.decorate(save: Save, grants: Grants, spot: string, id: string): boolean
	local item = Decor.ById[id]
	if not item or item.Spot ~= spot or not Profile.ownsDecor(save, grants, id) then
		return false
	end
	save.Cabin[spot] = id
	return true
end

-- Drops anything worn or placed that the player no longer owns (a pass
-- refunded, say), going back to the default.
function Profile.tidy(save: Save, grants: Grants)
	for slot, id in save.Equipped do
		if not Profile.ownsCosmetic(save, grants, id) then
			save.Equipped[slot] = nil
		end
	end
	for _, spot in Decor.Spots do
		local id = save.Cabin[spot]
		if not id or not Profile.ownsDecor(save, grants, id) then
			save.Cabin[spot] = Decor.Default[spot]
		end
	end
end

return Profile
