--!strict
-- What players build around the hearth. Everything sits on the build grid
-- (Config/Balance Build.Grid studs), within the build circle, and costs
-- stockpile resources. The Builder pays less (Config/Roles) and is the only
-- one who can raise a Blaze Tower.
--
-- Monsters walk straight at the hearth, so anything Solid in the way stops
-- them until they break it. Walls are long and cheap; turrets shoot; traps
-- burn whatever walks over them; warm things heat the players nearby.
--
-- Width and Depth are the footprint in studs along X and Z before turning
-- (a quarter turn swaps them) and Height how tall it stands. Parts is the most parts
-- its model may use (tests/World.spec checks), which keeps a full base under
-- the part budget.

export type Structure = {
	Id: string,
	Name: string,
	Blurb: string,
	Cost: { [string]: number },
	Health: number,
	Width: number,
	Depth: number,
	Height: number,
	Solid: boolean,
	Needs: number,
	Role: string?,
	-- Turrets.
	Damage: number?,
	Cooldown: number?,
	Range: number?,
	Splash: number?,
	-- Traps: damage per second to monsters standing on it.
	Burn: number?,
	-- Warm things: radius of the warm circle.
	Warmth: number?,
	Parts: number,
	Order: number,
	Icon: string,
}

local Structures = {}

Structures.List = {
	{
		Id = "WoodWall",
		Name = "Log Wall",
		Blurb = "Cheap and quick. Slows the monsters down.",
		Cost = { Wood = 6 },
		Health = 120,
		Width = 8,
		Depth = 2,
		Height = 6,
		Solid = true,
		Needs = 1,
		Parts = 7,
		Order = 1,
		Icon = "🧱",
	},
	{
		Id = "StoneWall",
		Name = "Stone Wall",
		Blurb = "Takes a real beating.",
		Cost = { Stone = 8, Wood = 2 },
		Health = 320,
		Width = 8,
		Depth = 2,
		Height = 7,
		Solid = true,
		Needs = 2,
		Parts = 6,
		Order = 2,
		Icon = "🏰",
	},
	{
		Id = "Lantern",
		Name = "Lantern Post",
		Blurb = "Lights the dark and keeps the people beside it warm.",
		Cost = { Wood = 3, Scrap = 2 },
		Health = 60,
		Width = 4,
		Depth = 4,
		Height = 8,
		Solid = false,
		Needs = 1,
		Warmth = 10,
		Parts = 5,
		Order = 3,
		Icon = "🏮",
	},
	{
		Id = "EmberTrap",
		Name = "Ember Trap",
		Blurb = "Hot coals under the snow. Burns monsters that walk on it.",
		Cost = { Wood = 4, Scrap = 4, Coal = 2 },
		Health = 90,
		Width = 8,
		Depth = 8,
		Height = 1,
		Solid = false,
		Needs = 1,
		Burn = 10,
		Parts = 6,
		Order = 4,
		Icon = "🔥",
	},
	{
		Id = "Campfire",
		Name = "Campfire",
		Blurb = "A small warm circle for an outpost.",
		Cost = { Wood = 8, Stone = 4 },
		Health = 80,
		Width = 8,
		Depth = 8,
		Height = 4,
		Solid = false,
		Needs = 2,
		Warmth = 16,
		Parts = 8,
		Order = 5,
		Icon = "🏕️",
	},
	{
		Id = "EmberTurret",
		Name = "Ember Turret",
		Blurb = "Shoots embers at the nearest monster.",
		Cost = { Scrap = 10, Stone = 6, Coal = 4 },
		Health = 150,
		Width = 4,
		Depth = 4,
		Height = 7,
		Solid = true,
		Needs = 1,
		Damage = 9,
		Cooldown = 0.8,
		Range = 42,
		Parts = 8,
		Order = 6,
		Icon = "🗼",
	},
	{
		Id = "BlazeTower",
		Name = "Blaze Tower",
		Blurb = "Builder only. Lobs fireballs that burst on groups.",
		Cost = { Scrap = 22, Stone = 16, Coal = 10 },
		Health = 260,
		Width = 8,
		Depth = 8,
		Height = 12,
		Solid = true,
		Needs = 3,
		Role = "Builder",
		Damage = 20,
		Cooldown = 1,
		Range = 46,
		Splash = 7,
		Parts = 12,
		Order = 7,
		Icon = "🌋",
	},
} :: { Structure }

Structures.ById = {} :: { [string]: Structure }
for _, structure in Structures.List do
	Structures.ById[structure.Id] = structure
end

-- Wood to repair a quarter of a structure's health.
Structures.RepairCost = { Wood = 2 }
Structures.RepairShare = 0.25

return Structures
