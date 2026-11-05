--!strict
-- The blizzard's monsters: cartoon frost creatures with glowing eyes. They
-- don't hurt players, they chill them (warmth goes down), and they don't die,
-- they puff back into snow. The server moves them as plain numbers
-- (shared/EnemySim) and each client draws them (shared/World/Monsters).
--
-- Speed is studs per second. Hit is the warmth a player loses per hit,
-- Smash the health a structure loses and Douse the flame the hearth loses.
-- Reach is how close they must be to hit, and Rate the seconds between hits.
-- Prefers says what they go for first: "Hearth" walks to the hearth and hits
-- whatever is in the way; "Players" chases the nearest player it can see
-- (within Sight) and otherwise heads for the hearth; "Structures" goes for
-- the nearest building first. Flying monsters pass over walls. Points is
-- what one costs from a night's wave budget, and From the first night it
-- can appear on.

export type Enemy = {
	Id: string,
	Name: string,
	Health: number,
	Speed: number,
	Radius: number,
	Hit: number,
	Smash: number,
	Douse: number,
	Reach: number,
	Rate: number,
	Prefers: "Hearth" | "Players" | "Structures",
	Sight: number,
	Flying: boolean,
	Points: number,
	From: number,
	-- Bosses only: hits land on everything within this radius.
	Slam: number?,
	Boss: boolean?,
	-- How big the client draws it.
	Scale: number,
}

local Enemies = {}

Enemies.List = {
	{
		Id = "Frostling",
		Name = "Frostling",
		Health = 30,
		Speed = 13,
		Radius = 1.5,
		Hit = 7,
		Smash = 8,
		Douse = 2,
		Reach = 4,
		Rate = 1,
		Prefers = "Hearth",
		Sight = 24,
		Flying = false,
		Points = 1,
		From = 1,
		Scale = 1,
	},
	{
		Id = "SnowHound",
		Name = "Snow Hound",
		Health = 40,
		Speed = 19,
		Radius = 2,
		Hit = 8,
		Smash = 6,
		Douse = 2,
		Reach = 4.5,
		Rate = 0.9,
		Prefers = "Players",
		Sight = 45,
		Flying = false,
		Points = 2,
		From = 2,
		Scale = 1,
	},
	{
		Id = "SnowBrute",
		Name = "Snow Brute",
		Health = 160,
		Speed = 7.5,
		Radius = 3.5,
		Hit = 18,
		Smash = 35,
		Douse = 6,
		Reach = 6.5,
		Rate = 1.8,
		Prefers = "Structures",
		Sight = 20,
		Flying = false,
		Points = 4,
		From = 3,
		Scale = 1,
	},
	{
		Id = "IceWisp",
		Name = "Ice Wisp",
		Health = 35,
		Speed = 11,
		Radius = 1.5,
		Hit = 6,
		Smash = 4,
		Douse = 2,
		Reach = 22,
		Rate = 1.6,
		Prefers = "Players",
		Sight = 40,
		Flying = true,
		Points = 3,
		From = 4,
		Scale = 1,
	},
	{
		Id = "Yeti",
		Name = "The Old Yeti",
		Health = 1200,
		Speed = 9,
		Radius = 5,
		Hit = 30,
		Smash = 80,
		Douse = 12,
		Reach = 9,
		Rate = 2.5,
		Prefers = "Hearth",
		Sight = 30,
		Flying = false,
		Points = 0,
		From = 99,
		Slam = 10,
		Boss = true,
		Scale = 1,
	},
	{
		Id = "ElderYeti",
		Name = "The Elder Yeti",
		Health = 2400,
		Speed = 9.5,
		Radius = 6,
		Hit = 35,
		Smash = 100,
		Douse = 15,
		Reach = 10,
		Rate = 2.3,
		Prefers = "Hearth",
		Sight = 34,
		Flying = false,
		Points = 0,
		From = 99,
		Slam = 12,
		Boss = true,
		Scale = 1.35,
	},
} :: { Enemy }

Enemies.ById = {} :: { [string]: Enemy }
Enemies.Code = {} :: { [string]: number }
Enemies.ByCode = {} :: { [number]: Enemy }
for code, enemy in Enemies.List do
	Enemies.ById[enemy.Id] = enemy
	-- A small number per kind, so a snapshot can say which kind in one byte.
	Enemies.Code[enemy.Id] = code
	Enemies.ByCode[code] = enemy
end

return Enemies
