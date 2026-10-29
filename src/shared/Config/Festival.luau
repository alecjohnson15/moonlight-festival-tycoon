--!strict
-- Each player's own festival: what they can choose to make their plot look
-- like theirs, and what unlocks each choice. Plain data with theme-neutral
-- ids; the names, colours and models come from the active theme pack
-- (Theme.FestivalNames, Theme.Palettes, Theme.Decor and the pack's Festival
-- module). Where everything stands on a plot is in Config/Layout.
--
-- A festival has:
--   a name, one word from each of the theme's three word lists (so there is
--   no free text to filter), picked at random from the player's id when they
--   first claim a plot;
--   a palette, the two colours of the stall's awning, its add-ons and the
--   Ghost Catcher booth;
--   a decoration in each of the plot's decoration spots;
--   a trophy shelf that fills itself.
--
-- Unlock is nil for things every player starts with, or one of:
--   Owns = id           owns that upgrade
--   Building = id       has finished a path of that building (Path = name
--                       for one path only, Tier = n for only that tier)
--   ActivityBest = n    has caught n wisps in one Ghost Catcher round
--   Parades = n         has caught lanterns in n Moonlight Parades
--
-- Nothing here changes coins or income. Everything is earned by playing;
-- none of it is sold.

return {
	-- How many words a festival name has, one from each of the theme's lists.
	NameWords = 3,

	-- In the order the board shows them. The first is every new festival's.
	Palettes = {
		{ Id = "classic" },
		{ Id = "harvest" },
		{ Id = "toxic", Unlock = { ActivityBest = 8 } },
		{ Id = "blood_moon", Unlock = { Building = "starter_stall" } },
		{ Id = "midnight", Unlock = { Parades = 1 } },
		{ Id = "phantom", Unlock = { Owns = "attraction_3" } },
	},

	-- Decorations for the plot's decoration spots, in the order the board
	-- shows them.
	Decor = {
		{ Id = "hay_corner" },
		{ Id = "graveyard_corner" },
		{ Id = "pumpkin_pile" },
		{ Id = "witch_cauldron", Unlock = { Owns = "kitchen" } },
		{ Id = "lantern_arch", Unlock = { ActivityBest = 6 } },
		{ Id = "moon_fountain", Unlock = { Parades = 1 } },
		{ Id = "bat_topiary", Unlock = { Building = "attraction_1" } },
		{ Id = "ghost_statue", Unlock = { ActivityBest = 12 } },
		{ Id = "parade_float", Unlock = { Parades = 3 } },
		{ Id = "skeleton_band", Unlock = { Building = "attraction_3" } },
	},

	-- What each decoration spot (Layout.Decor, in order) holds until the
	-- owner picks something else, and on every unclaimed plot.
	DefaultDecor = {
		"hay_corner",
		"graveyard_corner",
		"graveyard_corner",
		"hay_corner",
		"pumpkin_pile",
		"pumpkin_pile",
	},
}
