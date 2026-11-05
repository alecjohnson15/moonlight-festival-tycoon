-- A deterministic model of a whole run, second by second, built from the
-- game's own numbers (Config/Balance, Resources, Recipes, Structures,
-- Weapons, Roles, Enemies, the town layout and the wave rules). It answers
-- "with these numbers, can a team of this size and these roles get through,
-- and when do the milestones land?" for 1 to 8 players and nights 1 to 15.
--
-- It is a model, not a measurement. Real players wander, chat, die and get
-- lost, and nothing here knows how fun any of it is. The guesses it has to
-- make about how players spend their time are all in RunModel.Assumptions,
-- with what each stands for, so they can be argued with. tests/Pacing.spec
-- checks the design targets against it and tools/simulate_run prints it.
--
-- Use from games/snowed-in: `local RunModel = require("../tools/RunModel")`
-- from a test, or `lune run tools/simulate_run`.

local RobloxLoader = require("../tests/RobloxLoader")

local Assist = RobloxLoader.require("src/shared/Assist")
local Balance = RobloxLoader.require("src/shared/Config/Balance")
local Enemies = RobloxLoader.require("src/shared/Config/Enemies")
local Expedition = RobloxLoader.require("src/shared/Config/Expedition")
local Features = RobloxLoader.require("src/shared/Config/Features")
local Map = RobloxLoader.require("src/shared/Config/Map")
local Profile = RobloxLoader.require("src/shared/Profile")
local Radio = RobloxLoader.require("src/shared/Radio")
local Recipes = RobloxLoader.require("src/shared/Config/Recipes")
local Resources = RobloxLoader.require("src/shared/Config/Resources")
local Roles = RobloxLoader.require("src/shared/Config/Roles")
local Structures = RobloxLoader.require("src/shared/Config/Structures")
local Town = RobloxLoader.require("src/shared/World/Town")
local Waves = RobloxLoader.require("src/shared/Waves")
local Weapons = RobloxLoader.require("src/shared/Config/Weapons")

local RunModel = {}

-- How players are assumed to spend their time. Every number here is a
-- guess about behaviour, not a game rule; change one and see what moves.
RunModel.Assumptions = {
	-- Share of a day a player spends gathering and carrying. The rest goes
	-- on building, crafting, cooking, warming up and looking around.
	GatherShare = 0.6,
	-- How gathering time is shared out between the resources.
	Mix = { Wood = 0.4, Stone = 0.2, Scrap = 0.25, Coal = 0.15 },
	-- How many of the nearest nodes of a kind a team works (sets the walk).
	NearestNodes = 8,
	-- Seconds to move on when a node runs out, and to drop a pack off.
	NodeHop = 5,
	DropOff = 2,
	-- Supply crates opened each morning: this many per player, up to all.
	CratesPerPlayer = 2,
	-- Seconds at the start of the first day before anyone gathers: picking
	-- a role and following the guide's first steps.
	FirstDayWarmup = 60,
	-- Flame kept in hand for the coming night: the night's burn plus this.
	FlameMargin = 30,
	-- Share of a night each player is landing hits. The rest is moving,
	-- thawing friends, feeding the fire and warming up. A Cook's meals and a
	-- Medic's thaws each give the whole team a little more (once per team).
	FightUptime = 0.5,
	CookUptime = 0.05,
	MedicUptime = 0.05,
	-- Share of swings and shots that land, and how many monsters a hit of
	-- each kind of weapon catches on average.
	Accuracy = 0.7,
	Targets = { Melee = 1.4, Shot = 1, Blast = 2, Cone = 2.2 },
	-- Share of the time a turret has something in range.
	TurretUptime = 0.5,
	-- Turrets a team aims to keep per player, once it can afford them.
	TurretsPerPlayer = 1,
	-- Even a team that clears the wave lets some monsters reach the fire:
	-- this share of the wave lands one douse each.
	ChipShare = 0.15,
	-- A monster the team can't handle douses the fire this many times
	-- before it is dealt with.
	LeakHits = 4,
	-- Share of the team's damage on the boss while it is up.
	BossFocus = 0.5,
	-- An expedition's extra time: finding the way in the snow, regrouping,
	-- warming up, the part ceremony.
	ExpeditionOverhead = 45,
	-- Seconds into the day before an expedition sets out.
	ExpeditionPrep = 20,
	-- How many go on an expedition for a team of this size.
	Party = function(players: number): number
		return if players >= 4 then 2 else 1
	end,
}
local A = RunModel.Assumptions

