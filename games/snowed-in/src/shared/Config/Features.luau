--!strict
-- Switches for the newer mechanics, so each one can be turned off on its
-- own if play-testing shows it doesn't work: set it to false and rebuild.
-- Each switch is read where its mechanic lives, and turning one off puts
-- that part of the game back the way it was before.
-- docs/AUTONOMOUS_UPGRADE_REPORT.md lists what each one changes.

return {
	-- Every night has a theme (Hound Pack, Brute Siege, Wisp Swarm...) that
	-- shapes its wave and is announced from the morning before (shared/Waves).
	-- Off: every night is the same mix, picked at random.
	NightThemes = true,

	-- The yetis wind up their slams (a ring shows where they land), are out
	-- of breath after one (and take double damage), and roar for help at
	-- two-thirds and one-third health (shared/EnemySim). Off: they slam
	-- straight away, the old way.
	BossPhases = true,

	-- Each radio part has its own way to free it: saw the sawmill's logs,
	-- melt the cave ice with a fire tool, light the lighthouse with wood,
	-- pry the depot crate with scrap (Config/Map, shared/Radio). Off: every
	-- part is a 4 second "break the ice".
	LandmarkTrials = true,

	-- A team behind on the radio gets the missing parts marked through the
	-- storm and fewer guards on them (shared/Radio). Off: no help.
	RadioCatchUp = true,

	-- One or two players gather a bit faster and the hearth burns a bit
	-- slower, since there are fewer hands (Config/Balance.SoloAssist). Off:
	-- the same numbers for every team size.
	SoloAssist = true,

	-- A thawed player can't be chilled again for a few seconds, so nobody
	-- gets frozen over and over on the spot (Config/Balance.Warmth). Off: no
	-- grace.
	ThawGrace = true,

	-- Each player may own only a share of the base's structure cap, and can
	-- take down their own builds for half the cost back (shared/Grid). Off:
	-- anyone can fill the whole cap and nothing comes down.
	BuildShare = true,

	-- Team milestones (first hearth upgrade, first night, first radio
	-- part...) get a banner and a line on the results screen
	-- (shared/Milestones). Off: no milestone banners.
	Milestones = true,
}
