-- Every sound in the game. Each one is an original file in assets/audio,
-- made by tools/make_sounds.py. Upload them to Roblox (docs/launch.md) and
-- paste each asset id into Id as "rbxassetid://123...". Until then a sound
-- plays its Fallback, one of Roblox's own sounds, or nothing, so the game
-- runs before any audio is uploaded.
--
-- Music and ambience loop. Everything else plays once.

export type Sound = {
	Id: string,
	File: string,
	Volume: number,
	Fallback: string?,
	Loop: boolean?,
}

local Sounds = {}

local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local SLASH = "rbxasset://sounds/swordslash.wav"
local LUNGE = "rbxasset://sounds/swordlunge.wav"
local LAND = "rbxasset://sounds/action_jump_land.mp3"

Sounds.List = {
	-- Music.
	LobbyMusic = { Id = "", File = "music_lobby.ogg", Volume = 0.35, Loop = true },
	RoundMusic = { Id = "", File = "music_round.ogg", Volume = 0.3, Loop = true },
	FinalMusic = { Id = "", File = "music_final.ogg", Volume = 0.35, Loop = true },
	-- Ambience for each map.
	ManorAmbience = { Id = "", File = "ambience_manor.ogg", Volume = 0.4, Loop = true },
	CarnivalAmbience = { Id = "", File = "ambience_carnival.ogg", Volume = 0.35, Loop = true },
	-- Stings.
	RevealShadow = { Id = "", File = "reveal_shadow.ogg", Volume = 0.7, Fallback = LAND },
	RevealGuest = { Id = "", File = "reveal_guest.ogg", Volume = 0.6, Fallback = PING },
	GuestsWin = { Id = "", File = "win_guests.ogg", Volume = 0.7, Fallback = BUTTON },
	PhantomWins = { Id = "", File = "win_phantom.ogg", Volume = 0.7, Fallback = LAND },
	-- The round.
	Draw = { Id = "", File = "draw.ogg", Volume = 0.6, Fallback = LUNGE },
	Swing = { Id = "", File = "swing.ogg", Volume = 0.6, Fallback = SLASH },
	Throw = { Id = "", File = "throw.ogg", Volume = 0.6, Fallback = SWOOSH },
	Tag = { Id = "", File = "tag.ogg", Volume = 0.8, Fallback = LAND },
	Zap = { Id = "", File = "zap.ogg", Volume = 0.7, Fallback = PING },
	Misfire = { Id = "", File = "misfire.ogg", Volume = 0.7, Fallback = CLICK },
	Daze = { Id = "", File = "daze.ogg", Volume = 0.6, Fallback = SWOOSH },
	Revive = { Id = "", File = "revive.ogg", Volume = 0.7, Fallback = PING },
	Pickup = { Id = "", File = "pickup.ogg", Volume = 0.6, Fallback = BUTTON },
	Coin = { Id = "", File = "coin.ogg", Volume = 0.45, Fallback = PING },
	Page = { Id = "", File = "page.ogg", Volume = 0.6, Fallback = SWOOSH },
	Torn = { Id = "", File = "torn.ogg", Volume = 0.6, Fallback = CLICK },
	Bell = { Id = "", File = "bell.ogg", Volume = 0.8, Fallback = PING },
	Blackout = { Id = "", File = "blackout.ogg", Volume = 0.8, Fallback = LAND },
	Tick = { Id = "", File = "tick.ogg", Volume = 0.4, Fallback = CLICK },
	-- The lobby.
	CrateRoll = { Id = "", File = "crate_roll.ogg", Volume = 0.6, Fallback = CLICK },
	CrateReveal = { Id = "", File = "crate_reveal.ogg", Volume = 0.7, Fallback = BUTTON },
	TradeDone = { Id = "", File = "trade_done.ogg", Volume = 0.6, Fallback = BUTTON },
	LevelUp = { Id = "", File = "level_up.ogg", Volume = 0.6, Fallback = PING },
	Click = { Id = "", File = "click.ogg", Volume = 0.4, Fallback = CLICK },
	Deny = { Id = "", File = "deny.ogg", Volume = 0.5, Fallback = CLICK },
	Vote = { Id = "", File = "vote.ogg", Volume = 0.5, Fallback = BUTTON },
	-- Party emotes.
	Fanfare = { Id = "", File = "fanfare.ogg", Volume = 0.5, Fallback = BUTTON },
	Pop = { Id = "", File = "pop.ogg", Volume = 0.5, Fallback = CLICK },
} :: { [string]: Sound }

return Sounds
