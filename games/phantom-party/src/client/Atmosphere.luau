-- The sky and sound for wherever this player's camera is: the lobby's
-- moonlit plaza, or the map's own night when the camera is at the party
-- (playing or watching). Also the Saboteur's blackout, and the music:
-- lobby music between rounds, round music during one, and a faster track
-- for the last thirty seconds.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Look = Shared:WaitForChild("Look")
local Lobby = require(Look.Lobby)
local Carnival = require(Look.Maps.Carnival)
local Manor = require(Look.Maps.Manor)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)

local MAP_RADIUS = 260
local BLEND = TweenInfo.new(1.2, Enum.EasingStyle.Sine)

local SKIES = {
	lobby = Lobby.Lighting,
	manor = Manor.Lighting,
	carnival = Carnival.Lighting,
}
local AMBIENCE = { manor = "ManorAmbience", carnival = "CarnivalAmbience" }

local Atmosphere = {}

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "Grade"
grade.Parent = Lighting
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.6
bloom.Parent = Lighting

local current: string? = nil
local darkUntil = 0
local final = false

local function mapOrigin(): Vector3
	local at = Game.MapOrigin
	return Vector3.new(at[1], at[2], at[3])
end

-- Which sky the camera is under: a map's id, or "lobby".
local function place(): string
	local camera = Workspace.CurrentCamera
	local mapId = Workspace:GetAttribute("MapId")
	if camera and mapId and SKIES[mapId] then
		if (camera.CFrame.Position - mapOrigin()).Magnitude < MAP_RADIUS then
			return mapId
		end
	end
	return "lobby"
end

local function apply(id: string)
	local sky = SKIES[id]
	current = id
	TweenService:Create(Lighting, BLEND, {
		ClockTime = sky.ClockTime,
		Brightness = sky.Brightness,
		Ambient = Color3.fromHex(sky.Ambient),
		OutdoorAmbient = Color3.fromHex(sky.OutdoorAmbient),
		FogColor = Color3.fromHex(sky.FogColor),
		ColorShift_Top = Color3.fromHex(sky.ColorShift),
		ExposureCompensation = sky.Exposure,
	}):Play()
	TweenService:Create(atmosphere, BLEND, {
		Density = sky.Atmosphere.Density,
		Haze = sky.Atmosphere.Haze,
		Color = Color3.fromHex(sky.Atmosphere.Color),
		Decay = Color3.fromHex(sky.Atmosphere.Decay),
	}):Play()
	TweenService:Create(grade, BLEND, { Brightness = 0, Saturation = 0.08, Contrast = 0.06 }):Play()
end

-- The lights go out at the party for a few seconds.
function Atmosphere.blackout(seconds: number)
	darkUntil = os.clock() + seconds
	if current == "lobby" then
		return
	end
	TweenService:Create(grade, TweenInfo.new(0.3), { Brightness = -0.32, Saturation = -0.6, Contrast = 0.25 }):Play()
	TweenService:Create(Lighting, TweenInfo.new(0.3), { ExposureCompensation = -1.6 }):Play()
	task.delay(seconds, function()
		if os.clock() >= darkUntil and current then
			apply(current)
		end
	end)
end

local function music()
	local round = State.Round
	local atParty = current ~= "lobby"
	if round.State == "Playing" and atParty then
		Sounds.setMusic(if final then "FinalMusic" else "RoundMusic")
	elseif round.State == "Reveal" and atParty then
		Sounds.setMusic(nil)
	else
		Sounds.setMusic("LobbyMusic")
	end
	Sounds.setAmbience(if atParty then AMBIENCE[current :: string] else nil)
end

function Atmosphere.start()
	apply("lobby")
	State.on("Final", function()
		final = true
		music()
	end)
	State.on("Round", function()
		if State.Round.State ~= "Playing" then
			final = false
		end
		music()
	end)
	local musicSetting: boolean? = nil
	State.on("Profile", function()
		local profile = State.Profile
		local on = not profile or not profile.Settings or profile.Settings.Music ~= false
		if on ~= musicSetting then
			musicSetting = on
			Sounds.setMusicOn(on)
		end
	end)
	task.spawn(function()
		while true do
			local wanted = place()
			if wanted ~= current then
				apply(wanted)
				music()
			end
			task.wait(0.5)
		end
	end)
end

return Atmosphere
