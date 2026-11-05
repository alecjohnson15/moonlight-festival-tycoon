--!strict
-- A trade between two players, step by step. Each side puts up to MAX_ITEMS
-- copies on the table. When both accept, a countdown runs; any change to
-- either offer cancels both accepts, so nobody can swap an item out at the
-- last second. When the countdown ends the server checks everything again
-- and moves the copies in one go, or not at all.

local Inventory = require(script.Parent.Inventory)

export type Side = { Id: any, Offer: { string }, Accepted: boolean }
export type Session = {
	A: Side,
	B: Side,
	State: string,
	CountdownEnds: number?,
	Version: number,
}

local Trade = {}

Trade.MAX_ITEMS = 8
Trade.COUNTDOWN = 5

function Trade.new(a: any, b: any): Session
	return {
		A = { Id = a, Offer = {}, Accepted = false },
		B = { Id = b, Offer = {}, Accepted = false },
		State = "Open",
		CountdownEnds = nil,
		Version = 0,
	}
end

function Trade.side(session: Session, who: any): (Side?, Side?)
	if session.A.Id == who then
		return session.A, session.B
	elseif session.B.Id == who then
		return session.B, session.A
	end
	return nil, nil
end

local function reopen(session: Session)
	session.A.Accepted = false
	session.B.Accepted = false
	session.State = "Open"
	session.CountdownEnds = nil
	session.Version += 1
end

-- Replaces who's offer with uids, all from holder (who's inventory).
function Trade.setOffer(session: Session, who: any, uids: { string }, holder: Inventory.Holder): (boolean, string?)
	local side = Trade.side(session, who)
	if not side or session.State == "Done" or session.State == "Cancelled" then
		return false, "Closed"
	end
	if #uids > Trade.MAX_ITEMS then
		return false, "TooMany"
	end
	local seen = {}
	for _, uid in uids do
		if seen[uid] then
			return false, "Repeated"
		end
		seen[uid] = true
		if not Inventory.canTrade(holder, uid) then
			return false, "NotTradeable"
		end
	end
	side.Offer = table.clone(uids)
	reopen(session)
	return true, nil
end

function Trade.accept(session: Session, who: any, now: number): (boolean, string?)
	local side = Trade.side(session, who)
	if not side or session.State == "Done" or session.State == "Cancelled" then
		return false, "Closed"
	end
	if #session.A.Offer == 0 and #session.B.Offer == 0 then
		return false, "Empty"
	end
	side.Accepted = true
	if session.A.Accepted and session.B.Accepted then
		session.State = "Countdown"
		session.CountdownEnds = now + Trade.COUNTDOWN
	end
	return true, nil
end

function Trade.unaccept(session: Session, who: any)
	local side = Trade.side(session, who)
	if side and (session.State == "Open" or session.State == "Countdown") then
		side.Accepted = false
		session.State = "Open"
		session.CountdownEnds = nil
		session.Version += 1
	end
end

function Trade.cancel(session: Session)
	if session.State ~= "Done" then
		session.State = "Cancelled"
	end
end

-- Whether the countdown has run out and the trade should go through.
function Trade.due(session: Session, now: number): boolean
	return session.State == "Countdown" and session.CountdownEnds ~= nil and now >= session.CountdownEnds
end

-- Moves both offers, holderA belonging to side A and holderB to side B.
-- Checks every copy first and changes nothing unless all are still there.
function Trade.execute(session: Session, holderA: Inventory.Holder, holderB: Inventory.Holder): (boolean, string?)
	if session.State ~= "Countdown" then
		return false, "NotReady"
	end
	for _, uid in session.A.Offer do
		if not Inventory.canTrade(holderA, uid) then
			session.State = "Cancelled"
			return false, "Missing"
		end
	end
	for _, uid in session.B.Offer do
		if not Inventory.canTrade(holderB, uid) then
			session.State = "Cancelled"
			return false, "Missing"
		end
	end
	local moving = {}
	for _, uid in session.A.Offer do
		moving[uid] = holderA.Items[uid]
		holderA.Items[uid] = nil
	end
	for _, uid in session.B.Offer do
		holderA.Items[uid] = holderB.Items[uid]
		holderB.Items[uid] = nil
	end
	for uid, itemId in moving do
		holderB.Items[uid] = itemId
	end
	session.State = "Done"
	return true, nil
end

return Trade
