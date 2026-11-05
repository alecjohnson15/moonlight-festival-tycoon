--!strict
-- Role mastery goals: two or three per role, shown privately on the results
-- card the first time (and each time) a player meets one, and counted in
-- the save (data.Mastery, by id). They pay nothing and unlock nothing; they
-- give each role something to aim for beyond winning. Every goal either
-- needs the player's team to win or is plainly good for their team, so
-- none of them rewards throwing a round or picking on one player.
--
-- A goal is met when every condition it lists holds for the player's round
-- (Rules/Mastery):
--   Won, Survived, BellRang, Misfired, Hero, Dawn: must equal the value
--     given (Dawn is "the round ended at dawn").
--   Min: each named count must be at least the number given (Tags,
--     Revives, Clues, BlackoutsUsed).
--   Takedown: caught the Phantom.
--
-- Turn the whole thing off with Enabled = false: nothing is recorded or
-- shown, and saved counts stay as they were.

export type Goal = {
	Id: string,
	Role: string,
	Name: string,
	Text: string,
	Won: boolean?,
	Survived: boolean?,
	BellRang: boolean?,
	Misfired: boolean?,
	Hero: boolean?,
	Dawn: boolean?,
	Takedown: boolean?,
	Min: { [string]: number }?,
}

local Mastery = {}

Mastery.Enabled = true

Mastery.List = {
	{
		Id = "phantom_silent",
		Role = "Phantom",
		Name = "Silent Phantom",
		Text = "Win as the Phantom without the Truth Bell ringing.",
		Won = true,
		BellRang = false,
	},
	{
		Id = "phantom_triple",
		Role = "Phantom",
		Name = "Triple Tag",
		Text = "Tag three guests and win.",
		Won = true,
		Min = { Tags = 3 },
	},
	{
		Id = "saboteur_lights",
		Role = "Saboteur",
		Name = "Lights Out",
		Text = "Use both blackouts and win.",
		Won = true,
		Min = { BlackoutsUsed = 2 },
	},
	{
		Id = "saboteur_unseen",
		Role = "Saboteur",
		Name = "Never Suspected",
		Text = "Win as the Saboteur without being knocked out.",
		Won = true,
		Survived = true,
	},
	{
		Id = "guardian_clean",
		Role = "Guardian",
		Name = "Clean Catch",
		Text = "Catch the Phantom without zapping a single innocent guest.",
		Takedown = true,
		Misfired = false,
	},
	{
		Id = "guardian_watch",
		Role = "Guardian",
		Name = "Night Watch",
		Text = "Stay standing and win as the Guardian.",
		Won = true,
		Survived = true,
	},
	{
		Id = "medic_second",
		Role = "Medic",
		Name = "Second Chance",
		Text = "Revive a guest and win.",
		Won = true,
		Min = { Revives = 1 },
	},
	{
		Id = "medic_field",
		Role = "Medic",
		Name = "Field Doctor",
		Text = "Revive two guests in one round.",
		Min = { Revives = 2 },
	},
	{
		Id = "guest_bell",
		Role = "Guest",
		Name = "Bell Ringer",
		Text = "Bring three clue pages to the Truth Bell and win.",
		Won = true,
		Min = { Clues = 3 },
	},
	{
		Id = "guest_dawn",
		Role = "Guest",
		Name = "Dawn Survivor",
		Text = "Stay standing until dawn.",
		Won = true,
		Survived = true,
		Dawn = true,
	},
	{
		Id = "guest_hero",
		Role = "Guest",
		Name = "Borrowed Courage",
		Text = "Pick up a fallen Guardian's blaster and win.",
		Won = true,
		Hero = true,
	},
} :: { Goal }

return Mastery