-- When a team goes for the radio parts.
--   Steady: the pace the catch-up help treats as on time: the first part on
--   day CatchUpFrom - 1, then one every CatchUpEvery days.
--   Eager: a part every day from day 2, as fast as the day allows.
RunModel.Policies = {
	Steady = function(day: number): boolean
		local first = Balance.Radio.CatchUpFrom - 1
		return day >= first and (day - first) % Balance.Radio.CatchUpEvery == 0
	end,
	Eager = function(day: number): boolean
		return day >= 2
	end,
	-- Never fixes the radio: the run goes into overtime and ends at
	-- Balance.LastNight, to check that ending.
	Never = function(_day: number): boolean
		return false
	end,
}

---------------------------------------------------------------------------
-- The clock

local P = Balance.Phases

local function dayLength(day: number): number
	return if day == 1 then P.FirstDay else P.Day
end

-- Seconds from the start of day 1 to the start of a day.
function RunModel.dayStart(day: number): number
	if day <= 1 then
		return 0
	end
	return P.FirstDay + (day - 1) * (P.Dusk + P.Night + P.Dawn) + (day - 2) * P.Day
end

function RunModel.nightStart(night: number): number
	return RunModel.dayStart(night) + dayLength(night) + P.Dusk
end

function RunModel.dawnEnd(night: number): number
	return RunModel.nightStart(night) + P.Night + P.Dawn
end

---------------------------------------------------------------------------
-- Gathering

local NODE = { Wood = "Pine", Stone = "Rock", Coal = "CoalSeam", Scrap = "Salvage", Fish = "FishingHole" }
local SPOTS = { Wood = "Trees", Stone = "Rocks", Coal = "Coal", Scrap = "Salvage", Fish = "Holes" }

local layout = Town.layout()
local walks: { [string]: number } = {}

