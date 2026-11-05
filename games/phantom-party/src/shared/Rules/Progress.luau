--!strict
-- Levels, the Moon Pass and what a round pays. Pure, so the tests can check
-- the pacing: how many rounds a level or a tier takes.

local Pass = require(script.Parent.Parent.Config.Pass)
local Rewards = require(script.Parent.Parent.Config.Rewards)

export type Summary = {
	Won: boolean,
	Survived: boolean,
	Tags: number,
	Takedown: boolean,
	Revives: number,
	Clues: number,
	-- Candy coins picked up, already capped.
	Coins: number,
}

export type Line = { Label: string, Coins: number, Xp: number }

export type PassSave = {
	Season: string,
	Xp: number,
	Free: { [string]: boolean },
	Premium: { [string]: boolean },
}

local Progress = {}

-- XP needed to go from level to the next.
function Progress.levelCost(level: number): number
	return Rewards.Level.Base + Rewards.Level.Step * (level - 1)
end

-- The level reached with xp in all, the XP into it and the XP it takes.
function Progress.level(xp: number): (number, number, number)
	local level = 1
	local left = xp
	while level < Rewards.Level.Max and left >= Progress.levelCost(level) do
		left -= Progress.levelCost(level)
		level += 1
	end
	return level, left, Progress.levelCost(level)
end

-- The pass tier reached (0 before the first), the XP into the next tier
-- and what each tier takes.
function Progress.tier(xp: number): (number, number, number)
	local tier = math.min(Pass.Tiers, math.floor(xp / Pass.XpPerTier))
	local into = if tier >= Pass.Tiers then Pass.XpPerTier else xp - tier * Pass.XpPerTier
	return tier, into, Pass.XpPerTier
end

-- Coins and XP for a round, line by line.
function Progress.pay(summary: Summary): { Coins: number, Xp: number, Lines: { Line } }
	local coins = Rewards.Coins
	local xp = Rewards.Xp
	local lines: { Line } = {}
	local function add(label: string, coinAmount: number, xpAmount: number)
		if coinAmount > 0 or xpAmount > 0 then
			table.insert(lines, { Label = label, Coins = coinAmount, Xp = xpAmount })
		end
	end
	add("Played the round", 0, xp.Played)
	if summary.Coins > 0 then
		add(`Candy coins x{summary.Coins}`, summary.Coins * coins.Pickup, summary.Coins * xp.Coin)
	end
	if summary.Won then
		add("Your team won", coins.Win, xp.Win)
	end
	if summary.Survived then
		add("Survived", coins.Survive, xp.Survive)
	end
	if summary.Tags > 0 then
		add(`Guests tagged x{summary.Tags}`, summary.Tags * coins.Tag, summary.Tags * xp.Tag)
	end
	if summary.Takedown then
		add("Knocked out the Phantom", coins.Takedown, xp.Takedown)
	end
	if summary.Revives > 0 then
		add(`Revived x{summary.Revives}`, summary.Revives * coins.Revive, summary.Revives * xp.Revive)
	end
	-- Pages pay up to a cap a round, so they can't be farmed.
	local clues = math.min(summary.Clues, Rewards.ClueCap)
	if clues > 0 then
		add(`Clue pages x{clues}`, clues * coins.Clue, clues * xp.Clue)
	end
	local totalCoins, totalXp = 0, 0
	for _, line in lines do
		totalCoins += line.Coins
		totalXp += line.Xp
	end
	return { Coins = totalCoins, Xp = totalXp, Lines = lines }
end

-- A fresh pass save for the current season, or the given one if it's for
-- this season already.
function Progress.passFor(save: PassSave?): PassSave
	if save and save.Season == Pass.Season then
		return save
	end
	return { Season = Pass.Season, Xp = 0, Free = {}, Premium = {} }
end

-- Whether a tier's reward on a track can be claimed now.
function Progress.canClaim(save: PassSave, track: string, tier: number, premium: boolean): (boolean, string?)
	if tier < 1 or tier > Pass.Tiers or tier ~= math.floor(tier) then
		return false, "NoSuchTier"
	end
	local reached = Progress.tier(save.Xp)
	if tier > reached then
		return false, "NotReached"
	end
	local key = tostring(tier)
	if track == "Free" then
		if save.Free[key] then
			return false, "Claimed"
		end
		return true, nil
	elseif track == "Premium" then
		if not Pass.Premium[tier] then
			return false, "NoReward"
		elseif not premium then
			return false, "NeedsPremium"
		elseif save.Premium[key] then
			return false, "Claimed"
		end
		return true, nil
	end
	return false, "NoSuchTrack"
end

-- Marks a tier claimed and returns its reward.
function Progress.claim(save: PassSave, track: string, tier: number, premium: boolean): (Pass.Reward?, string?)
	local ok, err = Progress.canClaim(save, track, tier, premium)
	if not ok then
		return nil, err
	end
	local key = tostring(tier)
	if track == "Free" then
		save.Free[key] = true
		return Pass.freeReward(tier), nil
	end
	save.Premium[key] = true
	return Pass.Premium[tier], nil
end

-- Every reward that's ready to claim, in tier order.
function Progress.claimable(save: PassSave, premium: boolean): { { Track: string, Tier: number } }
	local ready = {}
	for tier = 1, Pass.Tiers do
		for _, track in { "Free", "Premium" } do
			if Progress.canClaim(save, track, tier, premium) then
				table.insert(ready, { Track = track, Tier = tier })
			end
		end
	end
	return ready
end

return Progress
