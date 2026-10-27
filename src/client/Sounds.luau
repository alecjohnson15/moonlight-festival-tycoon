-- Plays the theme's sounds on this client: one-off effects by name, and the
-- music and eerie ambience on a loop, which the player can turn off. A sound
-- whose id is empty in the theme is silent, so the game runs before any audio
-- is uploaded.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared").Config.Theme)

local LOOPS = { "Music", "Ambience" }

local Sounds = {}

local made: { [string]: Sound } = {}
local loopsOn = true

local function get(name: string): Sound?
	local sound = made[name]
	if sound then
		return sound
	end
	local spec = Theme.Sounds[name]
	if not spec or spec.Id == "" then
		return nil
	end
	local created = Instance.new("Sound")
	created.Name = name
	created.SoundId = spec.Id
	created.Volume = spec.Volume
	created.Parent = SoundService
	made[name] = created
	return created
end

function Sounds.play(name: string)
	local sound = get(name)
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Whether the theme has any music or ambience to turn on and off.
function Sounds.hasLoops(): boolean
	for _, name in LOOPS do
		if Theme.Sounds[name] and Theme.Sounds[name].Id ~= "" then
			return true
		end
	end
	return false
end

function Sounds.loopsOn(): boolean
	return loopsOn
end

function Sounds.setLoops(on: boolean)
	loopsOn = on
	for _, name in LOOPS do
		local sound = get(name)
		if sound then
			sound.Looped = true
			if on and not sound.IsPlaying then
				sound:Play()
			elseif not on then
				sound:Stop()
			end
		end
	end
end

function Sounds.start()
	Sounds.setLoops(true)
end

return Sounds
