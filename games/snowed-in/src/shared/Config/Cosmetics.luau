--!strict
-- Things players wear (Hat, Back, Trail) or walk with (Pet), and the
-- decorations for their cabin by the hearth (Config/Decor). None of them
-- changes how a run plays. They are saved, so they come along to every run.
--
-- Source says how an item is unlocked, and the game shows it on the item
-- before anyone tries to get it:
--   Shop      bought with snowflakes earned by playing (Price).
--   Pass      the game pass with the same id in Config/Catalog.
--   Tier      a reward on the Expedition Pass track (Config/Expedition).
--   Trophy    earned by doing something in a run (Trophy names it).
--   Starter   everyone has it.

export type Cosmetic = {
	Id: string,
	Name: string,
	Slot: "Hat" | "Back" | "Trail" | "Pet",
	Source: "Shop" | "Pass" | "Tier" | "Trophy" | "Starter",
	Price: number?,
	Trophy: string?,
	Blurb: string,
	Color: string,
}

local Cosmetics = {}

Cosmetics.Slots = { "Hat", "Back", "Trail", "Pet" }

Cosmetics.List = {
	-- Hats.
	{
		Id = "BobbleHat",
		Name = "Bobble Hat",
		Slot = "Hat",
		Source = "Shop",
		Price = 80,
		Blurb = "A knitted hat with a fluffy bobble.",
		Color = "#E5484D",
	},
	{
		Id = "Earmuffs",
		Name = "Fluffy Earmuffs",
		Slot = "Hat",
		Source = "Shop",
		Price = 60,
		Blurb = "Keeps the wind out of your ears.",
		Color = "#F2A7C3",
	},
	{
		Id = "MinerHelmet",
		Name = "Lamp Helmet",
		Slot = "Hat",
		Source = "Tier",
		Blurb = "A hard hat with a lamp that really glows.",
		Color = "#F5C542",
	},
	{
		Id = "AntlerBeanie",
		Name = "Antler Beanie",
		Slot = "Hat",
		Source = "Tier",
		Blurb = "A beanie with two soft antlers.",
		Color = "#8B5A3C",
	},
	{
		Id = "PolarBearHat",
		Name = "Polar Bear Hat",
		Slot = "Hat",
		Source = "Tier",
		Blurb = "A cosy bear face with round ears.",
		Color = "#F4F7FB",
	},
	{
		Id = "YetiHood",
		Name = "Yeti Hood",
		Slot = "Hat",
		Source = "Trophy",
		Trophy = "Yeti",
		Blurb = "Proof you beat the Old Yeti on night 5.",
		Color = "#DDE7F2",
	},
	{
		Id = "IcicleCrown",
		Name = "Icicle Crown",
		Slot = "Hat",
		Source = "Pass",
		Blurb = "A crown of glowing icicles.",
		Color = "#8FE3FF",
	},

	-- Backs.
	{
		Id = "Snowboard",
		Name = "Snowboard",
		Slot = "Back",
		Source = "Shop",
		Price = 150,
		Blurb = "A striped snowboard on your back.",
		Color = "#3D7BFF",
	},
	{
		Id = "LanternPack",
		Name = "Lantern Pack",
		Slot = "Back",
		Source = "Tier",
		Blurb = "A backpack with a little lantern swinging from it.",
		Color = "#C07A3A",
	},
	{
		Id = "FrostWings",
		Name = "Frost Wings",
		Slot = "Back",
		Source = "Tier",
		Blurb = "Wings of frosted glass.",
		Color = "#BFEFFF",
	},
	{
		Id = "AuroraCape",
		Name = "Aurora Cape",
		Slot = "Back",
		Source = "Pass",
		Blurb = "A cape that shimmers green and purple like the northern lights.",
		Color = "#5CF2B0",
	},

	-- Trails.
	{
		Id = "SnowflakeTrail",
		Name = "Snowflake Trail",
		Slot = "Trail",
		Source = "Shop",
		Price = 120,
		Blurb = "A ribbon of white that follows your feet.",
		Color = "#FFFFFF",
	},
	{
		Id = "EmberTrail",
		Name = "Ember Trail",
		Slot = "Trail",
		Source = "Tier",
		Blurb = "Warm orange sparks behind you.",
		Color = "#FF8A3D",
	},
	{
		Id = "SparkleTrail",
		Name = "Starlight Trail",
		Slot = "Trail",
		Source = "Tier",
		Blurb = "A trail of gold and pale blue.",
		Color = "#FFE58A",
	},
	{
		Id = "AuroraTrail",
		Name = "Aurora Trail",
		Slot = "Trail",
		Source = "Pass",
		Blurb = "The northern lights, following you around.",
		Color = "#7C5CFF",
	},

	-- Pets.
	{
		Id = "HuskyPup",
		Name = "Rescue Pup",
		Slot = "Pet",
		Source = "Trophy",
		Trophy = "Rescue",
		Blurb = "The train crew's pup, for everyone who gets rescued.",
		Color = "#9AA6B8",
	},
	{
		Id = "SnowOwl",
		Name = "Snow Owl",
		Slot = "Pet",
		Source = "Tier",
		Blurb = "A round white owl that flies at your shoulder.",
		Color = "#F4F4F4",
	},
	{
		Id = "Penguin",
		Name = "Penguin Buddy",
		Slot = "Pet",
		Source = "Pass",
		Blurb = "A waddling penguin in a tiny scarf.",
		Color = "#2B2F3A",
	},
	{
		Id = "ArcticFox",
		Name = "Arctic Fox Buddy",
		Slot = "Pet",
		Source = "Pass",
		Blurb = "A fluffy white fox with a big tail.",
		Color = "#F6F8FC",
	},
} :: { Cosmetic }

Cosmetics.ById = {} :: { [string]: Cosmetic }
for _, item in Cosmetics.List do
	Cosmetics.ById[item.Id] = item
end

return Cosmetics
