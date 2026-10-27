--!strict
-- Upgrade rules and income math. Pure functions with no Roblox APIs, so the
-- server, the client and the Lune test suite all run the same code. Only the
-- server's answer counts; the client uses it to decide what to show.

export type Upgrade = {
	Id: string,
	Kind: string,
	Cost: number,
	Requires: string?,
	IncomePerSecond: number?,
	Target: string?,
	Multiplier: number?,
}

export type State = {
	Coins: number,
	Owned: { [string]: boolean },
}

local Progression = {}

function Progression.find(upgrades: { Upgrade }, id: string): Upgrade?
	for _, upgrade in upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

-- Returns a list of problems with the upgrade config; empty means valid.
function Progression.validate(upgrades: { Upgrade }): { string }
	local problems = {}
	local seen: { [string]: Upgrade } = {}

	for _, upgrade in upgrades do
		if seen[upgrade.Id] then
			table.insert(problems, `duplicate id {upgrade.Id}`)
		end
		seen[upgrade.Id] = upgrade
	end

	for _, upgrade in upgrades do
		local id = upgrade.Id
		if typeof(upgrade.Cost) ~= "number" or upgrade.Cost < 0 or upgrade.Cost ~= math.floor(upgrade.Cost) then
			table.insert(problems, `{id}: cost must be a whole number of at least 0`)
		end
		if upgrade.Requires and not seen[upgrade.Requires] then
			table.insert(problems, `{id}: requires unknown upgrade {upgrade.Requires}`)
		end
		if upgrade.Kind == "Producer" then
			if typeof(upgrade.IncomePerSecond) ~= "number" or (upgrade.IncomePerSecond :: number) <= 0 then
				table.insert(problems, `{id}: producer needs a positive IncomePerSecond`)
			end
		elseif upgrade.Kind == "Boost" then
			local target = upgrade.Target and seen[upgrade.Target]
			if not target or target.Kind ~= "Producer" then
				table.insert(problems, `{id}: boost must target a producer`)
			end
			if typeof(upgrade.Multiplier) ~= "number" or (upgrade.Multiplier :: number) <= 1 then
				table.insert(problems, `{id}: boost needs a Multiplier above 1`)
			end
		else
			table.insert(problems, `{id}: unknown kind {upgrade.Kind}`)
		end
	end

	-- A requirement loop would make every upgrade in it impossible to buy.
	for _, upgrade in upgrades do
		local current: Upgrade? = upgrade
		local steps = 0
		while current and current.Requires do
			current = seen[current.Requires]
			steps += 1
			if steps > #upgrades then
				table.insert(problems, `{upgrade.Id}: requirement loop`)
				break
			end
		end
	end

	return problems
end

-- Why a purchase is refused: UnknownUpgrade, AlreadyOwned, Locked or TooExpensive.
function Progression.canPurchase(state: State, upgrades: { Upgrade }, id: string): (boolean, string?)
	local upgrade = Progression.find(upgrades, id)
	if not upgrade then
		return false, "UnknownUpgrade"
	end
	if state.Owned[id] then
		return false, "AlreadyOwned"
	end
	if upgrade.Requires and not state.Owned[upgrade.Requires] then
		return false, "Locked"
	end
	if state.Coins < upgrade.Cost then
		return false, "TooExpensive"
	end
	return true, nil
end

-- Charges for and grants an upgrade in place. Returns the same refusal
-- reasons as canPurchase and changes nothing when refused.
function Progression.purchase(state: State, upgrades: { Upgrade }, id: string): (boolean, string?)
	local ok, reason = Progression.canPurchase(state, upgrades, id)
	if not ok then
		return false, reason
	end
	local upgrade = Progression.find(upgrades, id) :: Upgrade
	state.Coins -= upgrade.Cost
	state.Owned[id] = true
	return true, nil
end

function Progression.incomePerSecond(owned: { [string]: boolean }, upgrades: { Upgrade }): number
	local multipliers: { [string]: number } = {}
	for _, upgrade in upgrades do
		if upgrade.Kind == "Boost" and owned[upgrade.Id] and upgrade.Target then
			multipliers[upgrade.Target] = (multipliers[upgrade.Target] or 1) * (upgrade.Multiplier or 1)
		end
	end

	local total = 0
	for _, upgrade in upgrades do
		if upgrade.Kind == "Producer" and owned[upgrade.Id] then
			total += (upgrade.IncomePerSecond or 0) * (multipliers[upgrade.Id] or 1)
		end
	end
	return total
end

-- Upgrades the player has unlocked but not bought yet, in config order.
function Progression.available(owned: { [string]: boolean }, upgrades: { Upgrade }): { Upgrade }
	local result = {}
	for _, upgrade in upgrades do
		if not owned[upgrade.Id] and (upgrade.Requires == nil or owned[upgrade.Requires]) then
			table.insert(result, upgrade)
		end
	end
	return result
end

return Progression
