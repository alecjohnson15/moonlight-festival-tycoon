--!strict
-- Remembers which purchases have already been granted, inside the player's
-- save, so a receipt Roblox retries is acknowledged without granting twice.

export type Ledger = {
	Ids: { [string]: number },
	Order: { string },
}

local ReceiptLedger = {}

-- Roblox stops retrying a receipt once it is acknowledged, so only recent
-- purchases can come back. Older ids are dropped to keep the save small.
ReceiptLedger.MAX_ENTRIES = 100

function ReceiptLedger.has(ledger: Ledger, purchaseId: string): boolean
	return ledger.Ids[purchaseId] ~= nil
end

function ReceiptLedger.record(ledger: Ledger, purchaseId: string, now: number)
	if ledger.Ids[purchaseId] then
		return
	end
	ledger.Ids[purchaseId] = now
	table.insert(ledger.Order, purchaseId)
	while #ledger.Order > ReceiptLedger.MAX_ENTRIES do
		local oldest = table.remove(ledger.Order, 1) :: string
		ledger.Ids[oldest] = nil
	end
end

-- Runs grant and records the purchase, unless it was already recorded.
-- Returns true when grant ran this time.
function ReceiptLedger.grantOnce(ledger: Ledger, purchaseId: string, now: number, grant: () -> ()): boolean
	if ReceiptLedger.has(ledger, purchaseId) then
		return false
	end
	grant()
	ReceiptLedger.record(ledger, purchaseId, now)
	return true
end

return ReceiptLedger
