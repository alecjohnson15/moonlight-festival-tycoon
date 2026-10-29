-- Plays the theme's sounds on this client: one-off effects by name, the
-- music as a playlist that goes round the theme's songs in turn, the
-- ambience of wherever the player is on a loop (crossfading as they move
-- between places; client/SoundZones picks it), loops for events such as
-- the parade's march, which turn the music down while they play, and loops
-- that play from a part, heard only near it, such as the ghost train's
-- wail. The player can turn the music, ambience and all loops off. A sound
-- whose id is empty in the theme plays its fallback, one of Roblox's own
-- sounds, or is silent if it has none, so the game runs before any audio is
-- uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared").Config.Theme)

local PLAYLIST = { "Music", "Music2" }
local AMBIENCE = "Ambience"
-- How loud the music is while an event loop plays.
local DUCKED = 0.25
local CROSSFADE = TweenInfo.new(2, Enum.EasingStyle.Sine)

local Sounds = {}

local made: { [string]: Sound } = {}
local loopsOn = true
-- The event loops playing now.
local events: { [string]: boolean } = {}
-- The loops playing from parts.
local attached: { [Sound]: boolean } = {}
-- The ambience loop for where the player is.
local ambience = AMBIENCE
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

-- Whether name has a sound to play: an uploaded id or a fallback.
function Sounds.has(name: string): boolean
	return soundId(name) ~= nil
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

-- Plays name on a loop from part, heard only within reach studs of it,
-- while loops are on. Only an uploaded sound plays, since a fallback would
-- grate on a loop.
function Sounds.attach(name: string, part: BasePart, reach: number): Sound?
	if not hasId(name) then
		return nil
	end
	local spec = Theme.Sounds[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = reach / 6
	sound.RollOffMaxDistance = reach
	sound.Parent = part
	attached[sound] = true
	sound.Destroying:Connect(function()
		attached[sound] = nil
	end)
	if loopsOn then
		sound:Play()
	end
	return sound
end

-- Whether the theme has any music or ambience to turn on and off.
function Sounds.hasLoops(): boolean
	return #songs() > 0 or hasId(AMBIENCE)
end

-- Crossfades to the ambience for where the player is, or the general one if
-- that place's isn't uploaded yet.
function Sounds.setAmbience(name: string)
	local wanted = if hasId(name) then name else AMBIENCE
	if wanted == ambience then
		return
	end
	local old, new = get(ambience), get(wanted)
	ambience = wanted
	if old then
		local fade = TweenService:Create(old, CROSSFADE, { Volume = 0 })
		fade.Completed:Connect(function()
			if ambience ~= old.Name then
				old:Stop()
			end
		end)
		fade:Play()
	end
	if new and loopsOn then
		new.Looped = true
		new.Volume = 0
		if not new.IsPlaying then
			new:Play()
		end
		TweenService:Create(new, CROSSFADE, { Volume = Theme.Sounds[wanted].Volume }):Play()
	end
end

function Sounds.loopsOn(): boolean
	return loopsOn
end

function Sounds.setLoops(on: boolean)
	loopsOn = on
	local place = get(ambience)
	if place then
		place.Looped = true
		if on and not place.IsPlaying then
			place.Volume = Theme.Sounds[ambience].Volume
			place:Play()
		elseif not on then
			place:Stop()
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
	for sound in attached do
		if not on then
			sound:Stop()
		elseif not sound.IsPlaying then
			sound:Play()
		end
	end
	duck()
end

function Sounds.start()
	Sounds.setLoops(true)
end

return Sounds
