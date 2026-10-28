--!strict
-- The arena's weapons, keyed by weapon id. A held item in the cosmetics config
-- names one of these ids, so a paid skin and the free weapon it reskins share
-- one entry and fight the same. Plain numbers, so this loads in tests as well
-- as in Studio. Values are first guesses for playtesting.
--
-- A weapon is a Style, which sets how it fights, at a Tier, which sets how
-- hard it hits:
--   Starter  the bonker the arena lends anyone who walks in empty-handed.
--   Earned   unlocked by playing.
--   Elite    the best free weapons, unlocked near the end of a full run.
--   Premium  bought with Robux. The game's owner chose to give these a slight
--            edge over the Elite weapons: they hit exactly as hard as Elite,
--            plus one Edge, a single stat PREMIUM_EDGE better (a shorter
--            Cooldown, or more of anything else). Set PREMIUM_EDGE to 1 to
--            make them exactly as strong as Elite. See docs/arena.md.
--
-- Every weapon has these, worked out below from its style and tier:
--   Damage     health taken by a swing, out of Config/Arena's Health.
--   Cooldown   seconds between swings.
--   Reach      studs from the attacker to whoever they hit.
--   Arc        degrees either side of straight ahead that a swing reaches.
--   Knockback  studs per second the target is thrown.
--   Special    a move on its own cooldown, of one of the kinds in Specials,
--              with its numbers copied in and its Damage scaled by tier.

local PREMIUM_EDGE = 1.1

local Styles = {
	-- Slow, heavy hits that throw people.
	Mallet = { Damage = 16, Cooldown = 0.8, Reach = 7.5, Arc = 55, Knockback = 60 },
	-- Long and wide, but lighter.
	Sweep = { Damage = 11, Cooldown = 0.65, Reach = 9.5, Arc = 75, Knockback = 45 },
	-- Quick and close.
	Claw = { Damage = 8, Cooldown = 0.4, Reach = 6, Arc = 60, Knockback = 28 },
	-- In between.
	Blade = { Damage = 12, Cooldown = 0.6, Reach = 8, Arc = 60, Knockback = 40 },
}

local Tiers = {
	Starter = 1,
	Earned = 1.1,
	Elite = 1.2,
	Premium = 1.2,
}

local Specials = {
	-- Leaps up and pounds the ground after Delay, hitting everyone within
	-- Radius of where they land.
	Slam = { Damage = 24, Cooldown = 8, Radius = 11, Knockback = 75, Delay = 0.55 },
	-- Charges Distance studs forward over Seconds, hitting everyone in the way.
	Dash = { Damage = 20, Cooldown = 6, Distance = 26, Width = 5, Knockback = 60, Seconds = 0.4 },
	-- Whirls round for Seconds, hitting everyone within Radius once.
	Spin = { Damage = 18, Cooldown = 7, Radius = 10, Knockback = 55, Seconds = 0.6 },
	-- Sends a wave Distance studs forward at Speed that hits the first
	-- fighter it reaches.
	Wave = { Damage = 20, Cooldown = 7, Distance = 45, Width = 5, Knockback = 50, Speed = 80 },
}

local Roster = {
	bonker = { Style = "Mallet", Tier = "Starter", Special = "Slam" },
	mallet = { Style = "Mallet", Tier = "Earned", Special = "Slam" },
	broom = { Style = "Sweep", Tier = "Earned", Special = "Dash" },
	claws = { Style = "Claw", Tier = "Earned", Special = "Dash" },
	moon_saber = { Style = "Blade", Tier = "Elite", Special = "Wave" },
	thunder_hammer = { Style = "Mallet", Tier = "Premium", Special = "Slam", Edge = "Knockback" },
	ghost_blade = { Style = "Blade", Tier = "Premium", Special = "Wave", Edge = "Reach" },
	reaper_scythe = { Style = "Sweep", Tier = "Premium", Special = "Spin", Edge = "Arc" },
	trident = { Style = "Blade", Tier = "Premium", Special = "Dash", Edge = "Damage" },
	foxfire_fan = { Style = "Claw", Tier = "Premium", Special = "Spin", Edge = "Cooldown" },
}

local Weapons: { [string]: any } = {}

for id, entry in Roster do
	local style = Styles[entry.Style]
	local power = Tiers[entry.Tier]
	local special: { [string]: any } = table.clone((Specials :: any)[entry.Special])
	special.Kind = entry.Special
	special.Damage *= power
	local weapon: { [string]: any } = {
		Style = entry.Style,
		Tier = entry.Tier,
		Edge = (entry :: any).Edge,
		Damage = style.Damage * power,
		Cooldown = style.Cooldown,
		Reach = style.Reach,
		Arc = style.Arc,
		Knockback = style.Knockback,
		Special = special,
	}
	local edge = weapon.Edge
	if edge == "Cooldown" then
		weapon.Cooldown /= PREMIUM_EDGE
	elseif edge then
		weapon[edge] *= PREMIUM_EDGE
	end
	Weapons[id] = weapon
end

-- What the weapons are made from, for the tests. It sits behind the metatable
-- so that going through Weapons gives only weapons.
return setmetatable(Weapons, {
	__index = { Styles = Styles, Tiers = Tiers, Specials = Specials, PremiumEdge = PREMIUM_EDGE },
})
