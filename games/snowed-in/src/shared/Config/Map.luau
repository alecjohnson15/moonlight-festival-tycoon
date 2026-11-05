--!strict
-- Where everything is in Pinehollow, the snowed-in town. Positions are
-- { X, Z } in studs on flat ground (Y = 0), with the hearth at the middle
-- and north toward -Z. shared/World/Town builds the town from this; the
-- server reads it to place monsters, prompts and objectives, and the tests
-- check that nothing overlaps (tests/World.spec).

export type Point = { number }

-- How a landmark's radio part is freed (with Config/Features.LandmarkTrials
-- on; off, every part is a plain "break the ice"). shared/Radio applies it.
--   Saw: hold the prompt Times times (anyone can take a turn).
--   Melt: hold for Seconds with a fire tool in hand.
--   Bring: hand over Amount of a Resource from your own backpack.
export type Trial = {
	Kind: "Saw" | "Melt" | "Bring",
	Times: number?,
	Seconds: number?,
	Resource: string?,
	Amount: number?,
	-- The prompt's words, and the hint the guide gives before you get there.
	Action: string,
	Hint: string,
}

export type Landmark = {
	Id: string,
	Name: string,
	At: Point,
	-- The radio part found here.
	Part: string,
	PartName: string,
	-- Clear ground around it, where no trees grow.
	Clear: number,
	Trial: Trial,
}

local Map = {}

Map.Hearth = { 0, 0 } :: Point
Map.Lodge = { 0, 50 } :: Point
Map.Workbench = { -20, 24 } :: Point
Map.Stockpile = { 20, 24 } :: Point
Map.CookPot = { 0, 26 } :: Point
Map.RadioTower = { 78, -78 } :: Point

-- The railway runs east to west south of the lodge; the rescue train stops
-- at the station.
Map.TrackZ = 132
Map.Station = { 0, 120 } :: Point

-- Cabins sit in a ring around the hearth, between the four roads the
-- monsters come along, so they are never in the way.
Map.CabinRadius = 62
Map.CabinCount = 8

Map.Landmarks = {
	{
		Id = "Sawmill",
		Name = "Old Sawmill",
		At = { 0, -255 },
		Part = "Generator",
		PartName = "Generator",
		Clear = 40,
		Trial = {
			Kind = "Saw",
			Times = 3,
			Seconds = 1.5,
			Action = "Saw the frozen logs",
			Hint = "It's jammed under frozen logs: saw them three times. Friends can take turns.",
		},
	},
	{
		Id = "IceCave",
		Name = "Ice Cave",
		At = { 258, -20 },
		Part = "Battery",
		PartName = "Big Battery",
		Clear = 38,
		Trial = {
			Kind = "Melt",
			Seconds = 5,
			Action = "Melt the ice",
			Hint = "The cave ice is thick: hold your torch (or any fire tool) out to melt it.",
		},
	},
	{
		Id = "Lighthouse",
		Name = "Lake Lighthouse",
		At = { -238, -30 },
		Part = "Lamp",
		PartName = "Signal Lamp",
		Clear = 30,
		Trial = {
			Kind = "Bring",
			Resource = "Wood",
			Amount = 6,
			Seconds = 1,
			Action = "Light the lighthouse fire",
			Hint = "Bring 6 wood in your backpack to light the lighthouse fire and thaw it out.",
		},
	},
	{
		Id = "Depot",
		Name = "Engine Depot",
		At = { 205, 190 },
		Part = "Antenna",
		PartName = "Antenna",
		Clear = 40,
		Trial = {
			Kind = "Bring",
			Resource = "Scrap",
			Amount = 4,
			Seconds = 1,
			Action = "Pry the crate open",
			Hint = "It's in a frozen crate: bring 4 scrap to pry it open. There's junk to dig nearby.",
		},
	},
} :: { Landmark }

Map.LandmarkById = {} :: { [string]: Landmark }
for _, landmark in Map.Landmarks do
	Map.LandmarkById[landmark.Id] = landmark
end

-- The frozen lake, where the fishing holes are.
Map.Lake = { At = { -200, -30 }, Radius = 78 }

-- The abandoned street, where most buried junk is.
Map.OldTown = { At = { -125, 185 }, Radius = 55 }

-- The quarry, where most boulders and coal are.
Map.Quarry = { At = { 150, -150 }, Radius = 45 }

-- Monsters come out of the blizzard at this distance.
Map.SpawnRadius = 240
Map.SpawnPoints = 8

-- The mountains around the valley, and the invisible wall just inside them.
Map.EdgeRadius = 330
Map.WallRadius = 318

-- How many of each thing the town scatters, and the seed that places them,
-- so the town is the same every run.
Map.Seed = 1225
Map.Trees = 120
Map.LooseRocks = 12
Map.Bushes = 22
Map.CrateSpots = 16

-- Circles monsters walk around rather than through: the lodge, the radio
-- tower and the cabins are added by the builder (shared/World/Town) as
-- { X, Z, Radius }.
Map.ObstacleMargin = 2

return Map
