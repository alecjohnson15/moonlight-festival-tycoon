-- Makes gathering feel right for this player's role and team: a Scout
-- holds the prompt on pines, rocks and the rest for less time (their Gather
-- Speed), and so does a team of one or two (shared/Assist). The server
-- allows for both (services/GatherService), so this is only the length of
-- the hold this player sees. It also hides "Take down" on structures this
-- player doesn't own (the server checks too).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assist = require(Shared.Assist)
local Roles = require(Shared.Config.Roles)
local Sounds = require(script.Parent.Sounds)

local Prompts = {}

local player = Players.LocalPlayer
local base: { [ProximityPrompt]: number } = setmetatable({}, { __mode = "k" }) :: any

local function speed(): number
	local role = Roles.ById[player:GetAttribute("Role") or ""]
	return role and role.GatherSpeed or 0
end

local function adjust(prompt: ProximityPrompt)
	if prompt:GetAttribute("Gather") ~= true then
		return
	end
	if not base[prompt] then
		base[prompt] = prompt.HoldDuration
	end
	prompt.HoldDuration = base[prompt] * Assist.holdScale(speed(), #Players:GetPlayers())
end

-- A structure's "Take down" prompt shows only to its owner, or to everyone
-- once the owner has left (Owner 0).
local function ownerOnly(prompt: ProximityPrompt)
	local function refresh()
		local owner = prompt:GetAttribute("Owner")
		prompt.Enabled = owner == 0 or owner == player.UserId
	end
	prompt:GetAttributeChangedSignal("Owner"):Connect(refresh)
	refresh()
end

local function watchBuilt(folder: Instance)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "TakeDown" then
			ownerOnly(descendant)
		end
	end
	folder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") and descendant.Name == "TakeDown" then
			ownerOnly(descendant)
		end
	end)
end

function Prompts.start()
	task.spawn(function()
		watchBuilt(Workspace:WaitForChild("Built"))
	end)
	ProximityPromptService.PromptShown:Connect(function(prompt)
		adjust(prompt)
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt:GetAttribute("Gather") == true then
			Sounds.play("Click", 0.8)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Gather") ~= true then
			Sounds.play("Click")
		end
	end)
end

return Prompts
