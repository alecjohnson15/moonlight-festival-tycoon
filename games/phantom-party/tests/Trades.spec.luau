-- The trade journal (src/server/Lib/TradeJournal) under crashes: the server
-- is stopped after every step of a trade, with and without autosaves at
-- that moment, then both players load again. Every time, the trade must
-- have happened fully or not at all, the same way for both, with every
-- copy owned by exactly one player.

local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local TradeJournal = Loader.require("src/server/Lib/TradeJournal")
local Trade = Loader.require("src/shared/Rules/Trade")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in value do
		out[key] = copy(inner)
	end
	return out
end

local A_ID, B_ID = 101, 202

local function setup()
	local store = TradeJournal.memory()
	local a = {
		Items = { ["101-1"] = "blade_neon_x", ["101-2"] = "mask_fox", ["101-3"] = "trail_sparkle" },
		PendingTrades = {},
		AppliedTrades = {},
	}
	local b = {
		Items = { ["202-1"] = "mask_moon", ["202-2"] = "fx_confetti" },
		PendingTrades = {},
		AppliedTrades = {},
	}
	local record = TradeJournal.record(
		"t-1",
		A_ID,
		B_ID,
		{ ["101-1"] = "blade_neon_x", ["101-2"] = "mask_fox" },
		{ ["202-1"] = "mask_moon" },
		0
	)
	return store, a, b, record
end

-- Checks the two saves after recovery: all moved or none, every copy once.
local function settled(a, b): string
	local moved = a.Items["202-1"] == "mask_moon"
	for uid, itemId in { ["101-1"] = "blade_neon_x", ["101-2"] = "mask_fox", ["202-1"] = "mask_moon" } do
		local inA, inB = a.Items[uid] == itemId, b.Items[uid] == itemId
		if inA == inB then
			error(`{uid} is in {if inA then "both saves" else "neither save"}`)
		end
	end
	if moved then
		assert(a.Items["101-1"] == nil and a.Items["101-2"] == nil, "A kept what they gave")
		assert(b.Items["101-1"] and b.Items["101-2"] and b.Items["202-1"] == nil, "B's side is half done")
	else
		assert(a.Items["101-1"] and a.Items["101-2"] and a.Items["202-1"] == nil, "A's side is half done")
		assert(b.Items["202-1"] and b.Items["101-1"] == nil, "B got items without the trade")
	end
	assert(a.Items["101-3"] == "trail_sparkle", "an item outside the trade changed")
	assert(b.Items["202-2"] == "fx_confetti", "an item outside the trade changed")
	assert(next(a.PendingTrades) == nil and next(b.PendingTrades) == nil, "a trade is still pending")
	return if moved then "moved" else "kept"
end

local STEPS = { "Prepared", "Marked", "SavedA", "SavedB", "Decided", "Applied", "SavedAppliedA", "Done" }

describe("a trade that crashes part way", function()
	it("settles all or nothing after every step, with any mix of autosaves", function()
		local outcomes = {}
		for _, stop in STEPS do
			for _, autosave in { "none", "A", "B", "both" } do
				local store, a, b, record = setup()
				local saved = { A = copy(a), B = copy(b) }
				local ok = pcall(TradeJournal.run, store, record, a, b, {
					save = function(side)
						saved[side] = copy(if side == "A" then a else b)
						return true
					end,
					crash = function(step)
						if step == stop then
							error("crash")
						end
					end,
				})
				expect(ok).toBe(stop == "Done" and false or false)
				-- The moment the server stops, an autosave may already have
				-- written what was in memory.
				if autosave == "A" or autosave == "both" then
					saved.A = copy(a)
				end
				if autosave == "B" or autosave == "both" then
					saved.B = copy(b)
				end
				local loadedA, loadedB = copy(saved.A), copy(saved.B)
				TradeJournal.recover(store, loadedA, A_ID)
				TradeJournal.recover(store, loadedB, B_ID)
				local result = settled(loadedA, loadedB)
				-- Loading again changes nothing.
				local againA, againB = copy(loadedA), copy(loadedB)
				expect(TradeJournal.recover(store, againA, A_ID)).toBe(false)
				expect(TradeJournal.recover(store, againB, B_ID)).toBe(false)
				expect(againA).toEqual(loadedA)
				outcomes[`{stop}/{autosave}`] = result
			end
		end
		-- Once the journal says Committed, the trade always happens.
		expect(outcomes["Decided/none"]).toBe("moved")
		expect(outcomes["Applied/A"]).toBe("moved")
		-- Before both saves carry the mark, it never does.
		expect(outcomes["Prepared/none"]).toBe("kept")
		expect(outcomes["SavedA/both"]).toBe("kept")
	end)

	it("goes through when nothing goes wrong", function()
		local store, a, b, record = setup()
		local ok, why = TradeJournal.run(store, record, a, b, {
			save = function()
				return true
			end,
		})
		expect(ok).toBe(true)
		expect(why).toBe("Done")
		expect(settled(a, b)).toBe("moved")
	end)
end)

