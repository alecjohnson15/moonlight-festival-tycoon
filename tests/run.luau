-- Runs the pure-logic test suite with Lune: `lune run tests/run`.
-- Modules under test use no Roblox APIs, so they load here unchanged.

local process = require("@lune/process")
local TestKit = require("./TestKit")

require("./Progression.spec")
require("./Config.spec")
require("./Saves.spec")
require("./RateLimiter.spec")

local failures = TestKit.run()
process.exit(if failures > 0 then 1 else 0)
