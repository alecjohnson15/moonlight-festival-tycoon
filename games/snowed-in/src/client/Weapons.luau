-- Fighting: clicking (or tapping) with a weapon out turns the player to
-- face where they aimed, draws the swing or the shot straight away, and
-- tells the server where they aimed. The server decides what was hit
-- (shared/Combat) and reports it back as a "Shot" effect. On a gamepad,
-- or with nothing under the cursor, the player aims straight ahead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.Weapons)
local BuildMode = require(script.Parent.BuildMode)
local Effects = require(script.Parent.Effects)

local Weapons = {}

local player = Players.LocalPlayer
local lastFired: { [string]: number } = {}

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where the player is aiming, on the ground.
local function aimPoint(range: number): Vector3?
	local me = root()
	if not me then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local lastInput = UserInputService:GetLastInputType()
	local gamepad = lastInput.Name:sub(1, 7) == "Gamepad"
	if camera and not gamepad then
		local location = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(location.X, location.Y)
		-- Where the ray meets the ground (y = 0), or the snow it hits first.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
		local point = if hit then hit.Position else nil
		if not point and ray.Direction.Y < -0.01 then
			point = ray.Origin + ray.Direction * (-ray.Origin.Y / ray.Direction.Y)
		end
		if point then
			local flat = Vector3.new(point.X - me.Position.X, 0, point.Z - me.Position.Z)
			if flat.Magnitude > 0.5 then
				local reach = math.min(flat.Magnitude, range)
				return me.Position + flat.Unit * reach
			end
		end
	end
	local look = me.CFrame.LookVector * Vector3.new(1, 0, 1)
	return me.Position + (if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis) * range
end

-- Turns the character to face the aim, so swings land where they look.
local function face(point: Vector3)
	local me = root()
	if not me then
		return
	end
	local flat = Vector3.new(point.X, me.Position.Y, point.Z)
	if (flat - me.Position).Magnitude > 0.5 then
		me.CFrame = CFrame.lookAt(me.Position, flat)
	end
end

-- A quick swing of the held tool's grip, for the torch and the rest.
local function swing(tool: Tool)
	local original = tool.Grip
	tool.Grip = original * CFrame.Angles(math.rad(-70), 0, 0)
	local value = Instance.new("CFrameValue")
	value.Value = tool.Grip
	value.Changed:Connect(function(cframe)
		if tool.Parent then
			tool.Grip = cframe
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Value = original })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
end

local function fire(tool: Tool)
	local weaponId = tool:GetAttribute("Weapon")
	local weapon = WeaponConfig.ById[weaponId or ""]
	if not weapon or player:GetAttribute("Frozen") == true or BuildMode.isOpen() then
		return
	end
	local time = os.clock()
	if time - (lastFired[weapon.Id] or 0) < weapon.Cooldown then
		return
	end
	lastFired[weapon.Id] = time
	local me = root()
	local point = aimPoint(weapon.Range)
	if not me or not point then
		return
	end
	face(point)
	swing(tool)
	Effects.shot(weapon.Id, me.Position, point)
	ReplicatedStorage.Remotes.Fire:FireServer(weapon.Id, point)
end

local function watch(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Weapon") == nil or tool:GetAttribute("Watched") then
		return
	end
	tool:SetAttribute("Watched", true)
	tool.Activated:Connect(function()
		fire(tool)
	end)
end

local function onCharacter(character: Model)
	character.ChildAdded:Connect(watch)
	for _, child in character:GetChildren() do
		watch(child)
	end
end

function Weapons.start()
	-- A new backpack comes with every new character.
	local function watchBackpack(backpack: Instance)
		if backpack:IsA("Backpack") then
			backpack.ChildAdded:Connect(watch)
			for _, child in backpack:GetChildren() do
				watch(child)
			end
		end
	end
	player.ChildAdded:Connect(watchBackpack)
	for _, child in player:GetChildren() do
		watchBackpack(child)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return Weapons
