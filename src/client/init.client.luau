-- Client entry point. The client draws the HUD, the night's sounds,
-- everything that moves on the plots and the arena's fights; it never decides
-- coins, ownership, purchases or hits.

local Arena = require(script.Arena)
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
Arena.start()
