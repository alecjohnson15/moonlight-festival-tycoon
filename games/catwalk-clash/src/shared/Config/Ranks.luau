--!strict
-- Style Score ranks, lowest first. A player's rank shows on their name tag
-- and profile card. MinScore is the lowest Style Score that earns the rank.

export type Rank = { Name: string, MinScore: number, Color: string }

return {
	{ Name = "Newcomer", MinScore = 0, Color = "Cloud" },
	{ Name = "Rising Star", MinScore = 1000, Color = "Sky" },
	{ Name = "Trendsetter", MinScore = 1100, Color = "Mint" },
	{ Name = "Icon", MinScore = 1200, Color = "Lavender" },
	{ Name = "Supermodel", MinScore = 1350, Color = "Bubblegum" },
	{ Name = "Legend", MinScore = 1500, Color = "Gold" },
} :: { Rank }
