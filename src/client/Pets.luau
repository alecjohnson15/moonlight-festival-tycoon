-- Draws every player's pet on this client: it floats beside them, bobbing,
-- and drifts after them as they move. The server only says which pet each
-- player has, through their WearPet attribute, so pets cost the server nothing
-- and move smoothly. Like the plot activity, this changes nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage:WaitForChild("Shared").Config.Theme)

-- Where a pet floats, from its owner's root part: off their right shoulder,
-- a little behind.
local OFFSET = CFrame.new(2.6, 1.2, 2.2)
local BOB_HEIGHT = 0.35
local FOLLOW_SPEED = 6
-- Pets further than this from the camera aren't moved, to save work.
local DRAW_DISTANCE = 300

type Pet = {
	Id: string,
	Model: Model,
	Frame: CFrame?,
	Phase: number,
}

local Pets = {}

local folder = Instance.new("Folder")
folder.Name = "Pets"
local pets: { [Player]: Pet } = {}

local function build(id: string): Model?
	local entry = Theme.Wearables[id]
	if not entry then
		return nil
	end
	local model = entry.Build()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function update(player: Player)
	local id = player:GetAttribute("WearPet")
	local current = pets[player]
	if current and current.Id == id then
		return
	end
	if current then
		current.Model:Destroy()
		pets[player] = nil
	end
	if type(id) == "string" then
		local model = build(id)
		if model then
			pets[player] = { Id = id, Model = model, Frame = nil, Phase = math.random() * math.pi * 2 }
		end
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("WearPet"):Connect(function()
		update(player)
	end)
	update(player)
end

local function onRenderStep(dt: number)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	for player, pet in pets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not camera or (root.Position - camera.CFrame.Position).Magnitude > DRAW_DISTANCE then
			pet.Model.Parent = nil
			pet.Frame = nil
			continue
		end
		local _, yaw = root.CFrame:ToOrientation()
		local bob = math.sin(now * 2.2 + pet.Phase) * BOB_HEIGHT
		local target = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0) * OFFSET * CFrame.new(0, bob, 0)
		pet.Frame = if pet.Frame then pet.Frame:Lerp(target, 1 - math.exp(-dt * FOLLOW_SPEED)) else target
		pet.Model:PivotTo(pet.Frame :: CFrame)
		pet.Model.Parent = folder
	end
end

function Pets.start()
	folder.Parent = Workspace
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local pet = pets[player]
		if pet then
			pet.Model:Destroy()
			pets[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.RenderStepped:Connect(onRenderStep)
end

return Pets
