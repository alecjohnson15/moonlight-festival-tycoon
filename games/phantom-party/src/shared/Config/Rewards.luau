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

-- Clue pages counted for coins and XP in one round, so pages can't be
-- farmed once the bell has rung. Pages past this still fill the bell.
Rewards.ClueCap = 10

-- The Truth Bell, which clue pages fill (Rules/Bell). At RoomAt percent it
-- chimes the room the Phantom is in; full, it lights the Phantom up for
-- everyone for a few seconds, then empties.
--
-- A bigger party finds pages faster, so the bell takes more pages the more
-- guests there are: Base plus PerGuest for each guest, between Min and Max.
-- It rings at most MaxRings times a round, and the room hint is a snapshot
-- of where the Phantom was when the bell passed half, not a live tracker
-- (TrackRoom), so the Phantom can move away and the guests must act on it.
--
-- Rollback to the first version: Base = 10, PerGuest = 0, Min = 10,
-- Max = 10, TrackRoom = true, MaxRings = math.huge.
Rewards.Bell = {
	Base = 8,
	PerGuest = 0.75,
	Min = 8,
	Max = 18,
	RoomAt = 50,
	-- How long the room hint stays on screen when it isn't tracking.
	HintSeconds = 12,
	TrackRoom = false,
	MaxRings = 1,
	RevealSeconds = 4,
}
-- The HUD's half-way mark.
Rewards.ClueRoomAt = Rewards.Bell.RoomAt

return Rewards
