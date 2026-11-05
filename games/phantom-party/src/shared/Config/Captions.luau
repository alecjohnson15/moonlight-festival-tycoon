--!strict
-- Words for the sounds that tell a player something, shown at the bottom of
-- the screen when they turn on Captions in Settings (off by default). A
-- sound from a spot in the world also says which way it came from. Menu
-- clicks, music and ambience have no caption on purpose. Every name here
-- must be a sound in Config/Sounds (tests/Accessibility.spec checks).

local Captions = {}

-- How long a caption stays, and how many show at once.
Captions.Seconds = 3
Captions.MaxLines = 3
-- A sound further than this from the camera gets no caption (it's too
-- faint to hear anyway).
Captions.Range = 120

Captions.Text = {
	Draw = "Blade drawn",
	Swing = "Blade swish",
	Throw = "Blade whistling through the air",
	Tag = "Someone was tagged",
	Zap = "Blaster zap",
	Misfire = "Blaster misfire",
	Daze = "Someone is dazed",
	Revive = "Someone was revived",
	Page = "Paper rustling",
	Torn = "Paper tearing",
	Bell = "The Truth Bell rings",
	Blackout = "The lights go out",
	Tick = "Clock ticking",
	RevealShadow = "Role revealed",
	RevealGuest = "Role revealed",
	GuestsWin = "Guests win music",
	PhantomWins = "Phantom wins music",
	TradeDone = "Trade complete",
	LevelUp = "Level up",
	Fanfare = "Fanfare",
} :: { [string]: string }

return Captions
