--!strict
-- Upgrade rules: what can be bought, when, and for how much. Pure functions
-- with no Roblox APIs, so the server, the client and the Lune test suite all
-- run the same code. Only the server's answer counts; the client uses it to
-- decide what to show. What each upgrade earns lives in Earnings.

export type Upgrade = {
	Id: string,
	Kind: string,
	Cost: number,
	Requires: string?,
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

-- Returns a list of problems with ids, costs and requirements; empty means
-- valid. Earnings.validate checks the fields each kind needs.
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
