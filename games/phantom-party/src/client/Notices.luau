-- Cards the server sends one player: a new level, a Moon Pass tier ready
-- to claim, a purchase arriving, the welcome on a first visit. Each kind
-- has its colour and its sound.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)
local Ui = require(script.Parent.Ui)

local Notice = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice") :: RemoteEvent

local Notices = {}

local KINDS = {
	Level = { Color = Ui.Colors.Gold, Sound = "LevelUp", Seconds = 5 },
	Pass = { Color = Ui.Colors.Gold, Sound = "LevelUp", Seconds = 6 },
	Purchase = { Color = Ui.Colors.Good, Sound = "CrateReveal", Seconds = 6 },
	Welcome = { Color = Ui.Colors.Accent, Sound = nil, Seconds = 12 },
	Info = { Color = Ui.Colors.Accent, Sound = nil, Seconds = 5 },
}

function Notices.start()
	Notice.OnClientEvent:Connect(function(message)
		if typeof(message) ~= "table" then
			return
		end
		local kind = KINDS[message.Kind] or KINDS.Info
		if kind.Sound then
			Sounds.play(kind.Sound)
		end
		Corner.note(tostring(message.Title or ""), message.Text, kind.Color, kind.Seconds)
	end)
end

return Notices
