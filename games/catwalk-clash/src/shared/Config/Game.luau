--!strict
-- The numbers that shape a round and the economy, in one place so they can
-- be tuned without touching the code. Times are in seconds.

return {
	Name = "Catwalk Clash",
	Tagline = "Dress up. Strut. Win the crown.",

	Round = {
		-- The lobby, with the theme vote in its last part.
		Intermission = 22,
		ThemeVote = 15,
		Reveal = 5,
		Dressing = 150,
		-- When every contestant has pressed Ready, dressing ends this soon.
		AllReady = 8,
		-- Players who join with less dressing time left than this watch the
		-- show and play the next round.
		LateJoinCutoff = 40,
		Crowning = 14,
		-- Rivals (Config/Rivals) fill the bracket up to this many walkers.
		MinEntrants = 4,
		MaxEntrants = 16,
	},

	Match = {
		-- Both walkers stride down their lane, pose at the end, then the
		-- audience's votes close and the result is shown.
		Intro = 2.5,
		Walk = 7,
		Pose = 3.5,
		-- Votes count only after the walkers have been on show this long, so
		-- nobody votes before seeing the outfits.
		VoteOpensAfter = 2.5,
		VoteGrace = 2,
		Result = 3.5,
		StrutSpeed = 11,
	},

	Voting = {
		-- A vote from a Roblox friend of either walker counts this much.
		FriendWeight = 0.5,
		-- A vote from an account younger than NewAccountDays counts this much.
		NewAccountWeight = 0.5,
		NewAccountDays = 7,
		-- Each judge's vote is worth JudgeBase minus JudgeFade per audience
		-- vote, but never less than JudgeFloor, so judges decide quiet servers
		-- and the crowd decides busy ones.
		JudgeBase = 3,
		JudgeFade = 0.25,
		JudgeFloor = 0.5,
	},

	StyleScore = {
		Start = 1000,
		Floor = 100,
		-- Elo K factor: higher for players still finding their level.
		NewK = 32,
		K = 20,
		NewUntilWalks = 30,
		-- Matches against rivals move the score half as much.
		RivalScale = 0.5,
		-- A small reward for walking at all, win or lose.
		WalkBonus = 2,
	},

	-- Sparkles (the currency) and Style Pass XP for each thing a player does.
	Rewards = {
		Walk = { Sparkles = 20, Xp = 60 },
		MatchWin = { Sparkles = 35, Xp = 80 },
		Crown = { Sparkles = 150, Xp = 250 },
		RunnerUp = { Sparkles = 60, Xp = 100 },
		-- Voting pays a little per vote, up to VoteCap votes a round, plus a
		-- bonus when the vote matched the crowd's pick ("good taste").
		Vote = { Sparkles = 3, Xp = 10 },
		VoteCap = 10,
		Taste = { Sparkles = 2, Xp = 5 },
		-- Up to this much for wearing the theme well (judges' theme score).
		ThemeBonus = { Sparkles = 20, Xp = 40 },
		-- The weekly spotlight theme pays this many times as much.
		SpotlightMultiplier = 2,
		StartingSparkles = 250,
		-- Daily login streak: day 1, 2, ... (the last value repeats).
		Streak = { 50, 75, 100, 125, 150, 200, 300 },
	},

	Looks = {
		-- Saved outfits: this many free, more with the Big Closet pass.
		FreeSlots = 4,
		ClosetSlots = 24,
		MaxFavorites = 150,
		MaxCatalogItems = 14,
	},

	-- How often a player may send each request, in seconds.
	Cooldowns = {
		SetLook = 0.35,
		Vote = 0.25,
		Search = 1.2,
		Shop = 0.5,
	},
}
