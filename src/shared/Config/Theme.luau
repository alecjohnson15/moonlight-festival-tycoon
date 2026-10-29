-- The active theme pack. Change this one line to swap themes.
local pack = script.Parent.Parent.Themes.MoonlightFestival

-- The pack's data, plus its builders for upgrade models (Props), the world
-- around them (Scenery), the visitors and goods on the plots (Crowd) and the
-- cosmetics players wear (Wearables). The builders make Instances, so they
-- live beside the data rather than in it, and the tests can still load the
-- data on its own.
local theme = require(pack)
theme.Props = require(pack.Props)
theme.Scenery = require(pack.Scenery)
theme.Crowd = require(pack.Crowd)
theme.Wearables = require(pack.Wearables)
return theme
