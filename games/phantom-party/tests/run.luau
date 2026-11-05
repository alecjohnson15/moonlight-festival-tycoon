-- Runs the test suite with Lune, from the games/phantom-party folder:
-- `lune run tests/run`. Modules load through RobloxLoader, which supplies
-- Lune's Roblox library and maps script.Parent paths onto src/.

local process = require("@lune/process")
local TestKit = require("./TestKit")

require("./Rules.spec")
require("./Saves.spec")
require("./Config.spec")
require("./Fairness.spec")
require("./Evidence.spec")
require("./Sims.spec")
require("./Trades.spec")
require("./Onboarding.spec")
require("./Look.spec")
require("./Compile.spec")

local failures = TestKit.run()
process.exit(if failures > 0 then 1 else 0)
