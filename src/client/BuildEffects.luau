-- Plays the build-up when something is bought: its parts rise out of the
-- ground from the bottom up and fade in, with a burst of sparks and, on the
-- player's own plot, a sound. A path tier's model is the whole path so far,
-- and the parts it keeps from the tier before (marked Kept) stay put, so
-- only what's new rises. The server builds everything in place and marks it
-- with BuiltAt; this only animates it on this client.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Motion = require(script.Parent.Motion)
local Sounds = require(script.Parent.Sounds)

-- Only things built this recently animate, so joining a server or streaming a
-- plot back in doesn't replay old builds.
local RECENT = 2
local DROP = 4
local SPREAD = 0.7
local RISE = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BuildEffects = {}

local player = Players.LocalPlayer

local function isMine(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current:GetAttribute("OwnerUserId") ~= nil then
			return current:GetAttribute("OwnerUserId") == player.UserId
		end
		current = current.Parent
	end
	return false
end

local function sparks(at: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(140, 90, 255))
	emitter.LightEmission = 1
	emitter.Parent = at
	emitter:Emit(50)
	Debris:AddItem(emitter, 2)
end

local function play(built: Instance)
	local parts = {}
	if built:IsA("BasePart") then
		table.insert(parts, built)
	end
	for _, descendant in built:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 and not descendant:GetAttribute("Kept") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		return
	end

	local low, high = math.huge, -math.huge
	for _, part in parts do
		low = math.min(low, part.Position.Y)
		high = math.max(high, part.Position.Y)
	end
	for _, part in parts do
		local cframe, transparency = part.CFrame, part.Transparency
		-- Parts that move on their own only fade, so they end up where the
		-- motion expects them.
		local rises = not Motion.moves(part)
		local delay = (cframe.Position.Y - low) / math.max(high - low, 1) * SPREAD
		part.Transparency = 1
		if rises then
			part.CFrame = cframe - Vector3.new(0, DROP, 0)
		end
		task.delay(delay, function()
			if part.Parent then
				local goal: { [string]: any } = { Transparency = transparency }
				if rises then
					goal.CFrame = cframe
				end
				TweenService:Create(part, RISE, goal):Play()
			end
		end)
	end

	local anchor = if built:IsA("Model") then built.PrimaryPart else nil
	sparks(anchor or parts[1])
	if isMine(built) then
		Sounds.play("Build")
	end
end

local function onAdded(instance: Instance)
	local builtAt = instance:GetAttribute("BuiltAt")
	if builtAt and Workspace:GetServerTimeNow() - builtAt < RECENT then
		-- Wait a frame so the whole build has arrived.
		task.defer(play, instance)
	end
end

function BuildEffects.start()
	local plots = Workspace:WaitForChild("Plots")
	plots.DescendantAdded:Connect(onAdded)
end

return BuildEffects
