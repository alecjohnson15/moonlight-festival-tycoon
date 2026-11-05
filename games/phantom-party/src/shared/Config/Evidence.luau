-- Leads: the imperfect evidence guests pick up during a round, kept in each
-- player's notebook (client/Leads). A lead narrows the suspects or points
-- to a room; it never names anyone, and some leads are wrong on purpose, so
-- talking it over still matters. The Truth Bell stays the big shared
-- payoff (Config/Rewards, Rules/Bell).
--
-- Four kinds, each from something the server saw happen:
--   Witness    You saw a guest tagged close by: you glimpsed the tagger's
--              mask colour. Usually right, sometimes not.
--   Commotion  You heard a tag or a thrown blade nearby: which room.
--   Footprints The Phantom leaves faint glowing footprints for a few seconds
--              after a tag. Nothing on them says whose they are.
--   Tampering  A torn clue page (scraps stay on the floor) or the lights
--              cut: which room, and a glimpse if you saw it happen.
--
-- Rollback: set Enabled to false and the round plays as before this system
-- (no leads, no footprints, no scraps).

local Evidence = {}

Evidence.Enabled = true

-- How long a lead stays in the notebook, and how many it holds.
Evidence.Lifetime = 75
Evidence.MaxLeads = 8

-- Seeing: within this many studs with nothing solid in between.
Evidence.SeeRange = 40
-- Hearing: within this many studs, walls or not.
Evidence.HearRange = 70

-- How often a glimpse of a mask colour is right. The rest of the time it
-- names one of the other colours.
Evidence.GlimpseAccuracy = 0.75

-- The same kind of lead isn't written twice within this many seconds for
-- one player, so a busy room can't flood the notebook.
Evidence.Cooldown = 4

Evidence.Footprints = {
	Enabled = true,
	-- After a tag, prints are left for this long...
	Seconds = 6,
	-- ...one step this often...
	Every = 0.9,
	-- ...each with this chance of showing (so the trail has gaps)...
	Show = 0.75,
	-- ...a little off where the foot really fell...
	Jitter = 1.2,
	-- ...and each fades after this long.
	Fade = 22,
}

-- A torn page leaves scraps on the floor for this long.
Evidence.ScrapSeconds = 30

-- After a blackout, everyone still standing learns roughly where the lights
-- were cut from: the Saboteur's room, right this often, otherwise another
-- room. The Saboteur's risk for causing chaos.
Evidence.Blackout = { Enabled = true, Accuracy = 0.7 }

return Evidence
