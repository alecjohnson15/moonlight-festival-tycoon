-- Signs that show through the blizzard: an ice cube over every frozen
-- friend (so they get thawed), a radio over whoever is carrying a part,
-- and the four radio parts' landmarks once the team has made Signal
-- Flares. A Scout's flare lights up every monster, radio part and supply
-- crate near them for a few seconds, for everyone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local MonsterView = require(script.Parent.MonsterView)
local UI = require(script.Parent.UI)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration

local Markers = {}

local player = Players.LocalPlayer
local folder: Folder
local playerTags: { [Player]: BillboardGui } = {}
local landmarkTags: { [string]: BillboardGui } = {}

-- A sign at a spot or over a part, seen through walls and fog.
local function tag(text: string, color: Color3, size: number?, adornee: Instance?, position: Vector3?): BillboardGui
	local board = Instance.new("BillboardGui")
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Size = UDim2.fromOffset(size or 120, 40)
	board.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	if adornee then
		board.Adornee = adornee
	else
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Position = position or Vector3.zero
		anchor.Parent = folder
		board.Adornee = anchor
		board.Destroying:Connect(function()
			anchor:Destroy()
		end)
	end
	UI.label(board, text, {
		Size = UDim2.fromScale(1, 1),
		Font = UI.Title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
	})
	board.Parent = folder
	return board
end

local function refreshPlayers()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local head = character and character:FindFirstChild("Head")
		local frozen = other:GetAttribute("Frozen") == true
		local carrying = other:GetAttribute("Carrying") or ""
		local text = if frozen then "🧊 Thaw me!" elseif carrying ~= "" then "📻" else nil
		local existing = playerTags[other]
		if text and head and other ~= player then
			if not existing or existing.Adornee ~= head then
				if existing then
					existing:Destroy()
				end
				existing = tag(text, if frozen then UI.Colors.Ice else UI.Colors.Gold, 120, head)
				existing.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
				playerTags[other] = existing
			end
			local label = existing:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = text
				label.TextColor3 = if frozen then UI.Colors.Ice else UI.Colors.Gold
			end
		elseif existing then
			existing:Destroy()
			playerTags[other] = nil
		end
	end
end

local function refreshLandmarks()
	local flares = State:GetAttribute("Upgrade_SignalFlares") == true
	for _, landmark in Map.Landmarks do
		local state = State:GetAttribute(`Part_{landmark.Part}`) or "Frozen"
		local want = flares and state == "Frozen"
		local existing = landmarkTags[landmark.Id]
		if want and not existing then
			local board = tag(
				`📻 {landmark.PartName}\n{landmark.Name}`,
				UI.Colors.Gold,
				170,
				nil,
				Vector3.new(landmark.At[1], 14, landmark.At[2])
			)
			board.Size = UDim2.fromOffset(170, 44)
			landmarkTags[landmark.Id] = board
		elseif not want and existing then
			existing:Destroy()
			landmarkTags[landmark.Id] = nil
		end
	end
end

-- A Scout's flare: lights up what's near them for a few seconds.
local function flare(data: any)
	if typeof(data.Position) ~= "Vector3" then
		return
	end
	local center = data.Position :: Vector3
	local radius = data.Radius or 120
	local seconds = data.Seconds or 12
	local made = {}
	local function near(position: Vector3): boolean
		return (Vector3.new(position.X, 0, position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= radius
	end
	for _, monster in MonsterView.all() do
		if near(monster.Position) then
			table.insert(made, tag("❗", UI.Colors.Bad, 40, nil, monster.Position + Vector3.new(0, 4, 0)))
		end
	end
	for _, crate in CollectionService:GetTagged("Crate") do
		if crate:IsA("Model") and crate:IsDescendantOf(Workspace) and near(crate:GetPivot().Position) then
			table.insert(made, tag("📦 Crate", UI.Colors.Gold, 90, nil, crate:GetPivot().Position))
		end
	end
	local parts = Workspace:FindFirstChild("RadioParts")
	if parts then
		for _, model in parts:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("State") ~= "Fitted" and near(model:GetPivot().Position) then
				table.insert(
					made,
					tag(
						`📻 {model:GetAttribute("PartName") or "Radio part"}`,
						UI.Colors.Gold,
						140,
						nil,
						model:GetPivot().Position
					)
				)
			end
		end
	end
	task.delay(seconds, function()
		for _, board in made do
			board:Destroy()
		end
	end)
end

function Markers.start()
	folder = Instance.new("Folder")
	folder.Name = "Markers"
	folder.Parent = Workspace
	State.AttributeChanged:Connect(function(name)
		if name:sub(1, 5) == "Part_" or name == "Upgrade_SignalFlares" then
			refreshLandmarks()
		end
	end)
	refreshLandmarks()
	Players.PlayerRemoving:Connect(function(other)
		local existing = playerTags[other]
		if existing then
			existing:Destroy()
			playerTags[other] = nil
		end
	end)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx").OnClientEvent:Connect(function(kind, data)
		if kind == "Flare" and type(data) == "table" then
			flare(data)
		end
	end)
	task.spawn(function()
		while true do
			refreshPlayers()
			task.wait(0.5)
		end
	end)
end

return Markers