describe("a trade that fails cleanly", function()
	it("moves nothing when a save fails while marking", function()
		local store, a, b, record = setup()
		local ok, why = TradeJournal.run(store, record, a, b, {
			save = function(side)
				return side == "A"
			end,
		})
		expect(ok).toBe(false)
		expect(why).toBe("Save")
		TradeJournal.recover(store, a, A_ID)
		TradeJournal.recover(store, b, B_ID)
		expect(settled(a, b)).toBe("kept")
	end)

	it("moves nothing when another server calls it off first", function()
		local store, a, b, record = setup()
		local ok, why = TradeJournal.run(store, record, a, b, {
			save = function()
				return true
			end,
			crash = function(step)
				if step == "SavedB" then
					-- A player loading elsewhere settles the trade first.
					TradeJournal.decide(store, record.Id, "Aborted")
				end
			end,
		})
		expect(ok).toBe(false)
		expect(why).toBe("Aborted")
		expect(settled(a, b)).toBe("kept")
	end)

	it("leaves the trade for the next load when the journal can't be reached, and settles it then", function()
		local store, a, b, record = setup()
		local calls, broken = 0, false
		local flaky = {
			update = function(key, transform)
				calls += 1
				if broken then
					return false, nil
				end
				return store.update(key, transform)
			end,
			read = store.read,
		}
		local saved = { A = copy(a), B = copy(b) }
		local ok, why = TradeJournal.run(flaky, record, a, b, {
			save = function(side)
				saved[side] = copy(if side == "A" then a else b)
				return true
			end,
			crash = function(step)
				if step == "SavedB" then
					broken = true
				end
			end,
		})
		expect(ok).toBe(false)
		expect(why).toBe("Unsettled")
		expect(calls > 1).toBe(true)
		local loadedA, loadedB = copy(saved.A), copy(saved.B)
		TradeJournal.recover(store, loadedA, A_ID)
		TradeJournal.recover(store, loadedB, B_ID)
		expect(settled(loadedA, loadedB)).toBe("kept")
	end)

	it("doesn't start when the journal can't be written", function()
		local _, a, b, record = setup()
		local down = {
			update = function()
				return false, nil
			end,
			read = function()
				return false, nil
			end,
		}
		local ok, why = TradeJournal.run(down, record, a, b, {
			save = function()
				return true
			end,
		})
		expect(ok).toBe(false)
		expect(why).toBe("Journal")
		expect(next(a.PendingTrades)).toBe(nil)
	end)
end)

describe("settling a trade", function()
	it("applies a side once, however often it's asked", function()
		local _, a, _, record = setup()
		expect(TradeJournal.apply(a, record, A_ID)).toBe(true)
		local once = copy(a)
		expect(TradeJournal.apply(a, record, A_ID)).toBe(false)
		expect(a).toEqual(once)
	end)

	it("never applies a trade to someone who wasn't in it", function()
		local _, a, _, record = setup()
		expect(TradeJournal.apply(a, record, 999)).toBe(false)
		expect(a.Items["101-1"]).toBe("blade_neon_x")
	end)

	it("remembers only the last settled trades", function()
		local holder = { Items = {}, PendingTrades = {}, AppliedTrades = {} }
		for index = 1, TradeJournal.KEEP_APPLIED + 10 do
			TradeJournal.apply(holder, TradeJournal.record(`t{index}`, 1, 2, {}, {}, 0), 1)
		end
		expect(#holder.AppliedTrades).toBe(TradeJournal.KEEP_APPLIED)
	end)

	it("drops a mark for a trade the journal never heard of", function()
		local store = TradeJournal.memory()
		local holder = { Items = {}, PendingTrades = { ghost = true }, AppliedTrades = {} }
		expect(TradeJournal.recover(store, holder, 1)).toBe(true)
		expect(holder.PendingTrades.ghost).toBe(nil)
	end)

	it("can't be prepared twice with the same id", function()
		local store, _, _, record = setup()
		expect(TradeJournal.prepare(store, record)).toBe(true)
		expect(TradeJournal.prepare(store, record)).toBe(false)
	end)
end)

describe("a trade session", function()
	it("ignores changes, accepts and cancels while it settles", function()
		local holderA = { Items = { x = "mask_fox" }, NextUid = 1, Equipped = {} }
		local session = Trade.new("a", "b")
		Trade.setOffer(session, "a", { "x" }, holderA)
		Trade.accept(session, "a", 0)
		Trade.accept(session, "b", 0)
		expect(Trade.settle(session)).toBe(true)
		expect(Trade.setOffer(session, "a", {}, holderA)).toBe(false)
		expect(Trade.accept(session, "b", 1)).toBe(false)
		Trade.unaccept(session, "a")
		expect(session.State).toBe("Settling")
		Trade.cancel(session)
		expect(session.State).toBe("Settling")
	end)

	it("only settles once both have accepted", function()
		local session = Trade.new("a", "b")
		expect(Trade.settle(session)).toBe(false)
	end)

	it("counts a double accept as one", function()
		local holderA = { Items = { x = "mask_fox" }, NextUid = 1, Equipped = {} }
		local session = Trade.new("a", "b")
		Trade.setOffer(session, "a", { "x" }, holderA)
		Trade.accept(session, "a", 0)
		Trade.accept(session, "a", 0.1)
		expect(session.State).toBe("Open")
		Trade.accept(session, "b", 0.2)
		expect(session.State).toBe("Countdown")
		local ends = session.CountdownEnds
		Trade.accept(session, "b", 0.3)
		expect(session.CountdownEnds).toBe(ends)
	end)
end)
