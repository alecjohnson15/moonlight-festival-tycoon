-- Client entry point. The client draws the HUD, the night's sounds and
-- everything that moves on the plots; it never decides coins, ownership or
-- purchases.

local BuildEffects = require(script.BuildEffects)
local Hud = require(script.Hud)
local Motion = require(script.Motion)
local PlotActivity = require(script.PlotActivity)
local Sounds = require(script.Sounds)

Sounds.start()
Hud.mount()
PlotActivity.start()
Motion.start()
BuildEffects.start()
