-- Plays the theme's sounds on this client: one-off effects by name, the
-- music as a playlist that goes round the theme's songs in turn, the eerie
-- ambience on a loop, and loops for events such as the parade's march, which
-- turn the music down while they play. The player can turn the music,
-- ambience and event loops off. A sound whose id is empty in the theme plays
-- its fallback, one of Roblox's own sounds, or is silent if it has none, so
-- the game runs before any audio is uploaded.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared").Config.Theme)

local PLAYLIST = { "Music", "Music2" }
local AMBIENCE = "Ambience"
-- How loud the music is while an event loop plays.
local DUCKED = 0.25

local Sounds = {}

local made: { [string]: Sound } = {}
local loopsOn = true
-- The event loops playing now.
local events: { [string]: boolean } = {}
-- Which of the songs with an id is playing, by its place in that list.
local current = 0
local playNextSong: () -> ()

local function hasId(name: string): boolean
	local spec = Theme.Sounds[name]
	return spec ~= nil and spec.Id ~= ""
end

local function soundId(name: string): string?
	local spec = Theme.Sounds[name]
	if spec and spec.Id ~= "" then
		return spec.Id
	end
	return spec and spec.Fallback
end

local function get(name: string): Sound?
	local sound = made[name]
	if sound then
		return sound
	end
	local id = soundId(name)
	if not id then
		return nil
	end
	local spec = Theme.Sounds[name]
	local created = Instance.new("Sound")
	created.Name = name
	created.SoundId = id
	created.Volume = spec.Volume
	created.Parent = SoundService
	if table.find(PLAYLIST, name) then
		created.Ended:Connect(playNextSong)
	end
	made[name] = created
	return created
end

-- The songs that have been uploaded, in playlist order.
local function songs(): { string }
	local list = {}
	for _, name in PLAYLIST do
		if hasId(name) then
			table.insert(list, name)
		end
	end
	return list
end

function playNextSong()
	local list = songs()
	if not loopsOn or #list == 0 then
		return
	end
	current = current % #list + 1
	local sound = get(list[current])
	if sound then
		-- A single song repeats; more than one take turns.
		sound.Looped = #list == 1
		sound.TimePosition = 0
		sound:Play()
	end
end

function Sounds.play(name: string)
	local sound = get(name)
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Turns the songs down while an event loop plays, and back up after.
local function duck()
	local scale = if next(events) and loopsOn then DUCKED else 1
	for _, name in PLAYLIST do
		local song = made[name]
		if song then
			song.Volume = Theme.Sounds[name].Volume * scale
		end
	end
end

-- Starts an event's loop, if loops are on and it has a sound.
function Sounds.startLoop(name: string)
	local sound = get(name)
	if not sound or events[name] then
		return
	end
	events[name] = true
	sound.Looped = true
	if loopsOn then
		sound.TimePosition = 0
		sound:Play()
	end
	duck()
end

function Sounds.stopLoop(name: string)
	local sound = made[name]
	events[name] = nil
	if sound then
		sound:Stop()
	end
	duck()
end

-- Whether the theme has any music or ambience to turn on and off.
function Sounds.hasLoops(): boolean
	return #songs() > 0 or hasId(AMBIENCE)
end

function Sounds.loopsOn(): boolean
	return loopsOn
end

function Sounds.setLoops(on: boolean)
	loopsOn = on
	local ambience = get(AMBIENCE)
	if ambience then
		ambience.Looped = true
		if on and not ambience.IsPlaying then
			ambience:Play()
		elseif not on then
			ambience:Stop()
		end
	end

	local playing = false
	for _, name in songs() do
		local song = get(name)
		if song and not on then
			song:Stop()
		elseif song and song.IsPlaying then
			playing = true
		end
	end
	if on and not playing then
		playNextSong()
	end
	for name in events do
		local sound = made[name]
		if sound and not on then
			sound:Stop()
		elseif sound and not sound.IsPlaying then
			sound:Play()
		end
	end
	duck()
end

function Sounds.start()
	Sounds.setLoops(true)
end

return Sounds
