-- Every cosmetic in the game. There are five kinds, one of each worn at a
-- time: the Phantom's Blade, the Guardian's Blaster (both only seen when a
-- round deals you that role), the Mask everyone wears to the party, the
-- Effect a knockout makes (the puff when your blade tags someone, or your
-- blaster zaps the Phantom) and the Trail behind you as you run.
--
-- Cosmetics only change looks. A blade tags and a blaster zaps exactly the
-- same in every skin (Config/Combat).
--
-- Where each comes from is decided elsewhere: Config/Shop (coins), Config/
-- Crates (opened with coins), Config/Pass (the Moon Pass) and Config/Catalog
-- (Robux). Items from crates and the coin shop can be traded; items from the
-- Moon Pass and from Robux purchases stay with the account that earned or
-- bought them.
--
-- Look holds what the builders in Look/ need: a Shape the builder knows and
-- colours as hex strings.

export type Item = {
	Id: string,
	Name: string,
	Kind: string,
	Rarity: string,
	Look: { [string]: any },
	-- Owned by everyone from the start.
	Default: boolean?,
	-- Can't be traded (Moon Pass and Robux items).
	Bound: boolean?,
	-- From a seasonal crate.
	Season: string?,
}

local Items = {}

Items.KINDS = { "Blade", "Blaster", "Mask", "Effect", "Trail" }

Items.KIND_NAMES = {
	Blade = "Phantom Blades",
	Blaster = "Guardian Blasters",
	Mask = "Masks",
	Effect = "Knockout Effects",
	Trail = "Trails",
}

Items.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Items.RARITY_COLORS = {
	Common = "#B8C0CC",
	Uncommon = "#6FDB7E",
	Rare = "#4DA3FF",
	Epic = "#B067FF",
	Legendary = "#FFC93D",
	Mythic = "#FF5EC4",
}

-- The item each kind starts with.
Items.DEFAULTS = {
	Blade = "blade_shadow",
	Blaster = "blaster_moonbeam",
	Mask = "mask_domino",
	Effect = "fx_poof",
	Trail = "trail_none",
}

