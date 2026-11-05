-- The game's own models (Config/People rivals) who fill the bracket when a
-- server is too quiet for a real show, so one player can still play a full
-- round. Each rival dresses for the theme (shared/RivalStyle), using only
-- free pieces, and walks like a player does. Matches against rivals move a
-- player's Style Score half as much.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local People = require(Shared.Config.People)
local Palette = require(Shared.Config.Palette)
local RivalStyle = require(Shared.RivalStyle)
local Look = require(Shared.Look)
local Kit = require(Shared.Build.Kit)
local LookService = require(script.Parent.LookService)

local RivalService = {}

export type Rival = {
	Info: any,
	Look: Look.Look,
	Model: Model,
	-- True when Roblox couldn't make a rig and a simple figure stands in.
	Figure: boolean,
	Tracks: { [string]: AnimationTrack },
}

-- Roblox's own default R15 animations, which every game may use.
local ANIMATIONS = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if not folder or not folder.Parent then
		folder = Kit.folder("Rivals", workspace)
	end
	return folder :: Folder
end

local function nameTag(model: Model, adornee: BasePart, name: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(180, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = name
	label.Parent = gui
	local tag = Instance.new("TextLabel")
	tag.Position = UDim2.fromScale(0, 0.6)
	tag.Size = UDim2.fromScale(1, 0.4)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.GothamBold
	tag.TextScaled = true
	tag.TextColor3 = Color3.fromRGB(255, 190, 240)
	tag.Text = "Studio Model"
	tag.Parent = gui
	for _, text in { label, tag } do
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(40, 10, 50)
		stroke.Parent = text
	end
	gui.Parent = model
end

-- A plain figure for when no rig can be made: a dressed-up mannequin.
local function figure(name: string, look: Look.Look): Model
	local model = Kit.model(name)
	local skin = Palette.skin(look.Skin)
	local top = Palette.resolve(look.Top.C)
	local bottom = Palette.resolve(look.Bottom.C)
	local root = Kit.part(model, {
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(0, 0, 0),
		Transparency = 1,
		CanCollide = false,
	})
	model.PrimaryPart = root
	Kit.part(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(0, 2.1, 0),
		Color = skin,
	})
	Kit.part(model, { Name = "Body", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(0, 0.4, 0), Color = top })
	Kit.part(model, { Name = "Legs", Size = Vector3.new(1.8, 2, 0.9), CFrame = CFrame.new(0, -1.6, 0), Color = bottom })
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
		end
	end
	return model
end

local function load(rival: Rival)
	local humanoid = rival.Model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			rival.Tracks[name] = track
		end
	end
	if rival.Tracks.Idle then
		rival.Tracks.Idle:Play()
	end
end

-- count different rivals, picked at random.
function RivalService.pick(count: number, rng: Random): { any }
	local pool = table.clone(People.Rivals)
	local picked = {}
	while #picked < count and #pool > 0 do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return picked
end

-- Dresses a rival for a theme and puts them in the world at cframe.
function RivalService.spawn(info: any, theme: any, rng: Random, cframe: CFrame): Rival
	local look = RivalStyle.dress(info, theme, function()
		return rng:NextNumber()
	end)
	local model = LookService.makeRig(info.Name, look)
	local rival: Rival =
		{ Info = info, Look = look, Model = model or figure(info.Name, look), Figure = model == nil, Tracks = {} }
	local root = rival.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		nameTag(rival.Model, (rival.Model:FindFirstChild("Head") or root) :: BasePart, info.Name)
	end
	rival.Model:SetAttribute("Rival", info.Id)
	rival.Model.Parent = getFolder()
	RivalService.place(rival, cframe, true)
	load(rival)
	return rival
end

-- Moves a rival to cframe; anchored stops them where they are.
function RivalService.place(rival: Rival, cframe: CFrame, anchored: boolean)
	local model = rival.Model
	if rival.Figure then
		model:PivotTo(cframe * CFrame.new(0, 0.2, 0))
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
	end
	model:PivotTo(cframe)
	if root then
		root.Anchored = anchored
	end
end

-- Walks a rival to target over about seconds.
function RivalService.strut(rival: Rival, target: CFrame, speed: number, seconds: number)
	if rival.Figure then
		local start = rival.Model:GetPivot()
		local value = Instance.new("CFrameValue")
		value.Value = start
		value.Changed:Connect(function(cframe)
			rival.Model:PivotTo(cframe)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(seconds * 0.7, Enum.EasingStyle.Linear), {
			Value = target * CFrame.new(0, 0.2, 0),
		})
		tween.Completed:Connect(function()
			value:Destroy()
		end)
		tween:Play()
		return
	end
	local humanoid = rival.Model:FindFirstChildOfClass("Humanoid")
	local root = rival.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	root.Anchored = false
	humanoid.WalkSpeed = speed
	humanoid:MoveTo(target.Position)
	if rival.Tracks.Walk then
		rival.Tracks.Walk:Play(0.2)
		rival.Tracks.Walk:AdjustSpeed(speed / 16)
	end
	task.delay(seconds, function()
		if rival.Tracks.Walk then
			rival.Tracks.Walk:Stop(0.2)
		end
	end)
end

-- Stops the walk animation.
function RivalService.halt(rival: Rival)
	if rival.Tracks.Walk then
		rival.Tracks.Walk:Stop(0.2)
	end
end

function RivalService.despawn(rival: Rival)
	for _, track in rival.Tracks do
		track:Stop()
	end
	rival.Model:Destroy()
end

function RivalService.clear()
	if folder then
		folder:ClearAllChildren()
	end
end

return RivalService
