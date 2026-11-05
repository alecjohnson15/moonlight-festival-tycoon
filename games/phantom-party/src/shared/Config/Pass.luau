-- The Moon Pass: a season of 30 tiers climbed with XP from playing rounds.
-- Every player gets the free track. The premium track is a game pass
-- (Config/Catalog, "moon_pass") that unlocks fixed, named cosmetics at set
-- tiers, all listed up front, including tiers already reached. The premium
-- track gives only cosmetics: no coins and no crates, so Robux never buys a
-- random item.

export type Reward = { Coins: number?, Item: string?, Crate: string? }

local Pass = {}

Pass.Season = "S1"
Pass.SeasonName = "Season 1: Midnight Gala"
Pass.Tiers = 30
Pass.XpPerTier = 250

-- Rewards on the free track by tier. Tiers not listed give coins.
Pass.Free = {
	[2] = { Coins = 100 },
	[3] = { Coins = 100 },
	[5] = { Item = "mask_paper" },
	[8] = { Crate = "masquerade" },
	[10] = { Coins = 250 },
	[12] = { Item = "fx_sparkle" },
	[16] = { Crate = "masquerade" },
	[18] = { Coins = 300 },
	[20] = { Item = "blaster_paper" },
	[24] = { Crate = "harvest" },
	[27] = { Coins = 400 },
	[30] = { Item = "trail_moonbeam" },
} :: { [number]: Reward }

-- Coins on free-track tiers with nothing else listed.
Pass.FreeCoins = 60

-- Rewards on the premium track. Only these tiers have one.
Pass.Premium = {
	[1] = { Item = "mask_gala" },
	[4] = { Item = "trail_velvet" },
	[7] = { Item = "blaster_music" },
	[11] = { Item = "blade_rose" },
	[15] = { Item = "fx_petals" },
	[19] = { Item = "mask_peacock" },
	[23] = { Item = "trail_aurora" },
	[27] = { Item = "blaster_chandelier" },
	[30] = { Item = "blade_gala" },
} :: { [number]: Reward }

-- The free reward at a tier, filling in coins where none is listed.
function Pass.freeReward(tier: number): Reward
	return Pass.Free[tier] or { Coins = Pass.FreeCoins }
end

return Pass