local list: { Item } = {
	-- Phantom blades. Shapes: straight, curved, crystal, quill, cane, bone,
	-- umbrella, rose.
	{
		Id = "blade_shadow",
		Name = "Shadow Blade",
		Kind = "Blade",
		Rarity = "Common",
		Default = true,
		Look = { Shape = "straight", Blade = "#2B2838", Edge = "#9D7BFF", Hilt = "#1A1622", Guard = "#5B4A7A" },
	},
	{
		Id = "blade_umbrella",
		Name = "Brolly Blade",
		Kind = "Blade",
		Rarity = "Common",
		Look = { Shape = "umbrella", Blade = "#2E3A59", Edge = "#F2D16B", Hilt = "#6B4226", Guard = "#C9CED6" },
	},
	{
		Id = "blade_candy",
		Name = "Candy Cane Cutter",
		Kind = "Blade",
		Rarity = "Uncommon",
		Look = { Shape = "cane", Blade = "#F7F3EC", Edge = "#E63946", Hilt = "#E63946", Guard = "#7BD389" },
	},
	{
		Id = "blade_pumpkin",
		Name = "Pumpkin Carver",
		Kind = "Blade",
		Rarity = "Uncommon",
		Look = { Shape = "straight", Blade = "#FF8C1A", Edge = "#FFD27A", Hilt = "#3E7B35", Guard = "#2C5A26" },
	},
	{
		Id = "blade_bone",
		Name = "Funny Bone",
		Kind = "Blade",
		Rarity = "Rare",
		Look = { Shape = "bone", Blade = "#EDE6D3", Edge = "#FFFFFF", Hilt = "#B9A98A", Guard = "#D8CDB2" },
	},
	{
		Id = "blade_quill",
		Name = "Quill of Secrets",
		Kind = "Blade",
		Rarity = "Rare",
		Look = { Shape = "quill", Blade = "#F4F1FF", Edge = "#3A4BD8", Hilt = "#22244A", Guard = "#D4AF37" },
	},
	{
		Id = "blade_frost",
		Name = "Frostfang",
		Kind = "Blade",
		Rarity = "Rare",
		Look = {
			Shape = "crystal",
			Blade = "#9EE7FF",
			Edge = "#E8FBFF",
			Hilt = "#2D5B8A",
			Guard = "#BFEFFF",
			Glass = true,
		},
	},
	{
		Id = "blade_ember",
		Name = "Emberline",
		Kind = "Blade",
		Rarity = "Epic",
		Look = {
			Shape = "straight",
			Blade = "#FF6A1F",
			Edge = "#FFD166",
			Hilt = "#3A1C12",
			Guard = "#8C2F1B",
			Glow = "#FF7A2E",
			Fire = "#FF8C3A",
		},
	},
	{
		Id = "blade_slime",
		Name = "Slime Saber",
		Kind = "Blade",
		Rarity = "Epic",
		Look = {
			Shape = "straight",
			Blade = "#5CFF6E",
			Edge = "#C8FFCB",
			Hilt = "#2B2B2B",
			Guard = "#3FA34D",
			Glow = "#5CFF6E",
			Drip = "#7DFF8A",
		},
	},
	{
		Id = "blade_starshard",
		Name = "Starshard",
		Kind = "Blade",
		Rarity = "Legendary",
		Look = {
			Shape = "crystal",
			Blade = "#8B5CFF",
			Edge = "#F1E6FF",
			Hilt = "#1B1240",
			Guard = "#FFD86B",
			Glow = "#A07BFF",
			Sparkle = "#FFF1A8",
		},
	},
	{
		Id = "blade_crescent",
		Name = "Crescent Moonblade",
		Kind = "Blade",
		Rarity = "Legendary",
		Look = {
			Shape = "curved",
			Blade = "#DDE3F0",
			Edge = "#FFFFFF",
			Hilt = "#26223A",
			Guard = "#F5C451",
			Glow = "#BFD7FF",
			Sparkle = "#FFFFFF",
		},
	},
	{
		Id = "blade_royal",
		Name = "Royal Rapier",
		Kind = "Blade",
		Rarity = "Legendary",
		Bound = true,
		Look = {
			Shape = "straight",
			Blade = "#F2D27A",
			Edge = "#FFF6D6",
			Hilt = "#6E1630",
			Guard = "#F5C451",
			Thin = true,
		},
	},
	{
		Id = "blade_neon",
		Name = "Neon Nightmare",
		Kind = "Blade",
		Rarity = "Legendary",
		Bound = true,
		Look = {
			Shape = "straight",
			Blade = "#FF3FD1",
			Edge = "#3FF2FF",
			Hilt = "#141018",
			Guard = "#3FF2FF",
			Glow = "#FF3FD1",
		},
	},
	{
		Id = "blade_rose",
		Name = "Thorned Rose",
		Kind = "Blade",
		Rarity = "Epic",
		Bound = true,
		Look = { Shape = "rose", Blade = "#2F7A3A", Edge = "#D7263D", Hilt = "#1F4D26", Guard = "#D7263D" },
	},
	{
		Id = "blade_sickle",
		Name = "Scarecrow Sickle",
		Kind = "Blade",
		Rarity = "Epic",
		Season = "Harvest",
		Look = {
			Shape = "curved",
			Blade = "#B8B8B8",
			Edge = "#F2F2F2",
			Hilt = "#8A5A2B",
			Guard = "#D9A441",
			Small = true,
		},
	},
	{
		Id = "blade_eclipse",
		Name = "Eclipse Edge",
		Kind = "Blade",
		Rarity = "Mythic",
		Season = "Harvest",
		Look = {
			Shape = "curved",
			Blade = "#0E0B14",
			Edge = "#FFB830",
			Hilt = "#0E0B14",
			Guard = "#FFB830",
			Glow = "#FFB830",
			Sparkle = "#FFE29A",
			Fire = "#FF9F1C",
		},
	},
	{
		Id = "blade_gala",
		Name = "Midnight Gala Blade",
		Kind = "Blade",
		Rarity = "Mythic",
		Bound = true,
		Look = {
			Shape = "straight",
			Blade = "#1B1F4A",
			Edge = "#F5C451",
			Hilt = "#F5C451",
			Guard = "#F5C451",
			Glow = "#7E8CFF",
			Sparkle = "#FFE7A3",
		},
	},

	-- Guardian blasters. Shapes: ray, bulb, flare, lantern, popper. Beam is
	-- the colour of the shot.
	{
		Id = "blaster_moonbeam",
		Name = "Moonbeam Blaster",
		Kind = "Blaster",
		Rarity = "Common",
		Default = true,
		Look = { Shape = "ray", Body = "#D9DEE8", Trim = "#6C7A96", Beam = "#BFE3FF" },
	},
	{
		Id = "blaster_gumdrop",
		Name = "Gumdrop Zapper",
		Kind = "Blaster",
		Rarity = "Uncommon",
		Look = { Shape = "bulb", Body = "#FF8FC8", Trim = "#8FF0C8", Beam = "#FF8FC8" },
	},
	{
		Id = "blaster_bubble",
		Name = "Bubble Popper",
		Kind = "Blaster",
		Rarity = "Uncommon",
		Look = { Shape = "bulb", Body = "#4FC3F7", Trim = "#FFFFFF", Beam = "#7FE7FF", Glass = true },
	},
	{
		Id = "blaster_retro",
		Name = "Retro Raygun",
		Kind = "Blaster",
		Rarity = "Rare",
		Look = { Shape = "ray", Body = "#D62828", Trim = "#E0E0E0", Beam = "#FF4D4D", Metal = true },
	},
	{
		Id = "blaster_lantern",
		Name = "Lantern Caster",
		Kind = "Blaster",
		Rarity = "Rare",
		Look = { Shape = "lantern", Body = "#B5843A", Trim = "#4A3520", Beam = "#FFD27A" },
	},
	{
		Id = "blaster_snow",
		Name = "Snowflake Zapper",
		Kind = "Blaster",
		Rarity = "Rare",
		Look = { Shape = "flare", Body = "#F2FAFF", Trim = "#8ED1FC", Beam = "#CFF4FF" },
	},
	{
		Id = "blaster_firefly",
		Name = "Firefly Flare",
		Kind = "Blaster",
		Rarity = "Epic",
		Look = { Shape = "lantern", Body = "#2F4F2F", Trim = "#C9E265", Beam = "#D8FF5C", Glow = "#D8FF5C" },
	},
	{
		Id = "blaster_nebula",
		Name = "Nebula Ray",
		Kind = "Blaster",
		Rarity = "Legendary",
		Look = {
			Shape = "ray",
			Body = "#3A1F6E",
			Trim = "#FF6AD5",
			Beam = "#FF6AD5",
			Glow = "#B57BFF",
			Sparkle = "#FFE3FF",
		},
	},
	{
		Id = "blaster_starfall",
		Name = "Starfall Blaster",
		Kind = "Blaster",
		Rarity = "Legendary",
		Bound = true,
		Look = {
			Shape = "flare",
			Body = "#1C2541",
			Trim = "#F5C451",
			Beam = "#FFE08A",
			Glow = "#FFE08A",
			Sparkle = "#FFF6D5",
		},
	},
	{
		Id = "blaster_gilded",
		Name = "Gilded Lantern Blaster",
		Kind = "Blaster",
		Rarity = "Legendary",
		Bound = true,
		Look = {
			Shape = "lantern",
			Body = "#F5C451",
			Trim = "#6E1630",
			Beam = "#FFF2C2",
			Glow = "#FFE7A3",
			Metal = true,
		},
	},
	{
		Id = "blaster_music",
		Name = "Music Box Blaster",
		Kind = "Blaster",
		Rarity = "Epic",
		Bound = true,
		Look = { Shape = "bulb", Body = "#7A2E4A", Trim = "#F5C451", Beam = "#FFB3D9" },
	},
	{
		Id = "blaster_chandelier",
		Name = "Chandelier Blaster",
		Kind = "Blaster",
		Rarity = "Legendary",
		Bound = true,
		Look = {
			Shape = "lantern",
			Body = "#E8D9A8",
			Trim = "#BDE8FF",
			Beam = "#FFFFFF",
			Glow = "#FFF4D6",
			Glass = true,
		},
	},
	{
		Id = "blaster_popcorn",
		Name = "Corn Popper",
		Kind = "Blaster",
		Rarity = "Epic",
		Season = "Harvest",
		Look = { Shape = "popper", Body = "#E63946", Trim = "#FFFFFF", Beam = "#FFE066" },
	},
	{
		Id = "blaster_sunburst",
		Name = "Sunburst Ray",
		Kind = "Blaster",
		Rarity = "Mythic",
		Season = "Harvest",
		Look = {
			Shape = "flare",
			Body = "#FF9F1C",
			Trim = "#FFE29A",
			Beam = "#FFC94D",
			Glow = "#FFB627",
			Sparkle = "#FFF3B0",
		},
	},
	{
		Id = "blaster_paper",
		Name = "Origami Blaster",
		Kind = "Blaster",
		Rarity = "Rare",
		Bound = true,
		Look = { Shape = "ray", Body = "#F4EBDD", Trim = "#C44536", Beam = "#FFF8E7", Paper = true },
	},

	-- Masks, worn over the eyes by everyone at the party. Shapes: domino,
	-- feather, cat, fox, moon, skull, butterfly, jester, sun, ghost, sack,
	-- visor, half, peacock, lantern, paper.
	{
		Id = "mask_domino",
		Name = "Domino Mask",
		Kind = "Mask",
		Rarity = "Common",
		Default = true,
		Look = { Shape = "domino", Base = "#1E1B26", Trim = "#F5C451" },
	},
	{
		Id = "mask_velvet",
		Name = "Velvet Domino",
		Kind = "Mask",
		Rarity = "Common",
		Look = { Shape = "domino", Base = "#8C1C3A", Trim = "#F2D27A" },
	},
	{
		Id = "mask_feather",
		Name = "Feathered Mask",
		Kind = "Mask",
		Rarity = "Uncommon",
		Look = { Shape = "feather", Base = "#127475", Trim = "#F5DF4D", Feather = "#0E9AA7" },
	},
	{
		Id = "mask_cat",
		Name = "Midnight Cat",
		Kind = "Mask",
		Rarity = "Uncommon",
		Look = { Shape = "cat", Base = "#15121C", Trim = "#3A3348", Glow = "#7CFF6B" },
	},
	{
		Id = "mask_fox",
		Name = "Kitsune Fox",
		Kind = "Mask",
		Rarity = "Rare",
		Look = { Shape = "fox", Base = "#F7F4EE", Trim = "#D62828", Glow = "#FF6B6B" },
	},
	{
		Id = "mask_moon",
		Name = "Moon Mask",
		Kind = "Mask",
		Rarity = "Rare",
		Look = { Shape = "moon", Base = "#D9DFEA", Trim = "#8FA3C7", Glow = "#E9F1FF" },
	},
	{
		Id = "mask_skull",
		Name = "Candy Skull",
		Kind = "Mask",
		Rarity = "Epic",
		Look = { Shape = "skull", Base = "#F5F2EA", Trim = "#FF5DA2", Flower = "#FFB627", Glow = "#5CE1E6" },
	},
	{
		Id = "mask_butterfly",
		Name = "Monarch Mask",
		Kind = "Mask",
		Rarity = "Epic",
		Look = { Shape = "butterfly", Base = "#FF8C1A", Trim = "#1A1A1A", Glow = "#FFE0A3" },
	},
	{
		Id = "mask_jester",
		Name = "Jester's Grin",
		Kind = "Mask",
		Rarity = "Legendary",
		Look = { Shape = "jester", Base = "#F4F1EA", Trim = "#7B2CBF", Bells = "#F5C451", Second = "#2EC4B6" },
	},
	{
		Id = "mask_ghost",
		Name = "Ghost Veil",
		Kind = "Mask",
		Rarity = "Legendary",
		Look = { Shape = "ghost", Base = "#F4F8FF", Trim = "#A9C6FF", Glow = "#CFE0FF" },
	},
	{
		Id = "mask_starlight",
		Name = "Starlight Visor",
		Kind = "Mask",
		Rarity = "Mythic",
		Look = { Shape = "visor", Base = "#12143A", Trim = "#C9B6FF", Glow = "#9EE6FF", Sparkle = "#FFFFFF" },
	},
	{
		Id = "mask_sun",
		Name = "Golden Sun Mask",
		Kind = "Mask",
		Rarity = "Legendary",
		Bound = true,
		Look = { Shape = "sun", Base = "#F5C451", Trim = "#FF9F1C", Glow = "#FFE7A3" },
	},
	{
		Id = "mask_gala",
		Name = "Gala Half-Mask",
		Kind = "Mask",
		Rarity = "Rare",
		Bound = true,
		Look = { Shape = "half", Base = "#F7F7F2", Trim = "#C9A227" },
	},
	{
		Id = "mask_peacock",
		Name = "Peacock Mask",
		Kind = "Mask",
		Rarity = "Legendary",
		Bound = true,
		Look = { Shape = "feather", Base = "#0B6E4F", Trim = "#F5C451", Feather = "#1F7AE0", Glow = "#3DDC97" },
	},
	{
		Id = "mask_paper",
		Name = "Paper Lantern Mask",
		Kind = "Mask",
		Rarity = "Uncommon",
		Bound = true,
		Look = { Shape = "paper", Base = "#F9E2AE", Trim = "#C44536", Glow = "#FFD27A" },
	},
	{
		Id = "mask_scarecrow",
		Name = "Scarecrow Sack",
		Kind = "Mask",
		Rarity = "Rare",
		Season = "Harvest",
		Look = { Shape = "sack", Base = "#C9A66B", Trim = "#4A3520", Straw = "#E9C46A" },
	},
	{
		Id = "mask_lantern",
		Name = "Jack-o'-Lantern Mask",
		Kind = "Mask",
		Rarity = "Legendary",
		Season = "Harvest",
		Look = { Shape = "lantern", Base = "#FF7B00", Trim = "#3E7B35", Glow = "#FFD000" },
	},

	-- Knockout effects. Styles: smoke, confetti, bubbles, bats, leaves,
	-- stars, ghosts, gold, supernova, sparkle, petals.
	{
		Id = "fx_poof",
		Name = "Puff of Smoke",
		Kind = "Effect",
		Rarity = "Common",
		Default = true,
		Look = { Style = "smoke", Colors = { "#D8D2E8", "#8C82A8" } },
	},
	{
		Id = "fx_confetti",
		Name = "Confetti Pop",
		Kind = "Effect",
		Rarity = "Uncommon",
		Look = { Style = "confetti", Colors = { "#FF5D8F", "#FFD23F", "#3BCEAC", "#5D9CEC" } },
	},
	{
		Id = "fx_bubbles",
		Name = "Bubble Burst",
		Kind = "Effect",
		Rarity = "Uncommon",
		Look = { Style = "bubbles", Colors = { "#9BF6FF", "#FFFFFF" } },
	},
	{
		Id = "fx_bats",
		Name = "Bat Burst",
		Kind = "Effect",
		Rarity = "Rare",
		Look = { Style = "bats", Colors = { "#2A2238", "#B067FF" } },
	},
	{
		Id = "fx_stars",
		Name = "Seeing Stars",
		Kind = "Effect",
		Rarity = "Epic",
		Look = { Style = "stars", Colors = { "#FFE66D", "#FFFFFF" } },
	},
	{
		Id = "fx_ghosts",
		Name = "Ghost Parade",
		Kind = "Effect",
		Rarity = "Legendary",
		Look = { Style = "ghosts", Colors = { "#F4F8FF", "#A9C6FF" } },
	},
	{
		Id = "fx_supernova",
		Name = "Supernova",
		Kind = "Effect",
		Rarity = "Mythic",
		Look = { Style = "supernova", Colors = { "#FFFFFF", "#FF5EC4", "#7B5CFF" } },
	},
	{
		Id = "fx_gold",
		Name = "Golden Confetti",
		Kind = "Effect",
		Rarity = "Legendary",
		Bound = true,
		Look = { Style = "confetti", Colors = { "#F5C451", "#FFF1B8", "#E0A526" } },
	},
	{
		Id = "fx_sparkle",
		Name = "Sparkle Pop",
		Kind = "Effect",
		Rarity = "Uncommon",
		Bound = true,
		Look = { Style = "sparkle", Colors = { "#FFF6B0", "#FFFFFF" } },
	},
	{
		Id = "fx_petals",
		Name = "Rose Petals",
		Kind = "Effect",
		Rarity = "Epic",
		Bound = true,
		Look = { Style = "petals", Colors = { "#D7263D", "#FF7096" } },
	},
	{
		Id = "fx_leaves",
		Name = "Autumn Swirl",
		Kind = "Effect",
		Rarity = "Rare",
		Season = "Harvest",
		Look = { Style = "leaves", Colors = { "#E76F51", "#F4A261", "#E9C46A" } },
	},

	-- Trails. A trail with no colours is no trail at all.
	{
		Id = "trail_none",
		Name = "No Trail",
		Kind = "Trail",
		Rarity = "Common",
		Default = true,
		Look = { Colors = {} },
	},
	{
		Id = "trail_mist",
		Name = "Moonmist",
		Kind = "Trail",
		Rarity = "Common",
		Look = { Colors = { "#C9D6FF", "#E2E2E2" }, Light = 0.2 },
	},
	{
		Id = "trail_candy",
		Name = "Candy Stripe",
		Kind = "Trail",
		Rarity = "Uncommon",
		Look = { Colors = { "#FF4D6D", "#FFFFFF", "#FF4D6D" }, Light = 0.3 },
	},
	{
		Id = "trail_stardust",
		Name = "Stardust",
		Kind = "Trail",
		Rarity = "Epic",
		Look = { Colors = { "#FFE66D", "#B067FF" }, Light = 0.8, Sparkle = "#FFFFFF" },
	},
	{
		Id = "trail_prism",
		Name = "Prism",
		Kind = "Trail",
		Rarity = "Legendary",
		Look = { Colors = { "#FF5D5D", "#FFD23F", "#3BCEAC", "#5D9CEC", "#B067FF" }, Light = 1 },
	},
	{
		Id = "trail_ghostfire",
		Name = "Ghostfire",
		Kind = "Trail",
		Rarity = "Legendary",
		Bound = true,
		Look = { Colors = { "#7CFF6B", "#1E8C3A" }, Light = 1, Sparkle = "#C8FFB8" },
	},
	{
		Id = "trail_moonbeam",
		Name = "Moonbeam",
		Kind = "Trail",
		Rarity = "Epic",
		Bound = true,
		Look = { Colors = { "#E9F1FF", "#7FA7FF" }, Light = 1 },
	},
	{
		Id = "trail_velvet",
		Name = "Velvet Ribbon",
		Kind = "Trail",
		Rarity = "Rare",
		Bound = true,
		Look = { Colors = { "#8C1C3A", "#D7263D" }, Light = 0.1 },
	},
	{
		Id = "trail_aurora",
		Name = "Aurora",
		Kind = "Trail",
		Rarity = "Legendary",
		Bound = true,
		Look = { Colors = { "#3DDC97", "#46B1FF", "#B067FF" }, Light = 1, Sparkle = "#E6FFF5" },
	},
	{
		Id = "trail_leaves",
		Name = "Falling Leaves",
		Kind = "Trail",
		Rarity = "Rare",
		Season = "Harvest",
		Look = { Colors = { "#E76F51", "#E9C46A" }, Light = 0.2 },
	},
	{
		Id = "trail_will",
		Name = "Will-o'-Wisp",
		Kind = "Trail",
		Rarity = "Legendary",
		Season = "Harvest",
		Look = { Colors = { "#9EF0FF", "#2E86AB" }, Light = 1, Sparkle = "#E0FBFF" },
	},
}

Items.List = list

Items.byId = {} :: { [string]: Item }
for _, item in list do
	Items.byId[item.Id] = item
end

function Items.get(id: string): Item?
	return Items.byId[id]
end

-- Whether players may trade the item.
function Items.tradeable(id: string): boolean
	local item = Items.byId[id]
	return item ~= nil and not item.Default and not item.Bound
end

-- Where a rarity sits, 1 (Common) to 6 (Mythic).
function Items.rank(rarity: string): number
	return table.find(Items.RARITIES, rarity) or 0
end

return Items
