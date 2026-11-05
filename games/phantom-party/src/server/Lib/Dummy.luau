-- Practice dummies: stand-in party guests for a lone tester in Studio, so
-- every role can be tried without a second player. A dummy is a plain
-- blocky character that strolls between the map's spawn points. It never
-- tags, zaps or picks anything up.

local Players = game:GetService("Players")

local Dummy = {}

Dummy.NAMES = { "Mannequin Mabel", "Dummy Dot", "Puppet Pip", "Waxwork Walter", "Ragdoll Rue", "Scarecrow Sid" }

local SKIN = Color3.fromRGB(234, 196, 160)
local SUITS = {
	Color3.fromRGB(123, 44, 191),
	Color3.fromRGB(46, 196, 182),
	Color3.fromRGB(215, 38, 61),
	Color3.fromRGB(58, 134, 255),
	Color3.fromRGB(255, 140, 26),
	Color3.fromRGB(46, 158, 91),
}

local function part(model: Model, name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function attach(parent: BasePart, name: string, position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent
end

-- A blocky character built by hand, for when Roblox can't make one.
local function handBuilt(index: number): Model
	local model = Instance.new("Model")
	local suit = SUITS[(index - 1) % #SUITS + 1]
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), suit)
	root.Transparency = 1
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), suit)
	local head = part(model, "Head", Vector3.new(2, 1, 1), SKIN)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	attach(head, "FaceFrontAttachment", Vector3.new(0, 0, -0.6))
	attach(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	local limbs = {
		{ "Left Arm", Vector3.new(-1.5, 0, 0), SKIN },
		{ "Right Arm", Vector3.new(1.5, 0, 0), SKIN },
		{ "Left Leg", Vector3.new(-0.5, -2, 0), Color3.fromRGB(40, 36, 52) },
		{ "Right Leg", Vector3.new(0.5, -2, 0), Color3.fromRGB(40, 36, 52) },
	}
	root.CFrame = CFrame.new(0, 3, 0)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	for _, limb in limbs do
		local piece = part(model, limb[1], Vector3.new(1, 2, 1), limb[3])
		piece.CFrame = root.CFrame * CFrame.new(limb[2])
	end
	for _, piece in model:GetChildren() do
		if piece:IsA("BasePart") and piece ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = piece
			weld.Parent = piece
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- A new dummy, standing at cframe.
function Dummy.new(index: number, cframe: CFrame): Model
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local suit = SUITS[(index - 1) % #SUITS + 1]
		description.TorsoColor = suit
		description.LeftArmColor = SKIN
		description.RightArmColor = SKIN
		description.HeadColor = SKIN
		description.LeftLegColor = Color3.fromRGB(40, 36, 52)
		description.RightLegColor = Color3.fromRGB(40, 36, 52)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		model = handBuilt(index)
	end
	model.Name = Dummy.NAMES[(index - 1) % #Dummy.NAMES + 1]
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.WalkSpeed = 9
	model:PivotTo(cframe)
	model:SetAttribute("Dummy", true)
	return model
end

-- Walks the dummy from point to point until it's removed or stopped.
function Dummy.wander(model: Model, points: { BasePart }, keepGoing: () -> boolean)
	task.spawn(function()
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		while model.Parent and humanoid and keepGoing() do
			if #points > 0 and humanoid.WalkSpeed > 0 then
				local target = points[math.random(1, #points)]
				humanoid:MoveTo(target.Position)
			end
			task.wait(math.random(40, 80) / 10)
		end
	end)
end

return Dummy
