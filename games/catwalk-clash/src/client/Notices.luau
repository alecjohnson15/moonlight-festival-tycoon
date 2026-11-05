-- Turns the server's notices (rewards, Style Pass tiers, rank ups,
-- purchases, saved outfits, gentle "no"s) into corner toasts with a sound.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Ui)
local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)

local C = Ui.Colors

local Notices = {}

local STYLE = {
	Reward = { Color = C.Gold, Sound = nil },
	Tier = { Color = C.Gold, Sound = "LevelUp", Title = "Style Pass" },
	RankUp = { Color = C.Pink, Sound = "LevelUp", Title = "Rank up!" },
	Purchase = { Color = C.Green, Sound = "Purchase", Title = "Yours!" },
	Saved = { Color = C.Aqua, Sound = "Equip", Title = "Closet" },
	Deny = { Color = C.Red, Sound = "Deny", Title = "Not yet" },
	Info = { Color = C.Violet, Sound = nil, Title = "Catwalk Clash" },
}

function Notices.show(message: { [string]: any })
	local style = STYLE[message.Kind] or STYLE.Info
	local title = style.Title or ""
	if message.Kind == "Reward" then
		local parts = {}
		if (message.Sparkles or 0) > 0 then
			table.insert(parts, `+{Ui.sparkles(message.Sparkles)}`)
		end
		if (message.Xp or 0) > 0 then
			table.insert(parts, `+{message.Xp} XP`)
		end
		title = table.concat(parts, "   ")
		if title == "" then
			title = "Nice!"
		end
	end
	if style.Sound then
		Sounds.play(style.Sound)
	end
	Corner.toast(title, tostring(message.Text or ""), style.Color)
end

function Notices.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice") :: RemoteEvent
	remote.OnClientEvent:Connect(function(message)
		if type(message) == "table" then
			Notices.show(message)
		end
	end)
end

return Notices
