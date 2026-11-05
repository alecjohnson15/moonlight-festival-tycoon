-- What's sold for Robux. Every entry is a game pass with its contents
-- stated: fixed cosmetics, the Moon Pass's premium track, the VIP lounge or
-- extra emotes. Nothing here gives coins, crates or an edge in a round.
--
-- PassId 0 means the pass hasn't been made on Roblox yet; the shop shows it
-- as coming soon and never prompts. docs/launch.md says how to make them and
-- tools/passes.json lists them for the Open Cloud script.

export type Product = {
	Id: string,
	Kind: string,
	Name: string,
	Description: string,
	Price: number,
	PassId: number,
	-- Items the pass gives.
	Items: { string },
	-- Not an item: "MoonPass", "VIP" or "Emotes".
	Perk: string?,
}

local Catalog = {
	{
		Id = "moon_pass",
		Kind = "GamePass",
		Name = "Moon Pass Premium",
		Description = "Unlocks the premium track of the Moon Pass: nine exclusive cosmetics, "
			.. "including the Midnight Gala Blade at tier 30. Tiers you've already reached unlock at once.",
		Price = 399,
		PassId = 0,
		Items = {},
		Perk = "MoonPass",
	},
	{
		Id = "royal_set",
		Kind = "GamePass",
		Name = "Royal Masquerade Set",
		Description = "The Royal Rapier blade, the Gilded Lantern Blaster and the Golden Confetti knockout effect.",
		Price = 249,
		PassId = 0,
		Items = { "blade_royal", "blaster_gilded", "fx_gold" },
	},
	{
		Id = "neon_blade",
		Kind = "GamePass",
		Name = "Neon Nightmare Blade",
		Description = "A glowing pink and cyan Phantom blade. Looks only: it tags like every other blade.",
		Price = 149,
		PassId = 0,
		Items = { "blade_neon" },
	},
	{
		Id = "starfall_blaster",
		Kind = "GamePass",
		Name = "Starfall Blaster",
		Description = "A navy and gold Guardian blaster that fires a golden beam. Looks only.",
		Price = 149,
		PassId = 0,
		Items = { "blaster_starfall" },
	},
	{
		Id = "sun_mask",
		Kind = "GamePass",
		Name = "Golden Sun Mask",
		Description = "A shining golden sun mask with glowing rays.",
		Price = 99,
		PassId = 0,
		Items = { "mask_sun" },
	},
	{
		Id = "ghostfire_trail",
		Kind = "GamePass",
		Name = "Ghostfire Trail",
		Description = "A trail of green ghostfire that follows you as you run.",
		Price = 99,
		PassId = 0,
		Items = { "trail_ghostfire" },
	},
	{
		Id = "vip",
		Kind = "GamePass",
		Name = "VIP Lounge",
		Description = "Entry to the VIP lounge on the plaza's balcony, a gold VIP tag in chat and a gold name "
			.. "over your head in the lobby.",
		Price = 199,
		PassId = 0,
		Items = {},
		Perk = "VIP",
	},
	{
		Id = "party_emotes",
		Kind = "GamePass",
		Name = "Party Emotes",
		Description = "Five extra emotes for the lobby and rounds: Spotlight, Confetti Cannon, Vanish, Levitate and Applause. Looks only.",
		Price = 99,
		PassId = 0,
		Items = {},
		Perk = "Emotes",
	},
} :: { Product }

return Catalog
