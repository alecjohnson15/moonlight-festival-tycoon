--!strict
-- How fast a player warms up or gets cold, per second. The server runs this
-- for every player a few times a second; the warmth itself lives in the
-- player's "Warmth" attribute so the HUD can show it.

local Balance = require(script.Parent.Config.Balance)

export type Situation = {
	-- Inside the hearth's warm circle.
	AtHearth: boolean,
	-- Beside a lantern or campfire someone built.
	NearWarmth: boolean,
	Night: boolean,
	-- 0 to 1 fractions that each cut the cold: the role, Wool Coats, the
	-- Hearty Stew, a nearby Medic. They stack by multiplying, so they never
	-- add up to complete immunity.
	Resists: { number },
}

local Warmth = {}

-- Warmth gained (positive) or lost (negative) per second.
function Warmth.rate(situation: Situation): number
	local config = Balance.Warmth
	if situation.AtHearth then
		return config.HearthGain
	end
	if situation.NearWarmth then
		return config.StructureGain
	end
	local drain = if situation.Night then config.DrainNight else config.DrainDay
	for _, resist in situation.Resists do
		drain *= 1 - math.clamp(resist, 0, 0.9)
	end
	return -drain
end

-- The warmth a hit from a monster takes off, after the same resists.
function Warmth.hit(amount: number, resists: { number }): number
	local taken = amount
	for _, resist in resists do
		taken *= 1 - math.clamp(resist, 0, 0.9) * 0.5
	end
	return taken
end

function Warmth.clamp(value: number): number
	return math.clamp(value, 0, Balance.Warmth.Max)
end

return Warmth
