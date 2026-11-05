--!strict
-- Settling a trade so that a server crash can't duplicate or lose an item.
--
-- Each player's save is a separate DataStore key, and Roblox can't write two
-- keys at once, so no trade between two saves is truly atomic. Instead this
-- is a small two-phase commit with one key that decides:
--
--   1. Prepare  Write the trade, State = "Prepared", to its own journal key.
--   2. Mark     Add the trade's id to both players' PendingTrades and save
--               both. If either save fails, abort: nothing has moved.
--   3. Decide   Flip the journal key from Prepared to Committed. This one
--               atomic write is the moment the trade happens. A player
--               loading on another server can flip it to Aborted instead
--               (step R), and whichever write lands first wins.
--   4. Apply    Move the items in both saves, record the id in each
--               AppliedTrades, drop the pending mark, and save both.
--
--   R. Recover  When a player loads, every id still in PendingTrades is
--               settled from the journal: Committed is applied (once: the
--               AppliedTrades list makes it idempotent), Prepared is
--               flipped to Aborted, Aborted or missing is dropped.
--
-- What this guarantees: once both saves carry the mark, each side ends up
-- applied exactly once or not at all, the same way for both players, even
-- if the server stops between any two steps. What it doesn't: the two saves
-- change at different moments, so a player may briefly see the old
-- inventory until they rejoin; and if the journal can't be read at all
-- (a DataStore outage), the trade stays pending until it can. Two trades
-- offering the same copy are stopped before this point (one trade per
-- player at a time, and the offer is checked as it settles).
--
-- Pure: the DataStore and the saves come in as functions, so the tests can
-- crash it after every step (tests/Trades.spec).

export type Record = {
	Id: string,
	A: number,
	B: number,
	AGives: { [string]: string },
	BGives: { [string]: string },
	State: string,
	Time: number,
}

-- The journal's storage. update runs transform on the stored value (nil if
-- none) and stores what it returns; returning nil leaves the value as it
-- was. Both return whether the call worked and the value now stored.
export type Store = {
	update: (key: string, transform: (any) -> any) -> (boolean, any),
	read: (key: string) -> (boolean, any),
}

export type Holder = {
	Items: { [string]: string },
	PendingTrades: { [string]: boolean },
	AppliedTrades: { string },
}

export type Steps = {
	-- Saves one side ("A" or "B"); true if the write worked.
	save: (side: string) -> boolean,
	-- For the tests: called after each step, may stop the run (a crash).
	crash: ((step: string) -> ())?,
}

local TradeJournal = {}

-- How many settled trade ids each save remembers.
TradeJournal.KEEP_APPLIED = 50

function TradeJournal.key(id: string): string
	return `trade_{id}`
end

function TradeJournal.record(
	id: string,
	a: number,
	b: number,
	aGives: { [string]: string },
	bGives: { [string]: string },
	time: number
): Record
	return { Id = id, A = a, B = b, AGives = aGives, BGives = bGives, State = "Prepared", Time = time }
end

-- Step 1. Writes a new trade; false if it couldn't, or the id was taken.
function TradeJournal.prepare(store: Store, record: Record): boolean
	-- The transform may run more than once (DataStore retries); the last
	-- run is the one that counts.
	local wrote = false
	local ok, value = store.update(TradeJournal.key(record.Id), function(old)
		if old ~= nil then
			wrote = false
			return nil
		end
		wrote = true
		local copy = table.clone(record)
		copy.State = "Prepared"
		return copy
	end)
	return ok and wrote and type(value) == "table" and value.Id == record.Id and value.State == "Prepared"
end

-- Step 3 (and R). Moves a Prepared trade to want ("Committed" or
-- "Aborted"). Returns the state it ends in, which may be the other one if
-- someone decided first, or nil if the journal couldn't be reached.
function TradeJournal.decide(store: Store, id: string, want: string): string?
	local ok, value = store.update(TradeJournal.key(id), function(old)
		if type(old) ~= "table" or old.State ~= "Prepared" then
			return nil
		end
		local copy = table.clone(old)
		copy.State = want
		return copy
	end)
	if not ok then
		return nil
	end
	if type(value) ~= "table" then
		return "Missing"
	end
	return value.State
end

function TradeJournal.applied(holder: Holder, id: string): boolean
	return table.find(holder.AppliedTrades, id) ~= nil
end

-- Drops the pending mark.
function TradeJournal.forget(holder: Holder, id: string)
	holder.PendingTrades[id] = nil
end

