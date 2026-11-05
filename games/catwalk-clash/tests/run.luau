-- Runs the test suite with Lune: `lune run tests/run` from the game's folder.
-- Modules load through RobloxLoader, which supplies Lune's Roblox library,
-- so the same files Roblox runs are tested here unchanged.

local process = require("@lune/process")
local TestKit = require("./TestKit")

require("./Bracket.spec")
require("./Voting.spec")
require("./Wardrobe.spec")
require("./World.spec")
require("./Judge.spec")
require("./Progress.spec")

local failures = TestKit.run()
process.exit(if failures > 0 then 1 else 0)
