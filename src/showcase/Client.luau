-- The showcase build's client half (see Server.luau): H hides everything
-- on the screen, the game's own panels and Roblox's buttons and chat, for
-- clean store screenshots, and H again brings it all back. Labels over the
-- plots stay, since they're part of the festival. It also keeps the
-- Moonlight Parade's cards in step with the showcase's parade times.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ParadeConfig = require(Shared.Config.Parade)
local Plan = require(Shared.ShowcasePlan)

local KEY = Enum.KeyCode.H

local Showcase = {}

local player = Players.LocalPlayer
-- The screens hidden, while they are.
local hidden: { ScreenGui }? = nil

local function setRobloxShown(shown: boolean)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, shown)
	-- Roblox's own buttons along the top; refused in a few places, which is
	-- fine for a screenshot.
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", shown)
	end)
end

local function toggle()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	if hidden then
		for _, gui in hidden do
			gui.Enabled = true
		end
		hidden = nil
		setRobloxShown(true)
		return
	end
	local screens = {}
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(screens, gui)
		end
	end
	hidden = screens
	setRobloxShown(false)
end

function Showcase.start()
	ParadeConfig.FirstSeconds = Plan.ParadeFirstSeconds
	ParadeConfig.IntervalSeconds = Plan.ParadeIntervalSeconds
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == KEY then
			toggle()
		end
	end)
end

return Showcase