-- The average walk from the stockpile to the nearest nodes of a resource.
function RunModel.walk(resource: string): number
	if not walks[resource] then
		local list = {}
		for _, spot in layout[SPOTS[resource]] do
			table.insert(list, math.sqrt((spot.X - Map.Stockpile[1]) ^ 2 + (spot.Z - Map.Stockpile[2]) ^ 2))
		end
		table.sort(list)
		local count = math.min(A.NearestNodes, #list)
		local sum = 0
		for index = 1, count do
			sum += list[index]
		end
		walks[resource] = sum / count
	end
	return walks[resource]
end

local function speedOf(role: any): number
	return Balance.WalkSpeed * (1 + (role.SpeedBonus or 0))
end

-- Units of a resource one player brings home per second spent gathering
-- it: a full pack, the holds to fill it, the walk there and back.
function RunModel.gatherRate(resource: string, role: any, players: number): number
	local node = Resources.Nodes[NODE[resource]]
	local pack = Balance.Backpack + (role.PackBonus or 0)
	local uses = math.ceil(pack / node.Yield)
	local hold = node.HoldSeconds * Assist.holdScale(role.GatherSpeed or 0, players)
	local hops = math.ceil(uses / node.Uses) - 1
	local trip = 2 * RunModel.walk(resource) / speedOf(role) + uses * hold + hops * A.NodeHop + A.DropOff
	return uses * node.Yield / trip
end

-- The most of a resource the whole valley gives per second, however many
-- gather it (every node used up and waiting to grow back).
function RunModel.supply(resource: string): number
	local node = Resources.Nodes[NODE[resource]]
	return #layout[SPOTS[resource]] * node.Uses * node.Yield / node.RespawnSeconds
end

---------------------------------------------------------------------------
-- Fighting

local WEAPONS = { "Torch" }
for _, recipe in Recipes.Weapons do
	table.insert(WEAPONS, recipe.Id)
end

-- One player's damage per second with a weapon, before uptime.
function RunModel.dps(weaponId: string, role: any): number
	local weapon = Weapons.ById[weaponId]
	local volley = 1
	if role.Ability.Id == "Volley" then
		-- Doubled hits for Amount swings every Cooldown seconds.
		local swings = role.Ability.Cooldown / weapon.Cooldown
		volley = 1 + math.min(1, (role.Ability.Amount :: number) / swings)
	end
	return weapon.Damage
		/ weapon.Cooldown
		* A.Targets[weapon.Kind]
		* A.Accuracy
		* (1 + (role.DamageBonus or 0))
		* volley
end

local TURRET = Structures.ById.EmberTurret

local function turretDps(): number
	return (TURRET.Damage :: number) / (TURRET.Cooldown :: number) * A.TurretUptime
end

-- A night's wave, averaged over a few rolls: its total health, its douse
-- if every monster hit the fire once, and how many monsters.
local function waveOf(night: number, players: number, theme: any)
	local health, douse, count = 0, 0, 0
	local rolls = 6
	for seed = 1, rolls do
		local state = seed * 7919 + night
		local function roll(): number
			state = (state * 16807) % 2147483647
			return (state - 1) / 2147483646
		end
		for _, kind in Waves.forNight(night, players, roll, theme) do
			local enemy = Enemies.ById[kind]
			health += enemy.Health
			douse += enemy.Douse
			count += 1
		end
	end
	return health / rolls, douse / rolls, count / rolls
end

---------------------------------------------------------------------------
-- A run

export type Night = {
	Night: number,
	Theme: string,
	WaveHealth: number,
	BossHealth: number,
	Capacity: number,
	-- Wave (and boss) health over what the team can deal in a night: under
	-- 1 the team clears it, over 1 some of it reaches the fire.
	Pressure: number,
	FlameLost: number,
	FlameAtDawn: number,
	Level: number,
	Turrets: number,
	BestWeapon: string,
	Parts: number,
	Behind: boolean,
}

export type Result = {
	Players: number,
	-- Everything gathered and opened, and the fuel fed to the fire, in
	-- units of resource.
	Gathered: number,
	Fuel: number,
	Roles: { string },
	Policy: string,
	Won: boolean,
	LostOn: number?,
	Nights: { Night },
	-- Minutes from the start of day 1 to each milestone the team reached.
	Milestones: { [string]: number },
	Knockouts: number,
	Parts: number,
	BeatYeti: boolean,
}

local function cost(recipe: { [string]: number }, discount: number): { [string]: number }
	local out = {}
	for id, amount in recipe do
		out[id] = math.ceil(amount * (1 - discount))
	end
	return out
end

local function afford(stock, price, keep): boolean
	for id, amount in price do
		if (stock[id] or 0) - (keep[id] or 0) < amount then
			return false
		end
	end
	return true
end

local function spend(stock, price)
	for id, amount in price do
		stock[id] -= amount
	end
end

-- Plays one run. roles is a list of role ids, one per player; policy is a
-- key of RunModel.Policies; seed picks the night themes (Waves.plan).
function RunModel.run(roles: { string }, policy: string?, seed: number?): Result
	local players = #roles
	local chosen = policy or "Steady"
	local goes = RunModel.Policies[chosen]
	local team = {}
	local hasBuilder, hasCook, hasMedic = false, false, false
	for _, id in roles do
		local role = Roles.ById[id]
		table.insert(team, { Role = role, Weapon = 1 })
		hasBuilder = hasBuilder or id == "Builder"
		hasCook = hasCook or id == "Cook"
		hasMedic = hasMedic or id == "Medic"
	end
	local uptime = A.FightUptime + (if hasCook then A.CookUptime else 0) + (if hasMedic then A.MedicUptime else 0)
	local burnScale = Assist.burn(players)
	local plan = Waves.plan(seed or 1225)
	local hearth = Balance.Hearth
	local stock = { Wood = 0, Stone = 0, Scrap = 0, Coal = 0 }
	local flame, level, turrets = hearth.StartFlame, 1, 0
	local maxTurrets = math.min(Balance.Build.MaxStructures, A.TurretsPerPlayer * players)
	local parts, knockouts = 0, 0
	local frozen = {}
	for _, landmark in Map.Landmarks do
		table.insert(frozen, landmark)
	end
	table.sort(frozen, function(a, b)
		return a.At[1] ^ 2 + a.At[2] ^ 2 < b.At[1] ^ 2 + b.At[2] ^ 2
	end)
	local result: Result = {
		Players = players,
		Gathered = 0,
		Fuel = 0,
		Roles = roles,
		Policy = chosen,
		Won = false,
		LostOn = nil,
		Nights = {},
		Milestones = {},
		Knockouts = 0,
		Parts = 0,
		BeatYeti = false,
	}
	local function mark(id: string, seconds: number)
		if not result.Milestones[id] then
			result.Milestones[id] = seconds / 60
		end
	end

	-- The team's damage per second at night, with its weapons and turrets.
	local function teamDps(): number
		local total = 0
		for _, member in team do
			total += RunModel.dps(WEAPONS[member.Weapon], member.Role) * uptime
		end
		return total + turrets * turretDps()
	end

	-- The flame the coming night will burn.
	local nightBurn = (P.Night * hearth.BurnPerSecondNight + (P.Dusk + P.Dawn) * hearth.BurnPerSecondDay) * burnScale

	-- What to keep back from spending: the wood to keep the fire fed.
	local function keep()
		local need = math.max(0, nightBurn + A.FlameMargin - flame)
		return { Wood = math.ceil(need / hearth.Fuel.Wood) }
	end

	local function feed()
		local maxFlame = hearth.Levels[level].MaxFlame
		local target = math.min(maxFlame, nightBurn + A.FlameMargin)
		while flame < target do
			local batch = hearth.FeedBatch
			result.Fuel += batch
			if stock.Wood >= batch then
				stock.Wood -= batch
				flame = math.min(maxFlame, flame + batch * hearth.Fuel.Wood)
			elseif stock.Coal >= batch then
				stock.Coal -= batch
				flame = math.min(maxFlame, flame + batch * hearth.Fuel.Coal)
			else
				result.Fuel -= batch
				break
			end
		end
	end

	local discount = if hasBuilder then Roles.ById.Builder.BuildDiscount or 0 else 0
	local turretCost = cost(TURRET.Cost, discount)

	-- The weapon a player would move up to: the hardest-hitting one (as
	-- modelled) the hearth allows at this level, if it beats theirs.
	local function upgradeFor(member, atLevel: number): number?
		local best, bestDps = nil, RunModel.dps(WEAPONS[member.Weapon], member.Role)
		for index = member.Weapon + 1, #WEAPONS do
			local recipe = Recipes.WeaponById[WEAPONS[index]]
			local dps = RunModel.dps(WEAPONS[index], member.Role)
			if recipe.Needs <= atLevel and dps > bestDps then
				best, bestDps = index, dps
			end
		end
		return best
	end

	-- Buys what the team can: the next hearth level, then better weapons,
	-- then turrets.
	local function shop(now: number)
		feed()
		local nextLevel = hearth.Levels[level + 1]
		if nextLevel and afford(stock, nextLevel.Cost, keep()) then
			spend(stock, nextLevel.Cost)
			level += 1
			mark("HearthUp", now)
		end
		for _, member in team do
			local index = upgradeFor(member, level)
			if index then
				local recipe = Recipes.WeaponById[WEAPONS[index]]
				if afford(stock, recipe.Cost, keep()) then
					spend(stock, recipe.Cost)
					member.Weapon = index
				end
			end
		end
		while turrets < maxTurrets and (TURRET.Needs or 1) <= level and afford(stock, turretCost, keep()) do
			spend(stock, turretCost)
			turrets += 1
		end
	end

	-- What the team is saving for: fuel, the next hearth level, and what
	-- the hearth already allows (the next weapon for its worst-armed
	-- player, a turret). Gathering goes where the shortfall would take
	-- longest to fill.
	local function goal(): { [string]: number }
		local want = keep()
		local function add(price)
			for id, amount in price do
				want[id] = (want[id] or 0) + amount
			end
		end
		local nextLevel = hearth.Levels[level + 1]
		if nextLevel then
			add(nextLevel.Cost)
		end
		if level == 1 then
			-- The guide's first-day goal is the first hearth upgrade alone.
			return want
		end
		local worst = team[1]
		for _, member in team do
			if member.Weapon < worst.Weapon then
				worst = member
			end
		end
		local index = upgradeFor(worst, level)
		if index then
			add(Recipes.WeaponById[WEAPONS[index]].Cost)
		end
		if turrets < maxTurrets and (TURRET.Needs or 1) <= level then
			add(turretCost)
		end
		return want
	end

	-- One day: crates, an expedition if the policy says so, and gathering
	-- towards the goal, with the party away for its trip.
	local function day(index: number)
		local start = RunModel.dayStart(index)
		local length = dayLength(index)
		if index > 1 then
			local crates = math.min(Resources.Crate.Count, A.CratesPerPlayer * players)
			for id, amount in Resources.Crate.Contents do
				if stock[id] then
					stock[id] += crates * amount
					result.Gathered += crates * amount
				end
			end
		end
		local party = math.min(players, A.Party(players))
		local leave, back = math.huge, -math.huge
		if #frozen > 0 and goes(index) then
			local landmark = table.remove(frozen, 1)
			local trial = landmark.Trial
			local slowest = math.huge
			local partyDps = 0
			for member = 1, party do
				slowest = math.min(slowest, speedOf(team[member].Role))
				partyDps += RunModel.dps(WEAPONS[team[member].Weapon], team[member].Role)
			end
			local guards = 0
			for _, kind in Waves.guards(index, if Radio.behind(index, parts) then 1 else 0) do
				guards += Enemies.ById[kind].Health
			end
			local out = math.sqrt(landmark.At[1] ^ 2 + landmark.At[2] ^ 2)
			local toRadio =
				math.sqrt((landmark.At[1] - Map.RadioTower[1]) ^ 2 + (landmark.At[2] - Map.RadioTower[2]) ^ 2)
			local home = math.sqrt(Map.RadioTower[1] ^ 2 + Map.RadioTower[2] ^ 2)
			local turns = if trial.Kind == "Saw" then trial.Times or 1 else 1
			local trialSeconds = turns * (trial.Seconds or 1)
			local leaves = start + A.ExpeditionPrep
			local found = leaves + out / slowest + guards / partyDps + trialSeconds + A.ExpeditionOverhead / 2
			local fitted = found + toRadio / slowest + A.ExpeditionOverhead / 2
			local returns = fitted + home / slowest
			local carry = if trial.Kind == "Bring" then trial.Resource :: string else nil
			local enough = not carry or (stock[carry] or 0) >= (trial.Amount or 0)
			if returns < start + length and enough then
				if carry then
					stock[carry] -= trial.Amount or 0
				end
				leave, back = leaves, returns
				mark("FirstPart", found)
				mark("FirstFit", fitted)
				parts += 1
				if parts == #Map.Landmarks - 1 then
					mark("OneToGo", fitted)
				elseif parts == #Map.Landmarks then
					mark("Radio", fitted)
				end
			else
				-- Not back before dark, or nothing to bring: another day.
				table.insert(frozen, 1, landmark)
			end
		end
		local warmup = if index == 1 then A.FirstDayWarmup else 0
		flame -= warmup * hearth.BurnPerSecondDay * burnScale
		local busy = length - warmup
		local steps = 20
		local slice = busy / steps
		for step = 1, steps do
			local now = start + warmup + slice * (step - 0.5)
			-- The team's gathering rate for each resource right now.
			local rates = {}
			for resource in A.Mix do
				local rate = 0
				for member, entry in team do
					if not (member <= party and now >= leave and now <= back) then
						rate += RunModel.gatherRate(resource, entry.Role, players)
					end
				end
				rates[resource] = rate
			end
			local want = goal()
			local shares, total = {}, 0
			for resource, rate in rates do
				local short = math.max(0, (want[resource] or 0) - stock[resource])
				shares[resource] = if rate > 0 then short / rate else 0
				total += shares[resource]
			end
			for resource, rate in rates do
				local share = if total > 0 then shares[resource] / total else A.Mix[resource]
				-- The valley only grows so much.
				local amount = math.min(rate * A.GatherShare * share, RunModel.supply(resource)) * slice
				stock[resource] += amount
				result.Gathered += amount
			end
			flame -= slice * hearth.BurnPerSecondDay * burnScale
			shop(start + warmup + slice * step)
		end
	end

	-- One night: the wave, the boss, the burn.
	local function night(index: number): boolean
		local theme = plan[index]
		local health, douse, count = waveOf(index, players, theme)
		local boss = Waves.boss(index)
		local bossHealth = if boss then Waves.bossHealth(boss, players) else 0
		-- With Config/Features.BossPhases the boss's roars bring help (more
		-- to fight), and it is out of breath after each slam (double damage
		-- for that share of the fight).
		local bossTaken = 1
		if boss and Features.BossPhases then
			local def = Enemies.ById[boss]
			local summons = #(def.Roars or {}) * ((def.SummonCount or 0) + players // 3)
			local summon = Enemies.ById[def.Summon]
			health += summons * summon.Health
			douse += summons * summon.Douse
			count += summons
			local tired = def.Tired or 0
			bossTaken = 1 + tired / (def.Windup + tired + def.Rate)
		end
		local dps = teamDps()
		local capacity = dps * P.Night
		local pressure = (health + bossHealth) / capacity
		local leak = if pressure > 1 then 1 - 1 / pressure else 0
		local lost = douse * A.ChipShare + douse * leak * A.LeakHits + nightBurn
		if boss then
			local spawnAt = P.Night * Balance.Waves.SpawnWindow * 0.5
			local beat = spawnAt + bossHealth / (dps * A.BossFocus * bossTaken)
			if beat <= P.Night then
				if boss == "Yeti" then
					result.BeatYeti = true
					mark("Yeti", RunModel.nightStart(index) + beat)
				end
			else
				lost += Enemies.ById[boss].Douse * A.LeakHits
			end
		end
		flame -= lost
		knockouts += count * (1 - leak)
		table.insert(result.Nights, {
			Night = index,
			Theme = if theme then theme.Id else "",
			WaveHealth = health,
			BossHealth = bossHealth,
			Capacity = capacity,
			Pressure = pressure,
			FlameLost = lost,
			FlameAtDawn = flame,
			Level = level,
			Turrets = turrets,
			BestWeapon = WEAPONS[team[1].Weapon],
			Parts = parts,
			Behind = Radio.behind(index, parts),
		})
		return flame > 0
	end

	for index = 1, Balance.LastNight do
		day(index)
		if not night(index) then
			result.LostOn = index
			break
		end
		if index == 1 then
			mark("Night1", RunModel.dawnEnd(1))
		end
		if parts == #Map.Landmarks and index >= Balance.Nights then
			result.Won = true
			mark("Rescue", RunModel.dawnEnd(index))
			break
		end
	end
	if not result.Won and not result.LostOn then
		-- The blizzard won: the radio was never fixed by the last night.
		result.LostOn = Balance.LastNight
	end
	result.Knockouts = knockouts / players
	result.Parts = parts
	return result
