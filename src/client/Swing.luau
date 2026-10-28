-- What a held weapon's swing looks and sounds like on this client: a thump or
-- a whoosh where it lands, a puff of dust in the weapon's colour and, for your
-- own heavy hits, a little shake. The server paces swings and plays the
-- swing animation; this only adds the effects, for every player's swings.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage:WaitForChild("Shared").Config.Theme)

local CosmeticSwung = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CosmeticSwung") :: RemoteEvent

-- How long the swing animation takes to bring the weapon down.
local LAND_SECONDS = 0.18
local DEFAULT_SWING = { Sound = "Thump", Dust = "#C9A27A" }

local Swing = {}

local player = Players.LocalPlayer

local function shake(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.CameraOffset = Vector3.new(0, -0.35, 0)
	TweenService:Create(humanoid, TweenInfo.new(0.25, Enum.EasingStyle.Elastic), { CameraOffset = Vector3.zero }):Play()
end

local function land(swinger: Player, tool: Tool)
	local entry = Theme.Wearables[tool:GetAttribute("Cosmetic") or ""]
	local swing = if entry and entry.Swing then entry.Swing else DEFAULT_SWING
	local tip = tool:FindFirstChild("Tip", true) or tool:FindFirstChild("Handle")
	if not tip or not tip:IsA("BasePart") then
		return
	end

	local spot = Instance.new("Attachment")
	spot.WorldPosition = tip.Position
	spot.Parent = Workspace.Terrain
	Debris:AddItem(spot, 3)

	local spec = Theme.Sounds[swing.Sound]
	if spec and spec.Id ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = spec.Id
		sound.Volume = spec.Volume
		sound.PlaybackSpeed = 0.9 + math.random() * 0.2
		sound.RollOffMaxDistance = 80
		sound.Parent = spot
		sound:Play()
	end

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromHex(swing.Dust))
	dust.LightEmission = 0.4
	dust.Size = NumberSequence.new(0.6, 1.6)
	dust.Transparency = NumberSequence.new(0.3, 1)
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(4, 7)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = 6
	dust.Enabled = false
	dust.Parent = spot
	dust:Emit(14)

	if swinger == player and swing.Sound == "Thump" and swinger.Character then
		shake(swinger.Character)
	end
end

function Swing.start()
	CosmeticSwung.OnClientEvent:Connect(function(swinger: Player, tool: Tool)
		if typeof(tool) == "Instance" and tool:IsA("Tool") then
			task.delay(LAND_SECONDS, land, swinger, tool)
		end
	end)
end

return Swing
