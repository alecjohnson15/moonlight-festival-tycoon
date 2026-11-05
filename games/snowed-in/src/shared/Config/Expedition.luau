--!strict
-- The Expedition Pass: a track of rewards earned with XP from playing (every
-- snowflake a run pays also gives Balance.Rewards.XpPerFlake XP). Each tier
-- has a free reward for everyone and a premium reward for owners of the
-- Expedition Pass: Premium game pass. Every reward is shown on the track
-- before it is earned and before anyone buys the pass; there is nothing
-- random in it. Once the track is finished, every further TierXp pays
-- BonusFlakes.
--
-- A reward is { Flakes = n } or { Item = id }, where id is a Config/Cosmetics
-- or Config/Decor item whose Source is "Tier".

export type Reward = { Flakes: number?, Item: string? }

export type Tier = { Free: Reward, Premium: Reward }

local Expedition = {}

Expedition.TierXp = 800
Expedition.BonusFlakes = 25

Expedition.Tiers = {
	{ Free = { Flakes = 25 }, Premium = { Item = "AntlerBeanie" } },
	{ Free = { Item = "EmberBrazier" }, Premium = { Flakes = 50 } },
	{ Free = { Flakes = 30 }, Premium = { Item = "EmberTrail" } },
	{ Free = { Item = "MinerHelmet" }, Premium = { Item = "IceSculpture" } },
	{ Free = { Flakes = 40 }, Premium = { Flakes = 75 } },
	{ Free = { Item = "BerryWreath" }, Premium = { Item = "PolarBearHat" } },
	{ Free = { Flakes = 50 }, Premium = { Item = "SparkleTrail" } },
	{ Free = { Item = "LanternPack" }, Premium = { Flakes = 100 } },
	{ Free = { Flakes = 60 }, Premium = { Item = "PenguinStatue" } },
	{ Free = { Item = "AuroraFlag" }, Premium = { Item = "FrostWings" } },
	{ Free = { Flakes = 70 }, Premium = { Flakes = 120 } },
	{ Free = { Item = "RoofStar" }, Premium = { Flakes = 150 } },
	{ Free = { Flakes = 100 }, Premium = { Item = "SnowOwl" } },
} :: { Tier }

return Expedition
