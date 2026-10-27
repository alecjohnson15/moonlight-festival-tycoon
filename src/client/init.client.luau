-- Client entry point. The client draws the HUD, animates plots and asks the
-- server for upgrades; it never decides coins, ownership or purchases.

local Hud = require(script.Hud)
local PlotActivity = require(script.PlotActivity)

Hud.mount()
PlotActivity.start()
