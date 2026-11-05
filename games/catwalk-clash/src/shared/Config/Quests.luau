--!strict
-- Daily challenges. Each day (UTC) every player gets the same three, picked
-- from this pool by shared/Quests, so friends can chase them together.
-- Event is what counts towards Goal; the server records events by name.

export type Quest = {
	Id: string,
	Text: string,
	Event: string,
	Goal: number,
	Sparkles: number,
	Xp: number,
}

return {
	{ Id = "walk3", Text = "Walk the runway 3 times", Event = "Walk", Goal = 3, Sparkles = 60, Xp = 150 },
	{ Id = "win2", Text = "Win 2 matchups", Event = "MatchWin", Goal = 2, Sparkles = 80, Xp = 200 },
	{ Id = "vote10", Text = "Vote in 10 matchups", Event = "Vote", Goal = 10, Sparkles = 50, Xp = 150 },
	{ Id = "theme3", Text = "Nail the theme 3 times", Event = "ThemeMatch", Goal = 3, Sparkles = 70, Xp = 180 },
	{ Id = "semi", Text = "Reach a semifinal", Event = "ReachSemi", Goal = 1, Sparkles = 80, Xp = 200 },
	{ Id = "crown", Text = "Win the crown", Event = "Crown", Goal = 1, Sparkles = 150, Xp = 300 },
	{ Id = "save_look", Text = "Save an outfit to your closet", Event = "SaveLook", Goal = 1, Sparkles = 40, Xp = 100 },
	{ Id = "catalog3", Text = "Try on 3 catalog items", Event = "CatalogTry", Goal = 3, Sparkles = 40, Xp = 100 },
	{ Id = "recolor5", Text = "Recolour 5 pieces", Event = "Recolor", Goal = 5, Sparkles = 40, Xp = 100 },
	{ Id = "taste5", Text = "Vote for the crowd's favourite 5 times", Event = "Taste", Goal = 5, Sparkles = 60, Xp = 150 },
	{ Id = "rounds3", Text = "Play 3 rounds", Event = "Round", Goal = 3, Sparkles = 60, Xp = 150 },
	{ Id = "glow", Text = "Walk wearing something that glows", Event = "GlowWalk", Goal = 1, Sparkles = 40, Xp = 100 },
	{ Id = "pose3", Text = "Strike 3 different poses", Event = "NewPose", Goal = 3, Sparkles = 50, Xp = 120 },
}
