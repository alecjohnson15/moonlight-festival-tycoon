--!strict
-- Ghost Catcher, the plot's repeatable activity between purchases: its owner
-- steps on the pad in front of the booth at the back of the walkway, and
-- wisps pop up one after another down the middle of the plot, each waiting a
-- few seconds to be caught by walking through it. Plain numbers so this file
-- loads in tests as well as in Studio. The booth's place is in Config/Layout,
-- and docs/progression.md has what the rounds do to the pacing.

return {
	RoundSeconds = 25,
	-- The rest from the end of one round to the start of the next. With the
	-- rewards below it keeps rounds back to back, and every Moonlight Parade
	-- caught in full, under 7.5% extra income (see docs/progression.md).
	CooldownSeconds = 72,
	-- A short wait after the pad is stepped on, so the first wisp doesn't
	-- appear before the player's screen is ready for it.
	LeadSeconds = 1,
	Wisps = 12,
	-- How long each wisp waits to be caught before it fades.
	WispSeconds = 6,
	-- Each wisp appears between MinGap and MaxGap studs from the one before
	-- (the first, from the pad), so catching them means a run, not a step.
	MinGap = 10,
	MaxGap = 26,
	-- How close a player's middle must come to a wisp to catch it, across the
	-- ground and up or down.
	CatchRadius = 4.5,
	CatchHeight = 5,
	-- Wisps float this high over the floor.
	Height = 3,
	-- Each wisp pays RewardSeconds of the plot's income, and never less than
	-- MinReward coins; catching every wisp in a round pays PerfectSeconds more
	-- (at least twice MinReward).
	RewardSeconds = 0.4,
	MinReward = 2,
	PerfectSeconds = 2,
	-- Where wisps appear, in plot-local studs: a strip along the walkway down
	-- the middle of the plot, far enough from the buildings' pads that a
	-- player catching one never stands on a pad.
	Area = { X = -1, Z = 2, Width = 8, Depth = 64 },
}
