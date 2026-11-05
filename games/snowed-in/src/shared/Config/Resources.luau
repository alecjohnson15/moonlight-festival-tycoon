--!strict
-- The materials players gather and the things in the town they gather them
-- from. A node gives Yield of its resource each time its prompt is held for
-- HoldSeconds, Uses times, then is gone until RespawnSeconds later. Team
-- upgrades (Config/Recipes) add to the yield, and the Scout's role makes
-- every hold quicker.

export type Resource = {
	Id: string,
	Name: string,
	Icon: string,
	Color: string,
}

export type Node = {
	Id: string,
	Name: string,
	Gives: string,
	Yield: number,
	Uses: number,
	HoldSeconds: number,
	RespawnSeconds: number,
	-- The verb on the prompt.
	Action: string,
	-- The team upgrade that adds one to Yield, if any.
	Upgrade: string?,
	-- The sound played on each use.
	Sound: string,
}

local Resources = {}

-- In the order the HUD lists them.
Resources.List = {
	{ Id = "Wood", Name = "Wood", Icon = "🪵", Color = "#B07A4A" },
	{ Id = "Stone", Name = "Stone", Icon = "🪨", Color = "#A7B0BA" },
	{ Id = "Scrap", Name = "Scrap", Icon = "🔩", Color = "#8FA3B8" },
	{ Id = "Coal", Name = "Coal", Icon = "⚫", Color = "#4A4A55" },
	{ Id = "Fish", Name = "Fish", Icon = "🐟", Color = "#6FB7E0" },
	{ Id = "Berries", Name = "Frostberries", Icon = "🫐", Color = "#7E6CF0" },
} :: { Resource }

Resources.ById = {} :: { [string]: Resource }
for _, resource in Resources.List do
	Resources.ById[resource.Id] = resource
end

Resources.Nodes = {
	Pine = {
		Id = "Pine",
		Name = "Snowy Pine",
		Gives = "Wood",
		Yield = 2,
		Uses = 5,
		HoldSeconds = 0.9,
		RespawnSeconds = 90,
		Action = "Chop",
		Upgrade = "SharpAxes",
		Sound = "Chop",
	},
	Rock = {
		Id = "Rock",
		Name = "Boulder",
		Gives = "Stone",
		Yield = 2,
		Uses = 4,
		HoldSeconds = 1,
		RespawnSeconds = 100,
		Action = "Mine",
		Upgrade = "SturdyPicks",
		Sound = "Mine",
	},
	CoalSeam = {
		Id = "CoalSeam",
		Name = "Coal Seam",
		Gives = "Coal",
		Yield = 1,
		Uses = 4,
		HoldSeconds = 1.2,
		RespawnSeconds = 120,
		Action = "Mine",
		Upgrade = "SturdyPicks",
		Sound = "Mine",
	},
	Salvage = {
		Id = "Salvage",
		Name = "Buried Junk",
		Gives = "Scrap",
		Yield = 2,
		Uses = 3,
		HoldSeconds = 1.1,
		RespawnSeconds = 120,
		Action = "Dig out",
		Upgrade = "SnowShovels",
		Sound = "Dig",
	},
	FishingHole = {
		Id = "FishingHole",
		Name = "Ice Fishing Hole",
		Gives = "Fish",
		Yield = 1,
		Uses = 3,
		HoldSeconds = 2.2,
		RespawnSeconds = 45,
		Action = "Fish",
		Sound = "Splash",
	},
	BerryBush = {
		Id = "BerryBush",
		Name = "Frostberry Bush",
		Gives = "Berries",
		Yield = 3,
		Uses = 1,
		HoldSeconds = 0.6,
		RespawnSeconds = 60,
		Action = "Pick",
		Sound = "Pick",
	},
} :: { [string]: Node }

-- Supply crates appear around town every dawn. Each holds a fixed mix,
-- shown on its prompt before it is opened: no surprises, nothing paid.
Resources.Crate = {
	Count = 6,
	HoldSeconds = 1.5,
	Contents = { Scrap = 4, Coal = 2, Fish = 1 },
}

return Resources