-- Step 4 for one side: takes what userId gave and adds what they got, once.
-- A copy is only taken if it's still the item the trade recorded, and only
-- added if the slot is free, so running it twice changes nothing.
function TradeJournal.apply(holder: Holder, record: Record, userId: number): boolean
	if TradeJournal.applied(holder, record.Id) then
		TradeJournal.forget(holder, record.Id)
		return false
	end
	local gives, gets
	if userId == record.A then
		gives, gets = record.AGives, record.BGives
	elseif userId == record.B then
		gives, gets = record.BGives, record.AGives
	else
		return false
	end
	for uid, itemId in gives do
		if holder.Items[uid] == itemId then
			holder.Items[uid] = nil
		end
	end
	for uid, itemId in gets do
		if holder.Items[uid] == nil then
			holder.Items[uid] = itemId
		end
	end
	table.insert(holder.AppliedTrades, record.Id)
	while #holder.AppliedTrades > TradeJournal.KEEP_APPLIED do
		table.remove(holder.AppliedTrades, 1)
	end
	TradeJournal.forget(holder, record.Id)
	return true
end

-- Step R. Settles every trade this holder is still marked for. Returns
-- whether the holder changed (so the caller saves it).
function TradeJournal.recover(store: Store, holder: Holder, userId: number): boolean
	local changed = false
	local ids = {}
	for id in holder.PendingTrades do
		table.insert(ids, id)
	end
	for _, id in ids do
		if TradeJournal.applied(holder, id) then
			TradeJournal.forget(holder, id)
			changed = true
			continue
		end
		local ok, record = store.read(TradeJournal.key(id))
		if not ok then
			continue
		end
		local state = if type(record) == "table" then record.State else "Missing"
		if state == "Prepared" then
			state = TradeJournal.decide(store, id, "Aborted") or "Unknown"
			if state == "Committed" then
				local okAgain, fresh = store.read(TradeJournal.key(id))
				record = if okAgain then fresh else nil
				if type(record) ~= "table" then
					continue
				end
			end
		end
		if state == "Committed" then
			TradeJournal.apply(holder, record :: Record, userId)
			changed = true
		elseif state == "Aborted" or state == "Missing" then
			TradeJournal.forget(holder, id)
			changed = true
		end
	end
	return changed
end

-- The whole trade, steps 1 to 4. Returns whether it went through and why
-- not: "Journal" (couldn't prepare), "Save" (a save failed while marking),
-- "Aborted" (a recovery elsewhere decided first) or "Unsettled" (the
-- journal couldn't be reached to decide; the next load settles it).
function TradeJournal.run(
	store: Store,
	record: Record,
	holderA: Holder,
	holderB: Holder,
	steps: Steps
): (boolean, string)
	local crash = steps.crash or function(_step: string) end
	local id = record.Id
	if not TradeJournal.prepare(store, record) then
		return false, "Journal"
	end
	crash("Prepared")

	holderA.PendingTrades[id] = true
	holderB.PendingTrades[id] = true
	crash("Marked")
	local savedA = steps.save("A")
	crash("SavedA")
	local savedB = steps.save("B")
	crash("SavedB")

	local function undo(reason: string): (boolean, string)
		TradeJournal.forget(holderA, id)
		TradeJournal.forget(holderB, id)
		steps.save("A")
		steps.save("B")
		return false, reason
	end

	if not savedA or not savedB then
		local state = TradeJournal.decide(store, id, "Aborted")
		if state ~= "Committed" then
			return undo("Save")
		end
	end

	local state = TradeJournal.decide(store, id, "Committed")
	crash("Decided")
	if state == nil then
		-- Couldn't reach the journal: try to call it off instead.
		state = TradeJournal.decide(store, id, "Aborted")
		if state == nil then
			return false, "Unsettled"
		end
	end
	if state ~= "Committed" then
		return undo("Aborted")
	end

	TradeJournal.apply(holderA, record, record.A)
	TradeJournal.apply(holderB, record, record.B)
	crash("Applied")
	steps.save("A")
	crash("SavedAppliedA")
	steps.save("B")
	crash("Done")
	return true, "Done"
end

-- A journal kept in memory, for Studio without DataStores and for the
-- tests.
function TradeJournal.memory(): Store
	local data: { [string]: any } = {}
	return {
		update = function(key, transform)
			local result = transform(data[key])
			if result ~= nil then
				data[key] = result
			end
			return true, data[key]
		end,
		read = function(key)
			return true, data[key]
		end,
	}
end

return TradeJournal
