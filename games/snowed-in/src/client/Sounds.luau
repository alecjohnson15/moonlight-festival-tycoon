-- Plays the game's sounds on this client: one-off effects by name (from
-- the screen, or from a spot in the world so they are heard only nearby),
-- the music for the time of day (cosy by day, tense by night, big while a
-- yeti is out) crossfading as it changes, and the wind on a loop under it
-- all. The player can turn the music and wind off (Settings). A sound with
-- no id plays its fallback, or nothing (Config/Sounds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine)

local Sounds = {}

local made: { [string]: Sound } = {}
local musicOn = true
local song: string? = nil

local function id(name: string): string?
	local spec = Config[name]
	if not spec then
		return nil
	end
	if spec.Id ~= "" then
		return spec.Id
	end
	return spec.Fallback
end

local function get(name: string): Sound?
	local existing = made[name]
	if existing then
		return existing
	end
	local soundId = id(name)
	if not soundId then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = Config[name].Volume
	sound.Parent = SoundService
	made[name] = sound
	return sound
end

function Sounds.play(name: string, pitch: number?)
	local sound = get(name)
	if sound then
		sound.PlaybackSpeed = pitch or 1
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Plays a sound from a spot in the world, heard within reach studs.
function Sounds.at(name: string, position: Vector3, reach: number?, pitch: number?)
	local soundId = id(name)
	if not soundId then
		return
	end
	local camera = Workspace.CurrentCamera
	local far = reach or 120
	if camera and (camera.CFrame.Position - position).Magnitude > far * 1.2 then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = Config[name].Volume
	sound.PlaybackSpeed = (pitch or 1) * (0.94 + math.random() * 0.12)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = far / 8
	sound.RollOffMaxDistance = far
	sound.Parent = holder
	sound:Play()
	sound.Ended:Connect(function()
		holder:Destroy()
	end)
	task.delay(12, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

local function fadeTo(sound: Sound, volume: number, stopAfter: boolean)
	local tween = TweenService:Create(sound, FADE, { Volume = volume })
	if stopAfter then
		tween.Completed:Connect(function()
			if sound.Volume <= 0.001 then
				sound:Stop()
			end
		end)
	end
	tween:Play()
end

-- Crossfades to a song (or to silence with nil).
function Sounds.music(name: string?)
	if name == song then
		return
	end
	local old = song and made[song]
	song = name
	if old then
		fadeTo(old, 0, true)
	end
	local new = name and Config[name] and Config[name].Id ~= "" and get(name)
	if new and musicOn then
		new.Looped = true
		new.Volume = 0
		if not new.IsPlaying then
			new.TimePosition = 0
			new:Play()
		end
		fadeTo(new, Config[name :: string].Volume, false)
	end
end

function Sounds.musicOn(): boolean
	return musicOn
end

-- Turns the music and the wind on or off.
function Sounds.setMusic(on: boolean)
	musicOn = on
	for _, name in { "MusicDay", "MusicNight", "MusicBoss", "Wind" } do
		local sound = made[name]
		if sound then
			if not on then
				sound:Stop()
			elseif name == song or name == "Wind" then
				sound.Volume = Config[name].Volume
				sound:Play()
			end
		end
	end
	if on and Config.Wind.Id ~= "" then
		local wind = get("Wind")
		if wind and not wind.IsPlaying then
			wind.Looped = true
			wind:Play()
		end
	end
end

-- Whether any music is uploaded, so the setting means something.
function Sounds.hasMusic(): boolean
	for _, name in { "MusicDay", "MusicNight", "MusicBoss", "Wind" } do
		if Config[name].Id ~= "" then
			return true
		end
	end
	return false
end

function Sounds.start()
	Sounds.setMusic(true)
end

return Sounds
