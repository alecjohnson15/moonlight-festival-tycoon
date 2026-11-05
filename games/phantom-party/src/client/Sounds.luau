-- Plays the game's sounds on this client: one-off effects by name, either
-- flat or from a spot in the world; the music, which changes with the round
-- (lobby, round, last thirty seconds); and the map's ambience while the
-- player is at the party. The player can turn the music off in Settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)

local Sounds = {}

local made: { [string]: Sound } = {}
local music: string? = nil
local ambience: string? = nil
local musicOn = true

local function idOf(name: string): string?
	local spec = SoundConfig.List[name]
	if not spec then
		return nil
	end
	if spec.Id ~= "" then
		return spec.Id
	end
	return spec.Fallback
end

local function get(name: string): Sound?
	if made[name] then
		return made[name]
	end
	local id = idOf(name)
	if not id then
		return nil
	end
	local spec = SoundConfig.List[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = spec.Volume
	sound.Looped = spec.Loop == true
	sound.Parent = SoundService
	made[name] = sound
	return sound
end

-- Plays a sound once. With a position, it comes from there and fades with
-- distance.
function Sounds.play(name: string, position: Vector3?, pitch: number?)
	local sound = get(name)
	if not sound then
		return
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.CFrame = CFrame.new(position)
		holder.Parent = Workspace
		local copy = sound:Clone()
		copy.RollOffMaxDistance = 120
		copy.RollOffMinDistance = 10
		copy.PlaybackSpeed = pitch or 1
		copy.Parent = holder
		copy:Play()
		task.delay(6, function()
			holder:Destroy()
		end)
		return
	end
	if pitch then
		local copy = sound:Clone()
		copy.PlaybackSpeed = pitch
		copy.Parent = SoundService
		copy:Play()
		task.delay(6, function()
			copy:Destroy()
		end)
		return
	end
	SoundService:PlayLocalSound(sound)
end

local function fadeTo(sound: Sound, volume: number, stopAfter: boolean?)
	local tween = TweenService:Create(sound, FADE, { Volume = volume })
	tween:Play()
	if stopAfter then
		tween.Completed:Connect(function()
			if sound.Volume <= 0.01 then
				sound:Stop()
			end
		end)
	end
end

local function swap(current: string?, wanted: string?): string?
	if current == wanted and (wanted == nil or (made[wanted] and made[wanted].IsPlaying)) then
		return current
	end
	if current and current ~= wanted and made[current] then
		fadeTo(made[current], 0, true)
	end
	local spec = wanted and SoundConfig.List[wanted]
	local sound = wanted and get(wanted)
	if sound and spec and spec.Id ~= "" then
		sound.Volume = 0
		if not sound.IsPlaying then
			sound:Play()
		end
		fadeTo(sound, spec.Volume)
	end
	return wanted
end

-- Which song plays now: "LobbyMusic", "RoundMusic", "FinalMusic" or nil.
function Sounds.setMusic(name: string?)
	if not musicOn then
		music = name
		return
	end
	music = swap(music, name)
end

-- Which ambience loop plays now, or nil.
function Sounds.setAmbience(name: string?)
	ambience = swap(ambience, name)
end

function Sounds.setMusicOn(on: boolean)
	local wanted = music
	if music and made[music] then
		fadeTo(made[music], 0, true)
	end
	music = nil
	musicOn = on
	Sounds.setMusic(wanted)
end

function Sounds.start() end

return Sounds
