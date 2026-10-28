--!strict
-- Upgrade rules: what can be bought, when, and for how much. Pure functions
-- with no Roblox APIs, so the server, the client and the Lune test suite all
-- run the same code. Only the server's answer counts; the client uses it to
-- decide what to show. What each upgrade earns lives in Earnings.
--
-- Paths: every upgrade that isn't a building itself names the Building it
-- improves. After a building's shared upgrades it forks into two or three
-- Paths, and the first upgrade bought on one path locks that building's other
-- paths for good. The chosen path is never stored separately: it is whichever
-- path the player owns upgrades on, so saving Owned saves the choice.

export type Upgrade = {
	Id: string,
	Kind: string,
	Cost: number,
	Requires: string?,
	Building: string?,
	Path: string?,
}

export type State = {
	Coins: number,
	Owned: { [string]: boolean },
}

-- Each building's paths, with each path's upgrades in the order they're bought.
export type Paths = { [string]: { [string]: { Upgrade } } }

local Progression = {}

function Progression.find(upgrades: { Upgrade }, id: string): Upgrade?
	for _, upgrade in upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

-- Groups the path upgrades by building and path, each path in tier order:
-- its first tier is the one that doesn't require another upgrade on the path.
function Progression.paths(upgrades: { Upgrade }): Paths
	local result: Paths = {}
	local onPath: { [string]: Upgrade } = {}
	for _, upgrade in upgrades do
		if upgrade.Building and upgrade.Path then
			onPath[upgrade.Id] = upgrade
		end
	end
	for _, upgrade in onPath do
		local building, path = upgrade.Building :: string, upgrade.Path :: string
		local required = upgrade.Requires and onPath[upgrade.Requires]
		if not (required and required.Building == building and required.Path == path) then
			local tiers = {}
			local current: Upgrade? = upgrade
			while current and #tiers <= #upgrades do
				table.insert(tiers, current)
				local nextUp: Upgrade? = nil
				for _, candidate in onPath do
					if
						candidate.Requires == current.Id
						and candidate.Path == path
						and candidate.Building == building
					then
						nextUp = candidate
						break
					end
				end
				current = nextUp
			end
			result[building] = result[building] or {}
			result[building][path] = tiers
		end
	end
	return result
end

-- The path the player has committed to on each building.
function Progression.chosenPaths(owned: { [string]: boolean }, upgrades: { Upgrade }): { [string]: string }
	local chosen = {}
	for _, upgrade in upgrades do
		if owned[upgrade.Id] and upgrade.Building and upgrade.Path then
			chosen[upgrade.Building] = upgrade.Path
		end
	end
	return chosen
end

-- True if the upgrade is on a path the player can no longer take, because
-- they own upgrades on another path of the same building.
function Progression.pathLocked(owned: { [string]: boolean }, upgrades: { Upgrade }, upgrade: Upgrade): boolean
	if not (upgrade.Building and upgrade.Path) then
		return false
	end
	for _, other in upgrades do
		if owned[other.Id] and other.Building == upgrade.Building and other.Path and other.Path ~= upgrade.Path then
			return true
		end
	end
	return false
end

-- Where an upgrade sits on its path, as tier and number of tiers, or nil for
-- an upgrade that isn't on a path.
function Progression.pathTier(upgrades: { Upgrade }, id: string): (number?, number?)
	local upgrade = Progression.find(upgrades, id)
	if not (upgrade and upgrade.Building and upgrade.Path) then
		return nil, nil
	end
	local tiers = Progression.paths(upgrades)[upgrade.Building :: string][upgrade.Path :: string]
	for index, tier in tiers do
		if tier.Id == id then
			return index, #tiers
		end
	end
	return nil, nil
end

-- True once every upgrade on a building's path is owned.
function Progression.pathComplete(
	owned: { [string]: boolean },
	upgrades: { Upgrade },
	building: string,
	path: string
): boolean
	local byBuilding = Progression.paths(upgrades)[building]
	local tiers = byBuilding and byBuilding[path]
	if not tiers then
		return false
	end
	for _, tier in tiers do
		if not owned[tier.Id] then
			return false
		end
	end
	return true
end

-- True if upgrade can only be bought after targetId.
local function requires(byId: { [string]: Upgrade }, upgrade: Upgrade, targetId: string, limit: number): boolean
	local current = upgrade
	for _ = 1, limit do
		local nextUp = current.Requires and byId[current.Requires]
		if not nextUp then
			return false
		end
		if nextUp.Id == targetId then
			return true
		end
		current = nextUp
	end
	return false
