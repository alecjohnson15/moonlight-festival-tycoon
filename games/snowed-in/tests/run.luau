-- Runs the test suite with Lune, from this game's folder: `lune run tests/run`.
-- Modules load through RobloxLoader, which gives them `script` paths and
-- Lune's Roblox library, the way Roblox would.

local process = require("@lune/process")
local TestKit = require("./TestKit")

require("./Logic.spec")
require("./Monsters.spec")
require("./Profile.spec")
require("./World.spec")
require("./Config.spec")
require("./Balance.spec")
require("./Radio.spec")
require("./Progress.spec")
require("./Pacing.spec")

local failures = TestKit.run()
process.exit(if failures > 0 then 1 else 0)
