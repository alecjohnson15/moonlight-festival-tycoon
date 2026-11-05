-- Crates, opened with coins earned by playing. Each crate lists its odds by
-- rarity and every item it can hold, and the game shows both before you
-- open one. Within a rarity, each item is equally likely.
--
-- Crates are never sold for Robux, coins are never sold for Robux, and
-- nothing bought with Robux gives coins or crates, so no real money ever
-- buys a random item.

export type Crate = {
	Id: string,
	Name: string,
	Price: number,
	-- Rarity name to its weight, out of 100.
	Odds: { [string]: number },
	-- Rarity name to the items of that rarity the crate holds.
	Pools: { [string]: { string } },
	Color: string,
	-- A seasonal crate, shown with its season's name.
	Season: string?,
	-- After this many opens without an item of PityRarity or better, the
	-- next open is guaranteed one.
	Pity: number,
	PityRarity: string,
}

local Crates = {}

Crates.List = {
	{
		Id = "masquerade",
		Name = "Masquerade Crate",
		Price = 600,
		Color = "#B067FF",
		Odds = { Uncommon = 54, Rare = 30, Epic = 11, Legendary = 4, Mythic = 1 },
		Pools = {
			Uncommon = { "blade_candy", "blade_pumpkin", "blaster_bubble", "mask_feather", "fx_bubbles", "trail_candy" },
			Rare = {
				"blade_bone",
				"blade_quill",
				"blade_frost",
				"blaster_retro",
				"blaster_lantern",
				"blaster_snow",
				"mask_fox",
				"mask_moon",
				"fx_bats",
			},
			Epic = {
				"blade_ember",
				"blade_slime",
				"blaster_firefly",
				"mask_skull",
				"mask_butterfly",
				"fx_stars",
				"trail_stardust",
			},
			Legendary = {
				"blade_starshard",
				"blade_crescent",
				"blaster_nebula",
				"mask_jester",
				"mask_ghost",
				"fx_ghosts",
				"trail_prism",
			},
			Mythic = { "mask_starlight", "fx_supernova" },
		},
		Pity = 10,
		PityRarity = "Epic",
	},
	{
		Id = "harvest",
		Name = "Harvest Moon Crate",
		Season = "Harvest Moon",
		Price = 900,
		Color = "#FF8C1A",
		Odds = { Rare = 50, Epic = 33, Legendary = 14, Mythic = 3 },
		Pools = {
			Rare = { "mask_scarecrow", "fx_leaves", "trail_leaves" },
			Epic = { "blade_sickle", "blaster_popcorn" },
			Legendary = { "mask_lantern", "trail_will" },
			Mythic = { "blade_eclipse", "blaster_sunburst" },
		},
		Pity = 8,
		PityRarity = "Legendary",
	},
} :: { Crate }

function Crates.get(id: string): Crate?
	for _, crate in Crates.List do
		if crate.Id == id then
			return crate
		end
	end
	return nil
end

return Crates