end

-- What a lost run looks like for the economy: snowed under on a night,
-- with some parts fitted and some monsters bopped.
function RunModel.loss(night: number, parts: number, knockouts: number): Result
	return {
		Players = 4,
		Gathered = 0,
		Fuel = 0,
		Roles = {},
		Policy = "Lost",
		Won = false,
		LostOn = night,
		Nights = {},
		Milestones = {},
		Knockouts = knockouts,
		Parts = parts,
		BeatYeti = night > 5,
	}
end

---------------------------------------------------------------------------
-- Snowflakes

-- What a run pays each player, from a modelled result.
function RunModel.flakes(result: Result): number
	return Profile.runFlakes({
		Nights = if result.Won then #result.Nights else result.LostOn or #result.Nights,
		Parts = result.Parts,
		Won = result.Won,
		Knockouts = math.floor(result.Knockouts),
	})
end

-- Minutes a run takes from the first day to the next run starting.
function RunModel.runMinutes(result: Result): number
	local last = result.LostOn or #result.Nights
	local seconds = RunModel.dawnEnd(last) + P.Results + P.Intermission
	if result.Won then
		seconds += 14
	end
	return seconds / 60
end

-- The snowflake economy for a player winning winRate of their runs with a
-- team like this one: flakes and minutes per run on average, and how many
-- runs and hours to the first role, the whole pass and everything in the
-- shop.
function RunModel.economy(win: Result, loss: Result, winRate: number)
	local flakes = winRate * RunModel.flakes(win) + (1 - winRate) * RunModel.flakes(loss)
	local minutes = winRate * RunModel.runMinutes(win) + (1 - winRate) * RunModel.runMinutes(loss)
	local cheapestRole, allRoles = math.huge, 0
	for _, role in Roles.List do
		if role.Price > 0 then
			cheapestRole = math.min(cheapestRole, role.Price)
			allRoles += role.Price
		end
	end
	local Cosmetics = RobloxLoader.require("src/shared/Config/Cosmetics")
	local Decor = RobloxLoader.require("src/shared/Config/Decor")
	local shop = 0
	for _, list in { Cosmetics.List, Decor.List } do
		for _, item in list do
			if item.Source == "Shop" then
				shop += item.Price
			end
		end
	end
	local passXp = Expedition.TierXp * #Expedition.Tiers
	return {
		FlakesPerRun = flakes,
		MinutesPerRun = minutes,
		RunsToFirstRole = cheapestRole / flakes,
		HoursToFirstRole = cheapestRole / flakes * minutes / 60,
		RunsToPass = passXp / (flakes * Balance.Rewards.XpPerFlake),
		RunsToEverything = (allRoles + shop) / flakes,
		ShopTotal = shop + allRoles,
	}
