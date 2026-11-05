--!strict
-- Decorations for each player's cabin by the hearth. Every player gets a
-- cabin when they join a run, and it wears the decorations they chose, from
-- run to run: this is the base that stays theirs between runs. Each cabin
-- has one spot of each kind in Spots, and a spot shows one decoration.
--
-- Sources work like Config/Cosmetics. An item with Source "Pack" comes with
-- the Cozy Cabin game pass (Config/Catalog).

export type Decor = {
	Id: string,
	Name: string,
	Spot: string,
	Source: "Starter" | "Shop" | "Tier" | "Trophy" | "Pack",
	Price: number?,
	Trophy: string?,
	Blurb: string,
	Color: string,
}

local Decor = {}

Decor.Spots = { "Roof", "Door", "Porch", "Yard", "Flag", "Window" }

Decor.SpotNames = {
	Roof = "Roof",
	Door = "Door",
	Porch = "Porch light",
	Yard = "Front yard",
	Flag = "Flag",
	Window = "Window glow",
}

Decor.List = {
	-- Roof.
	{
		Id = "PlainRoof",
		Name = "Snowy Roof",
		Spot = "Roof",
		Source = "Starter",
		Blurb = "Just snow.",
		Color = "#FFFFFF",
	},
	{
		Id = "StringLights",
		Name = "String Lights",
		Spot = "Roof",
		Source = "Shop",
		Price = 70,
		Blurb = "Warm bulbs along the roof.",
		Color = "#FFC46B",
	},
	{
		Id = "IcicleLights",
		Name = "Icicle Lights",
		Spot = "Roof",
		Source = "Shop",
		Price = 110,
		Blurb = "Blue lights that drip like icicles.",
		Color = "#8FD8FF",
	},
	{
		Id = "RoofStar",
		Name = "Roof Star",
		Spot = "Roof",
		Source = "Tier",
		Blurb = "A big glowing star on top.",
		Color = "#FFE14D",
	},
	{
		Id = "AuroraLights",
		Name = "Aurora Lights",
		Spot = "Roof",
		Source = "Pack",
		Blurb = "Lights that shift green to purple.",
		Color = "#6CF5C2",
	},

	-- Door.
	{
		Id = "NoWreath",
		Name = "Bare Door",
		Spot = "Door",
		Source = "Starter",
		Blurb = "A plain wooden door.",
		Color = "#7A5235",
	},
	{
		Id = "PineWreath",
		Name = "Pine Wreath",
		Spot = "Door",
		Source = "Shop",
		Price = 50,
		Blurb = "A green wreath with a red bow.",
		Color = "#2F8F4E",
	},
	{
		Id = "BerryWreath",
		Name = "Frostberry Wreath",
		Spot = "Door",
		Source = "Tier",
		Blurb = "A wreath studded with purple frostberries.",
		Color = "#7E6CF0",
	},
	{
		Id = "GoldWreath",
		Name = "Golden Wreath",
		Spot = "Door",
		Source = "Pack",
		Blurb = "A gold wreath that catches the firelight.",
		Color = "#F2C94C",
	},

	-- Porch light.
	{
		Id = "OilLamp",
		Name = "Oil Lamp",
		Spot = "Porch",
		Source = "Starter",
		Blurb = "A small warm lamp by the door.",
		Color = "#FFB85C",
	},
	{
		Id = "SnowflakeLantern",
		Name = "Snowflake Lantern",
		Spot = "Porch",
		Source = "Shop",
		Price = 80,
		Blurb = "A blue lantern with a snowflake inside.",
		Color = "#7CD3FF",
	},
	{
		Id = "EmberBrazier",
		Name = "Ember Brazier",
		Spot = "Porch",
		Source = "Tier",
		Blurb = "A little iron fire bowl.",
		Color = "#FF7A2E",
	},

	-- Front yard.
	{
		Id = "EmptyYard",
		Name = "Fresh Snow",
		Spot = "Yard",
		Source = "Starter",
		Blurb = "Untouched snow.",
		Color = "#FFFFFF",
	},
	{
		Id = "Snowman",
		Name = "Snowman",
		Spot = "Yard",
		Source = "Shop",
		Price = 100,
		Blurb = "Coal eyes, carrot nose, stick arms.",
		Color = "#F7F9FC",
	},
	{
		Id = "Sled",
		Name = "Red Sled",
		Spot = "Yard",
		Source = "Shop",
		Price = 90,
		Blurb = "A wooden sled with red runners.",
		Color = "#D93A3A",
	},
	{
		Id = "IceSculpture",
		Name = "Ice Swan",
		Spot = "Yard",
		Source = "Tier",
		Blurb = "A swan carved from clear ice.",
		Color = "#BFEFFF",
	},
	{
		Id = "PenguinStatue",
		Name = "Penguin Statue",
		Spot = "Yard",
		Source = "Tier",
		Blurb = "A stone penguin in a stone scarf.",
		Color = "#2B2F3A",
	},
	{
		Id = "YetiTrophy",
		Name = "Yeti Footprint",
		Spot = "Yard",
		Source = "Trophy",
		Trophy = "Yeti",
		Blurb = "A giant footprint cast in ice, from the night you beat the Old Yeti.",
		Color = "#DDE7F2",
	},
	{
		Id = "SnowGlobe",
		Name = "Giant Snow Globe",
		Spot = "Yard",
		Source = "Pack",
		Blurb = "A snow globe as big as you, with a tiny cabin inside.",
		Color = "#CFEFFF",
	},

	-- Flag.
	{
		Id = "BlueFlag",
		Name = "Blue Flag",
		Spot = "Flag",
		Source = "Starter",
		Blurb = "A plain blue flag.",
		Color = "#3D7BFF",
	},
	{
		Id = "RedFlag",
		Name = "Red Flag",
		Spot = "Flag",
		Source = "Shop",
		Price = 40,
		Blurb = "A bright red flag.",
		Color = "#E5484D",
	},
	{
		Id = "AuroraFlag",
		Name = "Aurora Flag",
		Spot = "Flag",
		Source = "Tier",
		Blurb = "Green and purple stripes.",
		Color = "#7C5CFF",
	},
	{
		Id = "RescueFlag",
		Name = "Rescue Flag",
		Spot = "Flag",
		Source = "Trophy",
		Trophy = "Rescue",
		Blurb = "Gold and white, for everyone who made it onto the train.",
		Color = "#F2C94C",
	},

	-- Window glow.
	{
		Id = "WarmGlow",
		Name = "Warm Glow",
		Spot = "Window",
		Source = "Starter",
		Blurb = "Firelight in the windows.",
		Color = "#FFB347",
	},
	{
		Id = "BlueGlow",
		Name = "Ice Blue Glow",
		Spot = "Window",
		Source = "Shop",
		Price = 30,
		Blurb = "A cool blue light.",
		Color = "#7CC8FF",
	},
	{
		Id = "GreenGlow",
		Name = "Pine Green Glow",
		Spot = "Window",
		Source = "Shop",
		Price = 30,
		Blurb = "A soft green light.",
		Color = "#6BE39A",
	},
	{
		Id = "RainbowGlow",
		Name = "Rainbow Glow",
		Spot = "Window",
		Source = "Pack",
		Blurb = "Windows that slowly change colour.",
		Color = "#FF6BD6",
	},
} :: { Decor }

Decor.ById = {} :: { [string]: Decor }
-- The decoration each spot starts with.
Decor.Default = {} :: { [string]: string }
for _, item in Decor.List do
	Decor.ById[item.Id] = item
	if item.Source == "Starter" then
		Decor.Default[item.Spot] = item.Id
	end
end

return Decor
