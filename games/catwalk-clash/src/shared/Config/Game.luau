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

	-- Switches for the show's newer parts, so each can be turned off on its
	-- own if it misbehaves (docs/AUTONOMOUS_UPGRADE_REPORT.md has rollback
	-- notes).
	Show = {
		-- "Random" (byes and first opponents by luck of the draw) or
		-- "Rating" (by Style Score, the launch rule).
		Seeding = "Random",
		-- Everyone in the show stands on the runway together for a moment
		-- before the first matchup, so every look is seen at least once.
		Lineup = true,
		LineupSeconds = 7,
		-- Each walker hears a few words from the judges on their look
		-- ("Theme ★★★", "Colour match"), never the exact score.
		JudgeFeedback = true,
	},

	Voting = {
		-- A vote is "suspect" when the voter is a Roblox friend of the walker
		-- they voted for, or their account is younger than NewAccountDays.
		-- Capped (the default): for each walker, the first SuspectFullVotes
		-- suspect votes count in full and any more count SuspectWeight each,
		-- so a newcomer or a friend in an honest crowd counts like anyone
		-- else but a big friend group or a pile of new alts can't take over.
		-- Flat (the launch rule, to roll back): every suspect vote counts
		-- FriendWeight and/or NewAccountWeight.
		Mode = "Capped",
		SuspectFullVotes = 2,
		SuspectWeight = 0.5,
		FriendWeight = 0.5,
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
		-- A player's first walks can only raise their score (0 turns it off).
		ProtectedWalks = 10,
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
