-- Emotes, from the emote wheel (press G, or the smiley button). Moves use
-- the dances and gestures every Roblox character already has. Reactions put
-- a bubble over your head for a few seconds; Suspect points one at another
-- player. Party emotes come with the Party Emotes game pass and are effects
-- only: they never hide you or move you.

export type Emote = {
	Id: string,
	Name: string,
	-- One of the built-in emotes the default Animate script plays.
	Anim: string?,
	-- Text shown in a bubble over the head.
	Bubble: string?,
	-- An effect drawn by every client (client/Emotes).
	Effect: string?,
	-- Needs the Party Emotes pass.
	Pass: boolean?,
	-- Points at another player.
	Target: boolean?,
}

local Emotes = {}

Emotes.List = {
	{ Id = "wave", Name = "Wave", Anim = "wave" },
	{ Id = "point", Name = "Point", Anim = "point" },
	{ Id = "cheer", Name = "Cheer", Anim = "cheer" },
	{ Id = "laugh", Name = "Laugh", Anim = "laugh" },
	{ Id = "dance", Name = "Dance", Anim = "dance" },
	{ Id = "dance2", Name = "Groove", Anim = "dance2" },
	{ Id = "dance3", Name = "Shuffle", Anim = "dance3" },
	{ Id = "hmm", Name = "Hmm?", Bubble = "?" },
	{ Id = "alarm", Name = "Look out!", Bubble = "!" },
	{ Id = "shh", Name = "Shh", Bubble = "Shh..." },
	{ Id = "trust", Name = "Trust me", Bubble = "Trust me!" },
	{ Id = "suspect", Name = "Suspect...", Target = true },
	{ Id = "spotlight", Name = "Spotlight", Effect = "spotlight", Pass = true },
	{ Id = "cannon", Name = "Confetti Cannon", Effect = "cannon", Pass = true },
	{ Id = "puff", Name = "Glitter Puff", Effect = "puff", Pass = true },
	{ Id = "halo", Name = "Star Halo", Effect = "halo", Pass = true },
	{ Id = "applause", Name = "Applause", Effect = "applause", Pass = true },
} :: { Emote }

-- How long a bubble stays up, and how soon the same player can emote again.
Emotes.BubbleSeconds = 4
Emotes.Cooldown = 1.5

function Emotes.get(id: string): Emote?
	for _, emote in Emotes.List do
		if emote.Id == id then
			return emote
		end
	end
	return nil
end

return Emotes
