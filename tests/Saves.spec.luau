-- Save schema, session locks and the receipt ledger: the pieces that decide
-- whether progress and purchases survive retries, crashes and server hops.

local TestKit = require("./TestKit")
local Migrations = require("../src/server/Lib/Migrations")
local ReceiptLedger = require("../src/server/Lib/ReceiptLedger")
local SessionLock = require("../src/server/Lib/SessionLock")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Migrations", function()
	it("creates a current save for a new player", function()
		local data = Migrations.run(nil)
		assert(data)
		expect(data.SchemaVersion).toBe(Migrations.CURRENT_VERSION)
		expect(data.Coins).toBe(0)
		expect(data.Stats.ServeCount).toBe(0)
	end)

	it("fills fields an older save is missing and keeps the rest", function()
		local data = Migrations.run({ SchemaVersion = 1, Coins = 42, Owned = { starter_stall = true } })
		assert(data)
		expect(data.Coins).toBe(42)
		expect(data.Owned.starter_stall).toBe(true)
		expect(data.Stats.ServeCount).toBe(0)
		expect(data.Receipts.Order).toEqual({})
		expect(data.Activity.Best).toBe(0)
		expect(data.Activity.Rounds).toBe(0)
	end)

	it("refuses a save written by a newer server", function()
		local stored = { SchemaVersion = Migrations.CURRENT_VERSION + 1, Coins = 5 }
		local data, err = Migrations.run(stored)
		expect(data).toBe(nil)
		expect(err).toBe("FutureVersion")
		expect(Migrations.isFuture(stored)).toBe(true)
		expect(Migrations.isFuture({ SchemaVersion = 1 })).toBe(false)
		expect(Migrations.isFuture(nil)).toBe(false)
	end)

	it("refuses a corrupt save instead of erroring", function()
		local data, err = Migrations.run("not a save")
		expect(data).toBe(nil)
		expect(err).toBe("save is not a table")
	end)

	it("runs each step once, in order", function()
		local log = {}
		local steps = {
			function(data)
				table.insert(log, 1)
				data.Gems = 0
			end,
			function(data)
				table.insert(log, 2)
				data.Gems += 10
			end,
		}
		local data = Migrations.migrate({ SchemaVersion = 1 }, steps, 3)
		expect(log).toEqual({ 1, 2 })
		expect(data.Gems).toBe(10)
		expect(data.SchemaVersion).toBe(3)
	end)

	it("fails when a step is missing", function()
		local data, err = Migrations.migrate({ SchemaVersion = 1 }, {}, 2)
		expect(data).toBe(nil)
		expect(err).toBe("missing migration from version 1")
	end)
end)

describe("SessionLock", function()
	local now = 1000

	it("acquires a free save or one this server already holds", function()
		expect(SessionLock.decide(nil, "job-a", now)).toBe("Acquire")
		expect(SessionLock.decide(SessionLock.new("job-a", now - 10), "job-a", now)).toBe("Acquire")
	end)

	it("waits while another live server holds the save", function()
		expect(SessionLock.decide(SessionLock.new("job-b", now - 30), "job-a", now)).toBe("Wait")
		local edge = SessionLock.new("job-b", now - SessionLock.STALE_AFTER)
		expect(SessionLock.decide(edge, "job-a", now)).toBe("Wait")
	end)

	it("takes over a lock its server stopped refreshing", function()
		local stale = SessionLock.new("job-b", now - SessionLock.STALE_AFTER - 1)
		expect(SessionLock.decide(stale, "job-a", now)).toBe("Steal")
	end)

	it("only lets the holder write", function()
		local lock = SessionLock.new("job-a", now)
		expect(SessionLock.isHeldBy(lock, "job-a")).toBe(true)
		expect(SessionLock.isHeldBy(lock, "job-b")).toBe(false)
		expect(SessionLock.isHeldBy(nil, "job-a")).toBe(false)
	end)
end)

describe("ReceiptLedger", function()
	local function newLedger()
		return { Ids = {}, Order = {} }
	end

	it("grants a purchase once however many times the receipt arrives", function()
		local ledger = newLedger()
		local grants = 0
		local function grant()
			grants += 1
		end
		expect(ReceiptLedger.grantOnce(ledger, "p1", 1, grant)).toBe(true)
		expect(ReceiptLedger.grantOnce(ledger, "p1", 2, grant)).toBe(false)
		expect(ReceiptLedger.grantOnce(ledger, "p1", 3, grant)).toBe(false)
		expect(grants).toBe(1)
		expect(#ledger.Order).toBe(1)
	end)

	it("keeps separate purchases separate", function()
		local ledger = newLedger()
		ReceiptLedger.record(ledger, "p1", 1)
		ReceiptLedger.record(ledger, "p2", 2)
		expect(ReceiptLedger.has(ledger, "p1")).toBe(true)
		expect(ReceiptLedger.has(ledger, "p2")).toBe(true)
		expect(ReceiptLedger.has(ledger, "p3")).toBe(false)
	end)

	it("drops the oldest ids beyond the cap", function()
		local ledger = newLedger()
		for i = 1, ReceiptLedger.MAX_ENTRIES + 5 do
			ReceiptLedger.record(ledger, `p{i}`, i)
		end
		expect(#ledger.Order).toBe(ReceiptLedger.MAX_ENTRIES)
		expect(ReceiptLedger.has(ledger, "p1")).toBe(false)
		expect(ReceiptLedger.has(ledger, "p5")).toBe(false)
		expect(ReceiptLedger.has(ledger, "p6")).toBe(true)
		expect(ReceiptLedger.has(ledger, `p{ReceiptLedger.MAX_ENTRIES + 5}`)).toBe(true)
	end)
end)

return nil
