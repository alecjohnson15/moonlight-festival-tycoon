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

	it("upgrades a version 1 save to version 2 without touching coins, items or stats", function()
		local old = {
			SchemaVersion = 1,
			Coins = 1234,
			Xp = 5678,
			Items = { ["7-1"] = "mask_fox", ["7-2"] = "blade_neon" },
			NextUid = 3,
			Equipped = { Mask = "mask_fox" },
			Pass = { Season = "s1", Xp = 900, Free = { ["1"] = true }, Premium = {} },
			Stats = { Rounds = 40, Wins = 12, Trades = 3 },
			Settings = { Music = false },
			Onboarding = 5,
			Sessions = 9,
		}
		local save = Migrations.run(old) :: any
		expect(save.SchemaVersion).toBe(2)
		expect(save.Coins).toBe(1234)
		expect(save.Xp).toBe(5678)
		expect(save.Items["7-1"]).toBe("mask_fox")
		expect(save.Items["7-2"]).toBe("blade_neon")
		expect(save.Equipped.Mask).toBe("mask_fox")
		expect(save.Pass.Free["1"]).toBe(true)
		expect(save.Stats.Wins).toBe(12)
		expect(save.Settings.Music).toBe(false)
		expect(save.Settings.ReduceMotion).toBe(false)
		expect(save.Settings.Captions).toBe(false)
		expect(save.Stats.Wisps).toBe(0)
		expect(next(save.Tips)).toBe(nil)
		expect(next(save.PendingTrades)).toBe(nil)
		expect(#save.AppliedTrades).toBe(0)
		expect(next(save.Mastery)).toBe(nil)
	end)

	it("keeps tips and trade marks already in a version 2 save", function()
		local save = Migrations.run({
			SchemaVersion = 2,
			Tips = { phantom_draw = true },
			PendingTrades = { ["t-9"] = true },
		}) :: any
		expect(save.Tips.phantom_draw).toBe(true)
		expect(save.PendingTrades["t-9"]).toBe(true)
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
