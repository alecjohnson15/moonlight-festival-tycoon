-- Team milestones (shared/Milestones): records each once per run and tells
-- every client to show its banner (Config/Features.Milestones).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Config.Features)
local Milestones = require(ReplicatedStorage.Shared.Milestones)
local Net = require(script.Parent.Net)
local RunStats = require(script.Parent.RunStats)

local Celebrate = {}

function Celebrate.milestone(id: string)
	local milestone = Milestones.ById[id]
	if not milestone or not Features.Milestones then
		return
	end
	if RunStats.milestone(id) then
		Net.fx("Milestone", { Id = id, Text = milestone.Text })
	end
end

return Celebrate
