--!strict
-- Deals the roles for a round. Every player holds tickets for each special
-- role. The more tickets, the likelier they are dealt it. A player who isn't
-- dealt a role gains a ticket for it; one who is drops back to one. So
-- everyone gets their turn as the Phantom or the Guardian, but nobody can
-- predict when.
--
-- A player's weight is their tickets squared, so a long wait pulls harder:
-- over 10,000 simulated rounds on a full server the longest anyone waited
-- for a turn as the Phantom fell from 88 rounds (one ticket, one weight, up
-- to 10) to about 30, with everyone's share still fair (tests/Sims.spec,
-- tools/simulate). Rollback: WEIGHT_POWER = 1, MAX_TICKETS = 10.

local Roles = require(script.Parent.Parent.Config.Roles)

export type Tickets = { [string]: number }

local Deal = {}

Deal.MAX_TICKETS = 20
Deal.WEIGHT_POWER = 2

local function weight(tickets: { [any]: Tickets }, id: any, roleId: string): number
	local held = tickets[id]
	local count = if held and held[roleId] then held[roleId] else 1
	return count ^ Deal.WEIGHT_POWER
end

-- Each id's role. random() gives a number from 0 up to 1.
function Deal.deal(ids: { any }, tickets: { [any]: Tickets }, random: () -> number): { [any]: string }
	local counts = Roles.counts(#ids)
	local roles = {}
	local pool = table.clone(ids)
	for _, roleId in Roles.DEAL_ORDER do
		for _ = 1, counts[roleId] or 0 do
			if #pool == 0 then
				break
			end
			local total = 0
			for _, id in pool do
				total += weight(tickets, id, roleId)
			end
			local roll = random() * total
			local chosen = #pool
			for index, id in pool do
				roll -= weight(tickets, id, roleId)
				if roll < 0 then
					chosen = index
					break
				end
			end
			roles[table.remove(pool, chosen)] = roleId
		end
	end
	for _, id in pool do
		roles[id] = "Guest"
	end
	return roles
end

-- After a deal: back to one ticket for the role you got, one more for each
-- you didn't.
function Deal.afterDeal(tickets: { [any]: Tickets }, roles: { [any]: string })
	for id, dealt in roles do
		local held = tickets[id] or {}
		tickets[id] = held
		for _, roleId in Roles.DEAL_ORDER do
			if dealt == roleId then
				held[roleId] = 1
			else
				held[roleId] = math.min((held[roleId] or 1) + 1, Deal.MAX_TICKETS)
			end
		end
	end
end

-- Each player's chance of being dealt roleId next round, as a percentage,
-- for the lobby's "your odds" line.
function Deal.chance(ids: { any }, tickets: { [any]: Tickets }, id: any, roleId: string): number
	local counts = Roles.counts(#ids)
	if (counts[roleId] or 0) == 0 then
		return 0
	end
	local total = 0
	for _, other in ids do
		total += weight(tickets, other, roleId)
	end
	return math.floor(100 * weight(tickets, id, roleId) / total + 0.5)
end

return Deal
