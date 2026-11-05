-- Pets: every player's pet (their "Pet" attribute, set by the server from
-- what they wear) trots along beside them, drawn on each client. A pet is
-- only for show: it never touches anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Wearables = require(ReplicatedStorage:WaitForChild("Shared").World.Wearables)

local Pets = {}

type Pet = { Id: string, Model: Model, Position: Vector3, Facing: number }

local pets: { [Player]: Pet } = {}
local folder: Folder

local function remove(owner: Player)
	local pet = pets[owner]
	if pet then
		pet.Model:Destroy()
		pets[owner] = nil
	end
end

local function refresh(owner: Player)
	local id = owner:GetAttribute("Pet") or ""
	local pet = pets[owner]
	if pet and pet.Id == id then
		return
	end
	remove(owner)
	if id == "" then
		return
	end
	local model = Wearables.build(nil, id, "Pet")
	if not model then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model.Parent = folder
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	pets[owner] = { Id = id, Model = model, Position = if root then root.Position else Vector3.zero, Facing = 0 }
end

local function step(dt: number)
	local time = os.clock()
	for owner, pet in pets do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		-- A spot just behind and to the left of its owner, on the snow.
		local goal = (root.CFrame * CFrame.new(-3, 0, 3)).Position
		goal = Vector3.new(goal.X, 0, goal.Z)
		local distance = (goal - pet.Position).Magnitude
		if distance > 60 then
			pet.Position = goal
		else
			pet.Position = pet.Position:Lerp(goal, math.min(1, dt * 6))
		end
		local moving = distance > 0.6
		if moving then
			local direction = goal - pet.Position
			if direction.Magnitude > 0.05 then
				pet.Facing = math.atan2(-direction.X, -direction.Z)
			end
		end
		local hop = if moving then math.abs(math.sin(time * 10)) * 0.5 else 0
		local flying = pet.Id == "SnowOwl"
		local height = if flying then 6 + math.sin(time * 3) * 0.6 else hop
		pet.Model:PivotTo(CFrame.new(pet.Position + Vector3.new(0, height, 0)) * CFrame.Angles(0, pet.Facing, 0))
	end
end

function Pets.start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = Workspace
	local function watch(owner: Player)
		owner:GetAttributeChangedSignal("Pet"):Connect(function()
			refresh(owner)
		end)
		refresh(owner)
	end
	Players.PlayerAdded:Connect(watch)
	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerRemoving:Connect(remove)
	RunService.Heartbeat:Connect(step)
end

return Pets
