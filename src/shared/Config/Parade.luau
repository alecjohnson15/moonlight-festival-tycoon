--!strict
-- The Moonlight Parade, the festival's shared moment: every so often a
-- parade of floats circles the Moonlight Wheel in the arrival courtyard,
-- letting go of lanterns as it goes. Everyone on the server can catch them
-- by running through them, and every catch fills one shared meter. Plain
-- numbers so this file loads in tests as well as in Studio. The route is the
-- courtyard's (the theme's Courtyard), and docs/progression.md has what the
-- rewards do to the pacing.

return {
	-- Server time from the server starting to the first parade, and from the
	-- start of one parade to the start of the next.
	FirstSeconds = 150,
	IntervalSeconds = 600,
	-- How long before a parade everyone is told it's coming.
	WarnSeconds = 30,
	RunSeconds = 60,

	-- The floats: how many, and how long one takes to go once round.
	Floats = 3,
	LapSeconds = 30,

	-- Lanterns let go over a parade: Lanterns, plus LanternsPerPlayer for
	-- each player on the server. Each floats at Height for LanternSeconds,
	-- up to Spread studs either side of the route, and is caught by the
	-- first player whose middle comes within CatchRadius of it.
	Lanterns = 12,
	LanternsPerPlayer = 6,
	LanternSeconds = 8,
	Spread = 4,
	Height = 3,
	CatchRadius = 4.5,
	CatchHeight = 5,
	-- The share of a parade's lanterns the server must catch to fill the
	-- meter.
	GoalShare = 0.6,

	-- Each catch pays RewardSeconds of the catcher's income, and never less
	-- than MinReward coins, for the first PaidLanterns they catch in a
	-- parade (more still fill the meter). If the meter fills, everyone who
	-- caught one gets FullSeconds of their income more, and never less than
	-- FullMinReward. Kept small so the pacing holds: see bonusShare in
	-- shared/Parade and docs/progression.md.
	RewardSeconds = 0.3,
	MinReward = 2,
	PaidLanterns = 6,
	FullSeconds = 1,
	FullMinReward = 5,
}
