--!strict
-- The Style Pass: a season of 30 tiers earned with XP from playing. Every
-- tier has a free reward, and a premium reward for owners of the season's
-- pass (Config/Catalog). Every reward is shown before anyone buys; nothing is
-- random and tiers can't be bought or skipped with Robux.
--
-- A reward is { Sparkles = n }, { Piece = id } (Config/Wardrobe),
-- { Pose = id } (Config/Poses) or { Entrance = id } (Config/Entrances).
--
-- For the next season: copy this file's shape with a new Id, dates, pass id
-- and rewards. Claimed rewards stay owned forever.

export type Reward = { Sparkles: number?, Piece: string?, Pose: string?, Entrance: string? }
export type Tier = { Free: Reward, Premium: Reward }

local Season = {
	Id = "S1",
	Name = "Season 1: Glow Up",
	-- Unix times: 2026-11-01 to 2027-02-01 (UTC).
	Starts = 1793491200,
	Ends = 1801440000,
	Pass = "style_pass_s1",
	XpPerTier = 500,
	Tiers = {} :: { Tier },
}

Season.Tiers = {
	{ Free = { Sparkles = 75 }, Premium = { Sparkles = 200 } },
	{ Free = { Sparkles = 75 }, Premium = { Pose = "kiss" } },
	{ Free = { Piece = "s1_fan_bag" }, Premium = { Sparkles = 200 } },
	{ Free = { Sparkles = 100 }, Premium = { Entrance = "glitter_storm" } },
	{ Free = { Sparkles = 100 }, Premium = { Sparkles = 250 } },
	{ Free = { Sparkles = 100 }, Premium = { Piece = "s1_glow_tiara" } },
	{ Free = { Sparkles = 100 }, Premium = { Sparkles = 250 } },
	{ Free = { Entrance = "petal_shower" }, Premium = { Piece = "feather_boa" } },
	{ Free = { Sparkles = 125 }, Premium = { Piece = "s1_star_heels" } },
	{ Free = { Sparkles = 125 }, Premium = { Sparkles = 300 } },
	{ Free = { Sparkles = 125 }, Premium = { Pose = "cool_lean" } },
	{ Free = { Piece = "hair_starlight" }, Premium = { Sparkles = 300 } },
	{ Free = { Sparkles = 150 }, Premium = { Piece = "jetpack" } },
	{ Free = { Sparkles = 150 }, Premium = { Sparkles = 300 } },
	{ Free = { Sparkles = 150 }, Premium = { Piece = "s1_spotlight_gown" } },
	{ Free = { Sparkles = 150 }, Premium = { Entrance = "paparazzi" } },
	{ Free = { Sparkles = 175 }, Premium = { Sparkles = 350 } },
	{ Free = { Pose = "point" }, Premium = { Piece = "s1_runway_wings" } },
	{ Free = { Sparkles = 175 }, Premium = { Sparkles = 350 } },
	{ Free = { Sparkles = 175 }, Premium = { Pose = "runway_royalty" } },
	{ Free = { Sparkles = 200 }, Premium = { Piece = "s1_icon_jacket" } },
	{ Free = { Entrance = "bubble_parade" }, Premium = { Sparkles = 400 } },
	{ Free = { Sparkles = 200 }, Premium = { Piece = "dragon_wings" } },
	{ Free = { Sparkles = 200 }, Premium = { Piece = "aura_rainbow" } },
	{ Free = { Sparkles = 225 }, Premium = { Entrance = "crown_rain" } },
	{ Free = { Sparkles = 225 }, Premium = { Sparkles = 450 } },
	{ Free = { Sparkles = 250 }, Premium = { Piece = "s1_legend_crown" } },
	{ Free = { Sparkles = 250 }, Premium = { Sparkles = 500 } },
	{ Free = { Sparkles = 300 }, Premium = { Sparkles = 600 } },
	{ Free = { Sparkles = 400 }, Premium = { Piece = "aura_gold" } },
}

return Season
