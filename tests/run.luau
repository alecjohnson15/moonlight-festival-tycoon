-- Runs the test suite with Lune: `lune run tests/run`. Most modules under
-- test use no Roblox APIs, so they load here unchanged; the theme's builders
-- load through RobloxLoader, which supplies Lune's Roblox library.

local process = require("@lune/process")
local TestKit = require("./TestKit")

require("./Progression.spec")
require("./Earnings.spec")
require("./Config.spec")
require("./Look.spec")
require("./Saves.spec")
require("./RateLimiter.spec")
require("./Wardrobe.spec")
require("./Arena.spec")
require("./Activity.spec")
require("./Festival.spec")
require("./Parade.spec")
require("./Analytics.spec")

local failures = TestKit.run()
process.exit(if failures > 0 then 1 else 0)
