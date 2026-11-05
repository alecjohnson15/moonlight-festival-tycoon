--!strict
-- The game's own characters: the three judges, who vote in every matchup
-- (their votes count most when few players are watching), and the rivals,
-- who walk against players when a server is too small for a full bracket.
-- All names are original.

export type Judge = {
	Id: string,
	Name: string,
	Title: string,
	Loves: { string },
	Colors: { string },
	Lines: { Win: { string }, Theme: { string }, Close: { string } },
}

export type Rival = {
	Id: string,
	Name: string,
	Loves: { string },
	-- How well they dress for the theme, from 0 to 1.
	Skill: number,
	Rating: number,
	Skin: number,
	Pose: string,
}

local Judges: { Judge } = {
	{
		Id = "velour",
		Name = "Madame Velour",
		Title = "Couture Legend",
		Loves = { "glam", "formal", "royal" },
		Colors = { "Gold", "Ruby", "Black" },
		Lines = {
			Win = { "Exquisite.", "Now THAT is couture.", "Bravo, darling!", "Timeless." },
			Theme = { "You understood the brief.", "On theme and on point.", "The theme, perfected." },
			Close = { "Oh, this was close.", "I nearly fainted.", "Both of you, stunning." },
		},
	},
	{
		Id = "pixel",
		Name = "DJ Pixel",
		Title = "Street Style Star",
		Loves = { "neon", "street", "future", "music" },
		Colors = { "Hot Pink", "Aqua", "Lime" },
		Lines = {
			Win = { "That fit goes HARD.", "Turn it up!", "Main character energy.", "Certified fresh." },
			Theme = { "Theme? Nailed it.", "You get the vibe.", "Big theme energy." },
			Close = { "Ooh, photo finish!", "Too close to call!", "Rematch, please." },
		},
	},
	{
		Id = "stitch",
		Name = "Nana Stitch",
		Title = "Master Tailor",
		Loves = { "cozy", "cute", "nature", "pastel" },
		Colors = { "Blush", "Mint", "Cream" },
		Lines = {
			Win = { "Lovely stitching, dear.", "So charming!", "That made my day.", "Darling look!" },
			Theme = { "Right on theme, sweetie.", "You listened!", "A perfect match." },
			Close = { "Goodness, both so nice.", "I can't choose!", "Hugs for both." },
		},
	},
}

local Rivals: { Rival } = {
	{
		Id = "vee",
		Name = "Velvet Vee",
		Loves = { "glam", "formal" },
		Skill = 0.7,
		Rating = 1060,
		Skin = 6,
		Pose = "hips",
	},
	{ Id = "lumi", Name = "Lumi Lark", Loves = { "fairy", "pastel" }, Skill = 0.6, Rating = 1010, Skin = 2, Pose = "wave" },
	{ Id = "pixie", Name = "Pixie Pop", Loves = { "cute", "candy" }, Skill = 0.5, Rating = 960, Skin = 4, Pose = "peace" },
	{
		Id = "cosmo",
		Name = "Coco Cosmo",
		Loves = { "space", "future" },
		Skill = 0.65,
		Rating = 1030,
		Skin = 8,
		Pose = "tada",
	},
	{ Id = "jinx", Name = "Juniper Jinx", Loves = { "spooky", "punk" }, Skill = 0.55, Rating = 990, Skin = 3, Pose = "hips" },
	{
		Id = "nova",
		Name = "Nova Nightingale",
		Loves = { "music", "neon" },
		Skill = 0.75,
		Rating = 1090,
		Skin = 7,
		Pose = "tada",
	},
	{ Id = "marlo", Name = "Marlo Mint", Loves = { "street", "sporty" }, Skill = 0.45, Rating = 940, Skin = 5, Pose = "peace" },
	{ Id = "sunny", Name = "Sunny Sable", Loves = { "beach", "nature" }, Skill = 0.5, Rating = 970, Skin = 1, Pose = "wave" },
	{
		Id = "regal",
		Name = "Regal Rue",
		Loves = { "royal", "fantasy" },
		Skill = 0.8,
		Rating = 1120,
		Skin = 12,
		Pose = "hips",
	},
	{ Id = "dot", Name = "Dot Dazzle", Loves = { "retro", "party" }, Skill = 0.4, Rating = 920, Skin = 10, Pose = "wave" },
}

return {
	Judges = Judges,
	Rivals = Rivals,
}
