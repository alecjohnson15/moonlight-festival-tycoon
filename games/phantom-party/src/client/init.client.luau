-- Client entry point. The client draws the HUD, the role card, the map
-- vote, the round buttons, the effects, the lighting and music of each
-- place, the menus (boutique, items, crates, Moon Pass, trades, emotes,
-- help), the spectator bar, first-time tips, the leads notebook and
-- captions for sounds. It never decides roles, hits, coins,
-- ownership, crate results or trades: it asks the server and shows the
-- answer.

local StarterGui = game:GetService("StarterGui")

local Atmosphere = require(script.Atmosphere)
local Captions = require(script.Captions)
local ChatTags = require(script.ChatTags)
local Controls = require(script.Controls)
local Corner = require(script.Corner)
local Crates = require(script.Crates)
local Effects = require(script.Effects)
local Emotes = require(script.Emotes)
local Hud = require(script.Hud)
local Inventory = require(script.Inventory)
local Leads = require(script.Leads)
local Motion = require(script.Motion)
local Notices = require(script.Notices)
local PassPanel = require(script.PassPanel)
local RoleCard = require(script.RoleCard)
local Settings = require(script.Settings)
local Shop = require(script.Shop)
local Sounds = require(script.Sounds)
local Spectate = require(script.Spectate)
local State = require(script.State)
local Tips = require(script.Tips)
local TradePanel = require(script.TradePanel)
local Vote = require(script.Vote)

-- Role tools are drawn with the round buttons, never from the backpack.
task.spawn(function()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end)

Corner.start()
Sounds.start()
Hud.start()
Atmosphere.start()
Motion.start()
Effects.start()
RoleCard.start()
Vote.start()
Controls.start()
Leads.start()
Shop.start()
Inventory.start()
Crates.start()
PassPanel.start()
TradePanel.start()
Emotes.start()
Settings.start()
Spectate.start()
ChatTags.start()
Notices.start()
Tips.start()
Captions.start()
-- Last, so every screen is listening when the first snapshot arrives.
State.start()
