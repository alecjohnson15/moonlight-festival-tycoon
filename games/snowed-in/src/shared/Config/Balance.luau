--!strict
-- The numbers that set the pace of a run: how long days and nights last, how
-- fast the hearth burns and players get cold, and how the waves grow with
-- the night and the number of players. Every value here is read by the
-- tests (tests/Balance.spec), so a change that makes the run unwinnable or
-- trivial shows up there first. tools/simulate_run.luau plays a whole run
-- with these numbers and prints how close the hearth came to going out.

local Balance = {}

Balance.MaxPlayers = 8

-- The finish line: the rescue train comes at the dawn after this night, as
-- long as the radio has called it. If the radio isn't fixed by then, the
-- nights go on (harder each time) until it is, up to LastNight.
Balance.Nights = 10
Balance.LastNight = 15

-- Seconds in each part of the run.
Balance.Phases = {
	-- Waiting for the run to start once somebody is in the server.
	Intermission = 30,
	-- The first day is longer, so new players can learn the loop in peace.
	FirstDay = 210,
	Day = 150,
	-- A warning before night: the sky turns and the horn sounds.
	Dusk = 20,
	Night = 120,
	Dawn = 12,
	-- The results screen before the town resets for the next run.
	Results = 25,
}

-- The hearth is the team's life: if its flame reaches zero the run is lost.
-- Each level is bought with team resources at the hearth, and pushes the
-- blizzard back (Fog is the Atmosphere density the clients use, lower is
-- clearer), warms a wider circle and holds more flame.
Balance.Hearth = {
	StartFlame = 80,
	BurnPerSecondDay = 0.12,
	BurnPerSecondNight = 0.3,
	-- How much flame one of each fuel adds.
	Fuel = { Wood = 4, Coal = 12 },
	-- How many of a fuel one press of "Feed" takes from the stockpile.
	FeedBatch = 5,
	Levels = {
		{ MaxFlame = 100, Radius = 30, FogDay = 0.42, FogNight = 0.55, Cost = {} },
		{ MaxFlame = 130, Radius = 38, FogDay = 0.38, FogNight = 0.51, Cost = { Wood = 30, Stone = 15 } },
		{ MaxFlame = 160, Radius = 46, FogDay = 0.34, FogNight = 0.47, Cost = { Wood = 45, Stone = 30, Scrap = 10 } },
		{
			MaxFlame = 200,
			Radius = 54,
			FogDay = 0.3,
			FogNight = 0.43,
			Cost = { Wood = 60, Stone = 40, Scrap = 25, Coal = 10 },
		},
		{
			MaxFlame = 250,
			Radius = 62,
			FogDay = 0.26,
			FogNight = 0.39,
			Cost = { Wood = 80, Stone = 60, Scrap = 40, Coal = 20 },
		},
	},
}

-- Players get cold away from heat. At zero warmth they freeze in a block of
-- ice (the game's knockout): a teammate can thaw them, or after
-- FrozenSeconds they wake up by the hearth, which costs it some flame.
Balance.Warmth = {
	Max = 100,
	-- Per second, inside the hearth's circle.
	HearthGain = 8,
	-- Per second, away from any heat.
	DrainDay = 0.3,
	DrainNight = 1.1,
	-- Seconds a teammate holds the thaw prompt (the Medic is quicker).
	ThawSeconds = 3,
	ThawWarmth = 40,
	FrozenSeconds = 25,
	RespawnWarmth = 50,
	RespawnFlameCost = 4,
	-- Warmth from standing still beside the warm things players build.
	StructureGain = 4,
	-- Seconds after a thaw when monsters can't chill the player again
	-- (Config/Features.ThawGrace), so nobody is frozen over and over on
	-- the spot.
	ThawGraceSeconds = 4,
}

-- Small teams have fewer hands, not just fewer monsters: with one or two
-- players (Config/Features.SoloAssist) gathering holds are this much
-- quicker and the hearth burns this share of its usual rate. The pacing
-- model (tools/RunModel.luau) and tests/Pacing.spec check the numbers.
Balance.SoloAssist = {
	UpToPlayers = 2,
	GatherSpeed = { [1] = 0.3, [2] = 0.15 },
	Burn = { [1] = 0.8, [2] = 0.9 },
}

-- The rescue radio (shared/Radio).
Balance.Radio = {
	-- A part left lying loose this long (dropped by a carrier who froze,
	-- left or fell) goes back to its landmark, unfrozen, so it can never be
	-- lost somewhere nobody can reach.
	LooseReturnSeconds = 90,
	-- The plain "break the ice" when Config/Features.LandmarkTrials is off.
	BreakSeconds = 4,
	-- Catch-up (Config/Features.RadioCatchUp): from night CatchUpFrom, a
	-- team should have fitted one part every CatchUpEvery nights. A team
	-- behind that gets the missing parts marked and one guard fewer at each.
	CatchUpFrom = 4,
	CatchUpEvery = 2,
}

Balance.Backpack = 20
Balance.FoodPocket = 3
Balance.WalkSpeed = 16

-- Players can build anywhere within this distance of the hearth, on a grid.
Balance.Build = {
	Radius = 84,
	Grid = 4,
	-- Most structures a run may hold, to keep the part count down.
	MaxStructures = 60,
	-- With Config/Features.BuildShare, one player may own at most this
	-- many, or an even share of the cap if that is more, so no one player
	-- can spend the whole base. Taking down your own build gives back
	-- RefundShare of what it cost.
	PerPlayerMin = 15,
	RefundShare = 0.5,
	-- Space kept clear around the hearth and the base's stations.
	ClearRadius = 12,
}

-- Waves: each night has a budget of points (NightBase + NightGrowth * night)
-- scaled by the number of players, spent on monsters that cost Points each
-- (Config/Enemies). Monsters arrive over SpawnWindow of the night.
Balance.Waves = {
	NightBase = 6,
	NightGrowth = 5,
	-- Points multiplier: Solo for one player, plus PerExtraPlayer for each
	-- other player, up to Max.
	Solo = 0.6,
	PerExtraPlayer = 0.2,
	Max = 2,
	-- After the finish line the nights keep growing faster.
	OvertimeGrowth = 9,
	SpawnWindow = 0.7,
	-- Most monsters alive at once; extra spawns wait their turn.
	MaxAlive = 60,
	-- Monsters that guard the radio parts by day, at each landmark.
	GuardsPerLandmark = 3,
}

-- Bosses: their health grows with the number of players by the same
-- multiplier as the waves, so a solo boss is beatable.
Balance.Bosses = {
	[5] = "Yeti",
	[10] = "ElderYeti",
}

-- What a run pays every player who took part, in snowflakes (the saved
-- currency) and pass XP.
Balance.Rewards = {
	PerNight = 10,
	PerPart = 5,
	Win = 60,
	-- One snowflake per this many monsters a player knocks out.
	KnockoutsPerFlake = 5,
	XpPerFlake = 10,
	-- Someone who joined late shares the win bonus and the rescue trophy
	-- only if they were there for at least this many nights, and the radio
	-- parts only if they saw at least one night.
	WinMinNights = 3,
}

-- How long the server waits for a player to choose a role before giving
-- them the first free one.
Balance.RoleChoiceSeconds = 40

return Balance
