--!strict
-- The Truth Bell, the pure part: how many pages fill it for a party of a
-- given size, and what each page does. PickupService rings it; the tests
-- model how often it rings (tests/Sims.spec).

local Rewards = require(script.Parent.Parent.Config.Rewards)

export type Config = {
	Base: number,
	PerGuest: number,
	Min: number,
	Max: number,
	RoomAt: number,
	HintSeconds: number,
	TrackRoom: boolean,
	MaxRings: number,
	RevealSeconds: number,
}

export type Bell = {
	-- Pages in this fill, and pages a fill takes.
	Pages: number,
	Need: number,
	-- Percent full, 0 to 100.
	Value: number,
	Rings: number,
	-- Whether this fill has chimed the room yet.
	Hinted: boolean,
	-- Rung as often as it may this round: pages no longer fill it.
	Spent: boolean,
}

local Bell = {}

-- Pages that fill the bell with guests guests in the round.
function Bell.need(guests: number, config: Config?): number
	local settings = config or Rewards.Bell
	local pages = math.floor(settings.Base + settings.PerGuest * math.max(0, guests) + 0.5)
	return math.clamp(pages, settings.Min, settings.Max)
end

function Bell.new(guests: number, config: Config?): Bell
	return { Pages = 0, Need = Bell.need(guests, config), Value = 0, Rings = 0, Hinted = false, Spent = false }
end

-- A guest brought a page. Returns "Hint" when the bell passes the half-way
-- mark, "Ring" when it fills, or nil.
function Bell.add(bell: Bell, config: Config?): string?
	local settings = config or Rewards.Bell
	if bell.Spent then
		return nil
	end
	bell.Pages += 1
	bell.Value = math.min(100, math.floor(100 * bell.Pages / bell.Need))
	if bell.Pages >= bell.Need then
		bell.Rings += 1
		bell.Pages = 0
		bell.Value = 0
		bell.Hinted = false
		bell.Spent = bell.Rings >= settings.MaxRings
		return "Ring"
	end
	if not bell.Hinted and bell.Value >= settings.RoomAt then
		bell.Hinted = true
		return "Hint"
	end
	return nil
end

return Bell
