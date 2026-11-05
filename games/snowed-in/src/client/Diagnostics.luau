-- Numbers for checking performance on a real device, shown at the bottom
-- of the Settings window: this device's frame rate (measured over the last
-- second), its ping, the monsters it is drawing, the base's structures,
-- and how long the server's monster step takes (Workspace attribute
-- "SimMs", from MonsterService). Nothing here is estimated: a number that
-- isn't measured yet shows as "-".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage:WaitForChild("Shared").Config.Balance)
local MonsterView = require(script.Parent.MonsterView)

local Diagnostics = {}

local fps: number? = nil

function Diagnostics.fps(): number?
	return fps
end

function Diagnostics.line(): string
	local ping = 0
	pcall(function()
		ping = Players.LocalPlayer:GetNetworkPing() * 1000
	end)
	local simMs = Workspace:GetAttribute("SimMs")
	return string.format(
		"Diagnostics: %s FPS · %d ms ping · %d monsters drawn · %d/%d builds · server step %s ms",
		if fps then tostring(math.floor(fps + 0.5)) else "-",
		math.floor(ping + 0.5),
		MonsterView.count(),
		Workspace:GetAttribute("Structures") or 0,
		Balance.Build.MaxStructures,
		if type(simMs) == "number" then string.format("%.2f", simMs) else "-"
	)
end

function Diagnostics.start()
	local frames, since = 0, os.clock()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - since >= 1 then
			fps = frames / (now - since)
			frames, since = 0, now
		end
	end)
end

return Diagnostics
