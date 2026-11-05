-- How the role tools play. Every number the server checks a hit against is
-- here. Skins only change how a tool looks, never these.

local Combat = {}

-- The Phantom's blade, held.
Combat.Blade = {
	-- Seconds between swings.
	Cooldown = 0.85,
	-- How far a swing reaches, and how wide (degrees either side of facing).
	Reach = 7,
	Arc = 75,
	-- How far above or below a target can be.
	Height = 5,
	-- How long drawing the blade takes before it can tag.
	DrawSeconds = 0.35,
}

-- The Phantom's blade, thrown.
Combat.Throw = {
	Cooldown = 4.5,
	-- Studs per second, and how far it flies before it fades.
	Speed = 120,
	Range = 150,
	-- How fat the blade is for hitting, in studs.
	Radius = 1.1,
	-- The server steps the flight this often.
	Step = 1 / 30,
}

-- The Guardian's Moonbeam Blaster.
Combat.Blaster = {
	-- Seconds to recharge after a shot.
	Cooldown = 2.6,
	Range = 400,
	Radius = 0.7,
	-- How long the hero has to wait after picking up a dropped blaster.
	PickupDelay = 0.6,
}

-- The Saboteur's blackout.
Combat.Blackout = {
	Charges = 2,
	Seconds = 9,
	Cooldown = 30,
	-- Not in the first seconds of a round, when nobody has spread out.
	NotBefore = 20,
}

-- The Medic's revive.
Combat.Revive = {
	Charges = 1,
	-- A second charge on servers this big.
	ExtraChargeAt = 10,
	-- How long the Medic holds the prompt.
	HoldSeconds = 1.2,
	Range = 9,
}

-- How far from where the server last saw them a player may claim to be
-- standing when they act, allowing for lag.
Combat.OriginSlack = 10

-- An action that arrives up to this fraction of its cooldown early still
-- counts, for network jitter.
Combat.CooldownSlack = 0.1

return Combat
