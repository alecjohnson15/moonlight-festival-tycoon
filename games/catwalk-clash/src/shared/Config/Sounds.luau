--!strict
-- Sounds and music, as Roblox asset ids ("rbxassetid://123"). The files are
-- made by tools/make_sounds.py into assets/audio (named in File); upload
-- them and paste each id into Id (docs/launch.md, step 5). Until then a
-- sound plays its Fallback, one of the plain sounds that come with Roblox,
-- or stays silent, so the game runs before anything is uploaded.

export type Sound = { Id: string, File: string, Volume: number, Fallback: string? }

local PING = "rbxasset://sounds/electronicpingshort.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"

return {
	-- Music: one song for each part of a round (client/Sounds picks).
	LobbyMusic = { Id = "", File = "music_lobby.ogg", Volume = 0.32 },
	BackstageMusic = { Id = "", File = "music_backstage.ogg", Volume = 0.3 },
	RunwayMusic = { Id = "", File = "music_runway.ogg", Volume = 0.36 },
	CrowdLoop = { Id = "", File = "crowd_loop.ogg", Volume = 0.22 },

	Click = { Id = "", File = "click.ogg", Volume = 0.4, Fallback = CLICK },
	Equip = { Id = "", File = "equip.ogg", Volume = 0.45, Fallback = CLICK },
	Purchase = { Id = "", File = "purchase.ogg", Volume = 0.55, Fallback = BUTTON },
	Deny = { Id = "", File = "deny.ogg", Volume = 0.45, Fallback = CLICK },
	Reveal = { Id = "", File = "theme_reveal.ogg", Volume = 0.6, Fallback = SWOOSH },
	Tick = { Id = "", File = "tick.ogg", Volume = 0.35, Fallback = CLICK },
	Whoosh = { Id = "", File = "whoosh.ogg", Volume = 0.45, Fallback = SWOOSH },
	Vote = { Id = "", File = "vote.ogg", Volume = 0.5, Fallback = BUTTON },
	VoteReveal = { Id = "", File = "vote_reveal.ogg", Volume = 0.55, Fallback = PING },
	MatchWin = { Id = "", File = "match_win.ogg", Volume = 0.55, Fallback = PING },
	Crown = { Id = "", File = "crown.ogg", Volume = 0.65, Fallback = PING },
	Cheer = { Id = "", File = "cheer.ogg", Volume = 0.5 },
	Shutter = { Id = "", File = "shutter.ogg", Volume = 0.35, Fallback = CLICK },
	Sparkle = { Id = "", File = "sparkle.ogg", Volume = 0.45, Fallback = PING },
	LevelUp = { Id = "", File = "level_up.ogg", Volume = 0.55, Fallback = PING },
	Ready = { Id = "", File = "ready.ogg", Volume = 0.5, Fallback = BUTTON },
} :: { [string]: Sound }
