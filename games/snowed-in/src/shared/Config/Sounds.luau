--!strict
-- Every sound and song, as Roblox asset ids ("rbxassetid://123"). All of
-- them are original: tools/make_sounds.py synthesises each one from sine
-- waves and noise into assets/audio/<snake_case name>.ogg. Upload those and
-- paste their ids here (docs/launch.md has the list). Until a sound has an
-- id it plays its Fallback, one of the plain sounds that come with Roblox
-- ("rbxasset://sounds/..."), or nothing, so the game runs before any audio
-- is uploaded. Volume is 0 to 1.

export type Sound = { Id: string, Volume: number, Fallback: string? }

local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local THUMP = "rbxasset://sounds/action_jump_land.mp3"

local Sounds: { [string]: Sound } = {
	-- Music: a cosy song for the days, a tense one for the nights, and a
	-- big one while a yeti is out. The wind loops under everything.
	MusicDay = { Id = "", Volume = 0.3 },
	MusicNight = { Id = "", Volume = 0.32 },
	MusicBoss = { Id = "", Volume = 0.38 },
	Wind = { Id = "", Volume = 0.3 },

	-- Gathering.
	Chop = { Id = "", Volume = 0.55, Fallback = THUMP },
	Mine = { Id = "", Volume = 0.55, Fallback = THUMP },
	Dig = { Id = "", Volume = 0.5, Fallback = THUMP },
	Splash = { Id = "", Volume = 0.5, Fallback = SWOOSH },
	Pick = { Id = "", Volume = 0.5, Fallback = CLICK },
	Deposit = { Id = "", Volume = 0.55, Fallback = BUTTON },
	Crate = { Id = "", Volume = 0.6, Fallback = PING },
	PackFull = { Id = "", Volume = 0.5, Fallback = CLICK },

	-- The base.
	Feed = { Id = "", Volume = 0.6, Fallback = SWOOSH },
	HearthUp = { Id = "", Volume = 0.7, Fallback = PING },
	Build = { Id = "", Volume = 0.55, Fallback = THUMP },
	Broken = { Id = "", Volume = 0.6, Fallback = THUMP },
	Repair = { Id = "", Volume = 0.5, Fallback = CLICK },
	Craft = { Id = "", Volume = 0.6, Fallback = PING },
	Cook = { Id = "", Volume = 0.55, Fallback = PING },
	Eat = { Id = "", Volume = 0.55, Fallback = BUTTON },

	-- Fighting.
	Swing = { Id = "", Volume = 0.5, Fallback = SWOOSH },
	Sling = { Id = "", Volume = 0.5, Fallback = SWOOSH },
	Flare = { Id = "", Volume = 0.55, Fallback = SWOOSH },
	Blaze = { Id = "", Volume = 0.5, Fallback = SWOOSH },
	Cannon = { Id = "", Volume = 0.65, Fallback = THUMP },
	Hit = { Id = "", Volume = 0.45, Fallback = CLICK },
	Poof = { Id = "", Volume = 0.5, Fallback = SWOOSH },
	Slam = { Id = "", Volume = 0.7, Fallback = THUMP },
	Roar = { Id = "", Volume = 0.75, Fallback = THUMP },

	-- Warmth.
	Freeze = { Id = "", Volume = 0.6, Fallback = CLICK },
	Thaw = { Id = "", Volume = 0.6, Fallback = PING },
	Chill = { Id = "", Volume = 0.4 },
	Ability = { Id = "", Volume = 0.6, Fallback = PING },

	-- The run.
	NightHorn = { Id = "", Volume = 0.7, Fallback = BUTTON },
	DawnChime = { Id = "", Volume = 0.65, Fallback = PING },
	IceBreak = { Id = "", Volume = 0.6, Fallback = THUMP },
	RadioFit = { Id = "", Volume = 0.7, Fallback = PING },
	Called = { Id = "", Volume = 0.7, Fallback = PING },
	TrainHorn = { Id = "", Volume = 0.8, Fallback = BUTTON },
	Win = { Id = "", Volume = 0.7, Fallback = PING },
	Lose = { Id = "", Volume = 0.6, Fallback = BUTTON },

	-- Menus.
	Click = { Id = "", Volume = 0.45, Fallback = CLICK },
	Unlock = { Id = "", Volume = 0.65, Fallback = PING },
	Deny = { Id = "", Volume = 0.45, Fallback = CLICK },
	Notice = { Id = "", Volume = 0.35 },
}

return Sounds
