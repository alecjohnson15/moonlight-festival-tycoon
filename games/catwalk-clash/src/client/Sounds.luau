-- Music and sound effects on this client. Each part of a round has its own
-- song (the lobby, backstage while dressing, and the runway, with the crowd
-- under it), crossfading as the phase changes; effects play by name. A sound
-- whose id is empty in Config/Sounds plays its fallback (one of Roblox's own
-- sounds) or stays silent, so the game runs before any audio is uploaded.
-- The Music setting turns the songs and crowd off; Effects turns the rest off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local SoundConfig = require(Config.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)

local PHASE_SONG = {
	Waiting = "LobbyMusic",
	Lobby = "LobbyMusic",
	ThemeVote = "LobbyMusic",
	Reveal = "LobbyMusic",
	Dressing = "BackstageMusic",
	Showtime = "RunwayMusic",
	Crowning = "RunwayMusic",
}

local Sounds = {}

local made: { [string]: Sound } = {}
local musicOn = true
local effectsOn = true
local song: string? = nil
local crowd = false

local function soundId(name: string): string?
	local spec = SoundConfig[name]
	if not spec then
		return nil
	end
	if spec.Id ~= "" then
		return spec.Id
	end
	return spec.Fallback
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
	local created = Instance.new("Sound")
	created.Name = name
	created.SoundId = id
	created.Volume = SoundConfig[name].Volume
	created.Parent = SoundService
	made[name] = created
	return created
end

-- Plays a sound effect once.
function Sounds.play(name: string, pitch: number?)
	if not effectsOn then
		return
	end
	local sound = get(name)
	if sound then
		sound.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(sound)
	end
end

local function fadeTo(sound: Sound, volume: number, stop: boolean)
	local tween = TweenService:Create(sound, FADE, { Volume = volume })
	if stop then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and sound.Volume <= 0.01 then
				sound:Stop()
			end
		end)
	end
	tween:Play()
end

local function setLoop(name: string, on: boolean)
	local sound = get(name)
	if not sound then
		return
	end
	sound.Looped = true
	local volume = SoundConfig[name].Volume
	if on and musicOn then
		if not sound.IsPlaying then
			sound.Volume = 0
			sound:Play()
		end
		fadeTo(sound, volume, false)
	elseif sound.IsPlaying then
		fadeTo(sound, 0, true)
	end
end

local function update()
	local phase = State.phase()
	local wanted = PHASE_SONG[phase] or "LobbyMusic"
	if wanted ~= song then
		if song then
			setLoop(song, false)
		end
		song = wanted
	end
	setLoop(wanted, true)
	local wantCrowd = phase == "Showtime" or phase == "Crowning"
	if wantCrowd ~= crowd then
		crowd = wantCrowd
		setLoop("CrowdLoop", wantCrowd)
	end
end

function Sounds.start()
	Ui.clickSound = function()
		Sounds.play("Click")
	end
	State.onRound(function(name)
		if name == "Phase" then
			update()
		end
	end)
	State.onProfile(function(profile)
		local settings = profile.Settings or {}
		local music = settings.Music ~= false
		effectsOn = settings.Effects ~= false
		if music ~= musicOn then
			musicOn = music
			if song then
				setLoop(song, musicOn)
			end
			setLoop("CrowdLoop", musicOn and crowd)
		end
	end)
	update()
end

return Sounds
