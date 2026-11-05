-- Makes gathering feel right for this player's role: a Scout holds the
-- prompt on pines, rocks and the rest for less time (their Gather Speed).
-- The server allows for it (services/GatherService), so this is only the
-- length of the hold this player sees.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roles = require(ReplicatedStorage:WaitForChild("Shared").Config.Roles)
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
	prompt.HoldDuration = base[prompt] * (1 - speed())
end

function Prompts.start()
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
