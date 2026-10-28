-- Client entry point. The client draws the HUD, the night's sounds,
-- everything that moves on the plots, pets, the wardrobe and the arena's
-- fights; it never decides coins, ownership, purchases or hits.

local Arena = require(script.Arena)
local BuildEffects = require(script.BuildEffects)
local Hud = require(script.Hud)
local Motion = require(script.Motion)
local Pets = require(script.Pets)
local PlotActivity = require(script.PlotActivity)
local Sounds = require(script.Sounds)
local Swing = require(script.Swing)
local Wardrobe = require(script.Wardrobe)

Sounds.start()
Hud.mount()
PlotActivity.start()
Motion.start()
BuildEffects.start()
Pets.start()
Swing.start()
Wardrobe.mount()
Arena.start()
