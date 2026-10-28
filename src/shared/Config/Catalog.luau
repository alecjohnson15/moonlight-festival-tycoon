-- Robux items. The brief allows only directly purchased items whose contents
-- are stated up front: no random rewards, rerolls, timers or anything that
-- speeds up progression. Every item is a premium cosmetic in Config/Cosmetics
-- with the same id, and none changes coins or income.
--
-- The Legendary weapons are the one exception to "looks only": they are a
-- little stronger than the best earned weapon, inside the PvP arena only.
-- That was the project owner's call (2026-10-27); their edge lives in
-- Config/Weapons, so it can be tuned or removed in one place.
--
-- Kind:
--   GamePass          bought once; Roblox tracks ownership.
--   DeveloperProduct  granted through a receipt and recorded in the save.
--
-- An item with id 0 is not set up yet and cannot be bought. SuggestedRobux is
-- a starting point for the price set on the Roblox website, and needs a value
-- review like every other price.

return {
	-- Deluxe looks.
	{
		Id = "moonstone_mallet",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 99,
		Includes = "The Big Wooden Mallet carved from glowing moonstone. It swings and hits exactly like the wooden one.",
	},
	{
		Id = "bat_wings",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 129,
		Includes = "Glowing purple bat wings worn on your back.",
	},
	{
		Id = "ghostfire_crown",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 99,
		Includes = "A golden crown with green ghostfire burning on its points.",
	},
	{
		Id = "toxic_aura",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 99,
		Includes = "Green ghostfire that flickers all around you.",
	},
	{
		Id = "rainbow_trail",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 79,
		Includes = "A bright ribbon of colour that follows your feet.",
	},

	-- Brainrot Buddies: pets that follow you around.
	{
		Id = "pizza_bat",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Pipistrello Pizzetta, a pet that is half pizza slice and half bat.",
	},
	{
		Id = "gelato_ghost",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Fantasmino Gelatino, a pet ghost made of mint gelato in a waffle cone.",
	},
	{
		Id = "candle_buddy",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Candelino Wobblino, a pet candle with googly eyes and tiny feet.",
	},
	{
		Id = "zombie_zucchini",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Zucchino Zombino, a pet zombie zucchini with its arms out.",
	},

	-- Legendary arena weapons.
	{
		Id = "thunder_hammer",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 499,
		Includes = "The Storm-Stone Hammer. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income.",
	},
	{
		Id = "ghost_blade",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 499,
		Includes = "The Ghostlight Blade. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income.",
	},
	{
		Id = "reaper_scythe",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 499,
		Includes = "The Reaper's Scythe. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income.",
	},
	{
		Id = "drowned_trident",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 499,
		Includes = "The Drowned Trident. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income.",
	},
	{
		Id = "foxfire_fan",
		Kind = "GamePass",
		PassId = 0,
		SuggestedRobux = 499,
		Includes = "The Foxfire Fan. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income.",
	},
}
