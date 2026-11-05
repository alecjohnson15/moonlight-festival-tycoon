-- The game's name and the shape of a round: how long each part lasts, how
-- many players it takes, and how far voices carry. Everything a designer
-- would tune between play tests lives here or in the other Config modules.

local Game = {}

Game.Name = "Phantom Party"
Game.Title = "Phantom Party: Masquerade Mystery"
Game.Tagline = "One Phantom. One Guardian. Who's behind the mask?"

-- A full server. Twelve is the format's sweet spot: enough guests to hide
-- among, few enough that every round has a story.
Game.MaxPlayers = 12
-- The fewest players a live round starts with. In Studio a lone tester gets
-- a practice round instead (see Game.Practice).
Game.MinPlayers = 2

Game.Seconds = {
	-- The countdown in the lobby while players vote for the next map.
	Intermission = 20,
	-- Players stand frozen in the map while their role card shows.
	Reveal = 6,
	-- The Phantom's blade stays sheathed this long into the round, so
	-- nobody is tagged before they can run.
	Grace = 8,
	-- How long the guests must survive.
	Round = 180,
	-- Extra time for a big server, per player over eight.
	RoundPerExtraPlayer = 5,
	-- The scoreboard after a round.
	Results = 10,
	-- How long a tagged player lies dazed, when a Medic can still revive
	-- them, before they fade back to the lobby.
	Daze = 8,
	-- After a revive, how long nobody can tag that player again.
	ReviveShield = 3,
	-- The last stretch of a round, when the music and the clock speed up.
	Final = 30,
}

-- In Studio, with only one player, rounds still run so every role can be
-- tried: the tester takes each role in turn and the round lasts until its
-- clock runs out. Live servers never do this.
Game.Practice = {
	Order = { "Phantom", "Guardian", "Medic", "Saboteur", "Guest" },
	Round = 90,
}

-- Who hears whom in text chat during a round (see Rules/Chat).
Game.Chat = {
	-- How far a living player's voice carries to other living players.
	RoundRange = 60,
	-- Lobby chat reaches everyone in the lobby.
	LobbyRange = math.huge,
}

-- Walking and jumping, for everyone, in the lobby and in rounds.
Game.Movement = {
	WalkSpeed = 16,
	-- The Phantom is a hair faster, so a chase can end, and the Guardian a
	-- hair slower, so they can't simply outrun the Phantom.
	PhantomSpeed = 17,
	GuardianSpeed = 15.5,
	JumpHeight = 7.2,
}

-- Where things are in the world, as X, Y and Z. Maps are built far from the
-- lobby so voices and sounds from one never reach the other.
Game.LobbyOrigin = { 0, 0, 0 }
Game.MapOrigin = { 0, 0, 900 }

-- How long a map takes to vote in: how many maps are offered each
-- intermission (all of them while there are this many or fewer).
Game.VoteChoices = 3

return Game
