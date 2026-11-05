-- The save format: new players get a full save, old saves gain new fields,
-- and a save from a newer server is refused rather than overwritten.

local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Migrations = Loader.require("src/server/Lib/Migrations")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("saves", function()
	it("makes a full save for a new player", function()
		local save = Migrations.run(nil) :: any
		expect(save.SchemaVersion).toBe(Migrations.CURRENT_VERSION)
		expect(save.Coins).toBe(0)
		expect(type(save.Items)).toBe("table")
		expect(save.Stats.Wins).toBe(0)
		expect(save.Settings.Music).toBe(true)
	end)

	it("fills in fields an older save lacks without touching the rest", function()
		local save = Migrations.run({ SchemaVersion = 1, Coins = 55, Stats = { Wins = 4 } }) :: any
		expect(save.Coins).toBe(55)
		expect(save.Stats.Wins).toBe(4)
		expect(save.Stats.Trades).toBe(0)
		expect(type(save.Pass.Free)).toBe("table")
	end)

	it("refuses a save from a newer version", function()
		local save, err = Migrations.run({ SchemaVersion = Migrations.CURRENT_VERSION + 1 })
		expect(save).toBe(nil)
		expect(err).toBe("FutureVersion")
		expect(Migrations.isFuture({ SchemaVersion = Migrations.CURRENT_VERSION + 1 })).toBe(true)
	end)

	it("runs migration steps in order", function()
		local steps = {
			function(data)
				data.Added = 1
			end,
			function(data)
				data.Added += 1
			end,
		}
		local data = Migrations.migrate({ SchemaVersion = 1 }, steps, 3) :: any
		expect(data.Added).toBe(2)
		expect(data.SchemaVersion).toBe(3)
		local _, err = Migrations.migrate({ SchemaVersion = 1 }, {}, 2)
		expect(err ~= nil).toBe(true)
	end)

	it("rejects junk", function()
		local save, err = Migrations.run("nope")
		expect(save).toBe(nil)
		expect(err ~= nil).toBe(true)
	end)
end)

return nil
