-- What a round pays. Coins buy crates and shop items; XP climbs the Moon
-- Pass and the player's level. A typical round pays 30 to 80 coins and 60
-- to 150 XP; Rules/Progress adds it up.

local Rewards = {}

Rewards.Coins = {
	-- Each candy coin picked up in a round, up to Cap a round.
	Pickup = 1,
	Cap = 40,
	Win = 20,
	Survive = 10,
	-- The Phantom, for each guest tagged out.
	Tag = 3,
	-- Whoever knocks out the Phantom.
	Takedown = 25,
	Revive = 10,
	Clue = 2,
}

Rewards.Xp = {
	Played = 20,
	Win = 40,
	Survive = 30,
	Tag = 10,
	Takedown = 60,
	Revive = 30,
	Clue = 5,
	Coin = 1,
}

-- Levels: each takes Base + Step x (level - 1) XP, so early levels come
-- quickly and later ones take longer.
Rewards.Level = { Base = 200, Step = 50, Max = 200 }

-- Clue pages fill the Truth Bell. Each page adds this much (out of 100).
Rewards.CluePerPage = 10
-- At 50 the bell shows which room the Phantom is in; at 100 it lights the
-- Phantom up for everyone for a few seconds, then the bell empties again.
Rewards.ClueRoomAt = 50
Rewards.ClueRevealSeconds = 4

return Rewards
