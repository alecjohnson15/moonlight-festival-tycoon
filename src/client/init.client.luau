-- Client entry point. The client draws the HUD, the guide to what's next,
-- the night's sounds (with the ambience of each place), everything that
-- moves on the plots and in the woods, pets, the wardrobe, the festival
-- board, the arena's fights, Ghost Catcher's wisps and the Moonlight
-- Parade; it never decides coins, ownership, purchases, hits or catches.

local Activity = require(script.Activity)
local Arena = require(script.Arena)
local BuildEffects = require(script.BuildEffects)
local FestivalBoard = require(script.FestivalBoard)
local Guide = require(script.Guide)
local Hud = require(script.Hud)
local Motion = require(script.Motion)
local Parade = require(script.Parade)
local Pets = require(script.Pets)
local PlotActivity = require(script.PlotActivity)
local SoundZones = require(script.SoundZones)
local Sounds = require(script.Sounds)
local Swing = require(script.Swing)
local Wardrobe = require(script.Wardrobe)

Sounds.start()
SoundZones.start()
Hud.mount()
Guide.mount()
PlotActivity.start()
Parade.start()
Motion.start()
BuildEffects.start()
Pets.start()
Swing.start()
Wardrobe.mount()
FestivalBoard.mount()
Arena.start()
Activity.start()
