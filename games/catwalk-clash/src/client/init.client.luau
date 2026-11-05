-- Client entry point. The client draws the HUD and menus, the wardrobe, the
-- theme vote, the runway show with its camera and effects, and plays the
-- music; it never decides Sparkles, ownership, purchases, votes or winners.

local Camera = require(script.Camera)
local Corner = require(script.Corner)
local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Menus = require(script.Menus)
local Notices = require(script.Notices)
local Show = require(script.Show)
local Sounds = require(script.Sounds)
local State = require(script.State)
local ThemeVote = require(script.ThemeVote)
local Tips = require(script.Tips)
local Ui = require(script.Ui)
local Wardrobe = require(script.Wardrobe)

State.start()
Sounds.start()
Camera.start()
Effects.start()
Corner.mount()
Hud.mount()
Notices.start()
ThemeVote.mount()
Wardrobe.mount()
Menus.mount()
Show.mount()
Tips.mount()

local C = Ui.Colors
Hud.addButton(1, "👗", "Wardrobe", C.Pink, function()
	if Wardrobe.isOpen() then
		Wardrobe.close()
	else
		Wardrobe.open()
	end
end)
Hud.addButton(2, "🧥", "Closet", C.Violet, function()
	Menus.toggle("Closet")
end)
Hud.addButton(3, "🛍", "Shop", C.Aqua, function()
	Menus.toggle("Shop")
end)
Hud.addButton(4, "⭐", "Pass", C.Gold, function()
	Menus.toggle("Pass")
end)
Hud.addButton(5, "👑", "Profile", C.Panel3, function()
	Menus.toggle("Profile")
end)
Hud.addButton(6, "⚙", "Settings", C.Panel2, function()
	Menus.toggle("Settings")
end)
