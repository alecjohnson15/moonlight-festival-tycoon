-- The active theme pack. Change this one line to swap themes.
local pack = script.Parent.Parent.Themes.MoonlightFestival

-- The pack's data, plus its builders for upgrade models (Props), the world
-- around them (Scenery), the visitors and goods on the plots (Crowd), the
-- cosmetics players wear (Wearables), the PvP arena's look, names and
-- sounds (Arena), Ghost Catcher's booth and wisps (Activity), and each
-- player's own festival: decorations, name sign, board and trophy shelf
-- (Festival). The builders make Instances, so they live beside the data
-- rather than in it, and the tests can still load the data on its own.
local theme = require(pack)
theme.Props = require(pack.Props)
theme.Scenery = require(pack.Scenery)
theme.Crowd = require(pack.Crowd)
theme.Wearables = require(pack.Wearables)
theme.Arena = require(pack.Arena)
theme.Activity = require(pack.Activity)
theme.Festival = require(pack.Festival)
return theme