end

---------------------------------------------------------------------------
-- Roles side by side

-- Each role's own output under the same conditions (a team of four, day
-- one, the torch and the sling): what it gathers, what it hits, what it
-- does for the team.
function RunModel.roleSheet()
	local sheet = {}
	for _, role in Roles.List do
		local gather = 0
		for resource, mix in A.Mix do
			gather += RunModel.gatherRate(resource, role, 4) * mix
		end
		table.insert(sheet, {
			Id = role.Id,
			Price = role.Price,
			GatherPerMinute = gather * 60,
			TorchDps = RunModel.dps("Torch", role),
			SlingDps = RunModel.dps("EmberSling", role),
			BuildDiscount = role.BuildDiscount or 0,
			TeamUptime = if role.Id == "Cook" then A.CookUptime elseif role.Id == "Medic" then A.MedicUptime else 0,
		})
	end
	return sheet
end

-- The team compositions the fairness checks compare.
RunModel.Compositions = {
	Free = { "Scout", "Builder", "Cook", "Scout" },
	FreeRanger = { "Scout", "Builder", "Cook", "Ranger" },
	FreeMedic = { "Scout", "Builder", "Cook", "Medic" },
	AllScouts = { "Scout", "Scout", "Scout", "Scout" },
	AllBuilders = { "Builder", "Builder", "Builder", "Builder" },
	AllCooks = { "Cook", "Cook", "Cook", "Cook" },
	AllRangers = { "Ranger", "Ranger", "Ranger", "Ranger" },
	AllMedics = { "Medic", "Medic", "Medic", "Medic" },
}

-- A team of n players with the free roles in turn.
function RunModel.team(players: number): { string }
	local free = { "Scout", "Builder", "Cook" }
	local list = {}
	for index = 1, players do
		table.insert(list, free[(index - 1) % #free + 1])
	end
	return list
end

-- The highest pressure over the first Balance.Nights nights.
function RunModel.peak(result: Result): number
	local peak = 0
	for _, entry in result.Nights do
		if entry.Night <= Balance.Nights then
			peak = math.max(peak, entry.Pressure)
		end
	end
	return peak
end

-- The lowest flame at any dawn.
function RunModel.lowest(result: Result): number
	local low = math.huge
	for _, entry in result.Nights do
		low = math.min(low, entry.FlameAtDawn)
	end
	return low
end

return RunModel
