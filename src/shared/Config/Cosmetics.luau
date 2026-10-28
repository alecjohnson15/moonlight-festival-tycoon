-- Everything a player can wear, hold or have follow them, so others can see
-- how far they have got. Ids are theme-neutral; names, looks and blurbs come
-- from the active theme pack (Theme.Cosmetics and the pack's Wearables).
--
-- Slots (one item each): Head, Back, Hand (held as a Tool), Pet, Aura, Trail.
--
-- Free items are earned by building. Unlock is one or more of:
--   Owns = id                   owns that upgrade
--   OwnsAll = { ids }           owns all of them
--   OwnedCount = n              owns at least n upgrades
--   Building = id, Path = name  owns every upgrade on that path of that
--                               building's tree (see Config/Balance)
--
-- Premium items are bought with Robux: each has a Catalog entry with the same
-- id. Nothing here changes coins or income.
--
-- Weapon, on a Hand item, names its entry in Config/Weapons, which holds what
-- it does in the PvP arena. Items that share a Weapon fight the same, so a
-- paid look of a free weapon is no stronger. Legendary weapons are the only
-- paid items with an edge, and only in the arena.
--
-- Line groups items in the wardrobe: Earned, Deluxe (paid looks), Brainrot
-- (paid pets) and Legendary (paid arena weapons).

return {
	-- Earned, roughly one per upgrade in the order players buy them.
	{ Id = "lantern", Slot = "Hand", Line = "Earned", Unlock = { Owns = "starter_stall" } },
	{ Id = "witch_cape", Slot = "Back", Line = "Earned", Unlock = { Owns = "stall_counter" } },
	{ Id = "pumpkin_head", Slot = "Head", Line = "Earned", Unlock = { Owns = "grower" } },
	{ Id = "wooden_mallet", Slot = "Hand", Line = "Earned", Weapon = "mallet", Unlock = { Owns = "kitchen" } },
	{ Id = "ember_trail", Slot = "Trail", Line = "Earned", Unlock = { Owns = "grower_boost" } },
	{ Id = "witch_broom", Slot = "Hand", Line = "Earned", Weapon = "broom", Unlock = { Owns = "kitchen_boost" } },
	{ Id = "pumpkling", Slot = "Pet", Line = "Earned", Unlock = { Owns = "attraction_1" } },
	{ Id = "werewolf_claws", Slot = "Hand", Line = "Earned", Weapon = "claws", Unlock = { Owns = "attraction_2" } },
	{ Id = "phantom_aura", Slot = "Aura", Line = "Earned", Unlock = { Owns = "attraction_3" } },
	-- The best weapon anyone can earn, for building the whole festival.
	{ Id = "moon_saber", Slot = "Hand", Line = "Earned", Weapon = "moon_saber", Unlock = { OwnedCount = 9 } },

	-- Paid looks.
	{ Id = "moonstone_mallet", Slot = "Hand", Line = "Deluxe", Weapon = "mallet", Premium = true },
	{ Id = "bat_wings", Slot = "Back", Line = "Deluxe", Premium = true },
	{ Id = "ghostfire_crown", Slot = "Head", Line = "Deluxe", Premium = true },
	{ Id = "toxic_aura", Slot = "Aura", Line = "Deluxe", Premium = true },
	{ Id = "rainbow_trail", Slot = "Trail", Line = "Deluxe", Premium = true },

	-- Paid pets: original nonsense characters in the style of the
	-- "brainrot" meme trend. None of them is an existing meme character.
	{ Id = "pizza_bat", Slot = "Pet", Line = "Brainrot", Premium = true },
	{ Id = "gelato_ghost", Slot = "Pet", Line = "Brainrot", Premium = true },
	{ Id = "candle_buddy", Slot = "Pet", Line = "Brainrot", Premium = true },
	{ Id = "zombie_zucchini", Slot = "Pet", Line = "Brainrot", Premium = true },

	-- Paid arena weapons, a little stronger than the best earned one.
	{ Id = "thunder_hammer", Slot = "Hand", Line = "Legendary", Weapon = "thunder_hammer", Premium = true },
	{ Id = "ghost_blade", Slot = "Hand", Line = "Legendary", Weapon = "ghost_blade", Premium = true },
	{ Id = "reaper_scythe", Slot = "Hand", Line = "Legendary", Weapon = "reaper_scythe", Premium = true },
	{ Id = "drowned_trident", Slot = "Hand", Line = "Legendary", Weapon = "trident", Premium = true },
	{ Id = "foxfire_fan", Slot = "Hand", Line = "Legendary", Weapon = "foxfire_fan", Premium = true },
}