end

local function validatePaths(upgrades: { Upgrade }, seen: { [string]: Upgrade }, problems: { string })
	local forkOf: { [string]: string? } = {}
	local pathCount: { [string]: number } = {}
	local roots: { [string]: { [string]: number } } = {}

	for _, upgrade in upgrades do
		local id, building = upgrade.Id, upgrade.Building
		if upgrade.Path and not building then
			table.insert(problems, `{id}: a path upgrade must name its Building`)
		end
		if building then
			local owner = seen[building]
			if not owner or owner.Building then
				table.insert(problems, `{id}: Building {building} is not a building`)
			elseif not requires(seen, upgrade, building, #upgrades) then
				table.insert(problems, `{id}: must require its Building, directly or through others`)
			end
		end

		-- Only a later tier of the same path may require a path upgrade, or the
		-- upgrade could never be bought by players who chose another path.
		local required = upgrade.Requires and seen[upgrade.Requires]
		if required and required.Path then
			if required.Building ~= building or required.Path ~= upgrade.Path then
				table.insert(problems, `{id}: requires {required.Id}, which is on another path`)
			end
		end

		if building and upgrade.Path and not (required and required.Path) then
			-- The first tier of its path: every path of a building forks from
			-- the same upgrade.
			local fork = upgrade.Requires or ""
			if forkOf[building] == nil then
				forkOf[building] = fork
			elseif forkOf[building] ~= fork then
				table.insert(problems, `{id}: the paths of {building} must all start after the same upgrade`)
			end
			roots[building] = roots[building] or {}
			roots[building][upgrade.Path] = (roots[building][upgrade.Path] or 0) + 1
			if roots[building][upgrade.Path] == 1 then
				pathCount[building] = (pathCount[building] or 0) + 1
			end
		end
	end

	for building, byPath in roots do
		for path, count in byPath do
			if count > 1 then
				table.insert(problems, `{building} path {path} must be one line of tiers`)
			end
		end
		if pathCount[building] < 2 then
			table.insert(problems, `{building} has only one path, so there is nothing to choose`)
		end
	end

	-- Within a path, tiers follow one another: no two need the same upgrade.
	local after: { [string]: string } = {}
	for _, upgrade in upgrades do
		if upgrade.Path and upgrade.Requires then
			local key = `{upgrade.Building}/{upgrade.Path}/{upgrade.Requires}`
			if after[key] then
				table.insert(problems, `{upgrade.Building} path {upgrade.Path} must be one line of tiers`)
			end
			after[key] = upgrade.Id
		end
	end
end

-- Returns a list of problems with ids, costs, requirements and paths; empty
-- means valid. Earnings.validate checks the fields each kind needs.
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
	local looped = false
	for _, upgrade in upgrades do
		local current: Upgrade? = upgrade
		local steps = 0
		while current and current.Requires do
			current = seen[current.Requires]
			steps += 1
			if steps > #upgrades then
				table.insert(problems, `{upgrade.Id}: requirement loop`)
				looped = true
				break
			end
		end
	end

	if not looped then
		validatePaths(upgrades, seen, problems)
	end
	return problems
end

-- Why a purchase is refused: UnknownUpgrade, AlreadyOwned, PathLocked, Locked
-- or TooExpensive.
function Progression.canPurchase(state: State, upgrades: { Upgrade }, id: string): (boolean, string?)
	local upgrade = Progression.find(upgrades, id)
	if not upgrade then
		return false, "UnknownUpgrade"
	end
	if state.Owned[id] then
		return false, "AlreadyOwned"
	end
	if Progression.pathLocked(state.Owned, upgrades, upgrade) then
		return false, "PathLocked"
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

-- Upgrades the player has unlocked but not bought yet, in config order,
-- leaving out paths they can no longer take.
function Progression.available(owned: { [string]: boolean }, upgrades: { Upgrade }): { Upgrade }
	local chosen = Progression.chosenPaths(owned, upgrades)
	local result = {}
	for _, upgrade in upgrades do
		local unlocked = upgrade.Requires == nil or owned[upgrade.Requires]
		local open = not upgrade.Path
			or chosen[upgrade.Building :: string] == nil
			or chosen[upgrade.Building :: string] == upgrade.Path
		if not owned[upgrade.Id] and unlocked and open then
			table.insert(result, upgrade)
		end
	end
	return result
end

return Progression
