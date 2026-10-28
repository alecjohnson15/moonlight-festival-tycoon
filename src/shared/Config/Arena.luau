--!strict
-- The PvP arena: where it is, its size, and the rules of a fight. Plain
-- numbers so this file loads in tests as well as in Studio. The weapons are in
-- Config/Weapons.

return {
	-- A raised round stage past the bonfire, on the plaza's centre line. Its
	-- middle is Distance studs beyond the back edge of the plaza, and its
	-- entrance faces the plaza.
	Distance = 92,
	Radius = 32,
	-- The stage's top, in studs above the ground. High enough that the grass
	-- can't show through it.
	Height = 2,
	-- The gap in the arena wall, and the ramp up to it.
	EntranceWidth = 10,
	RampLength = 7,

	Health = 100,
	-- Nobody can be hit for this long after walking in, so a player isn't
	-- bonked the moment they arrive.
	ShieldSeconds = 2,
	-- How long a knocked-out player lies dizzy before being put outside the
	-- entrance, where they can walk straight back in.
	KnockedOutSeconds = 2,
	-- Where they are put, in studs in front of the entrance.
	ExitDistance = 10,
	-- Hits only land on fighters within this many studs above or below.
	HitHeight = 6,
	-- Every knockback also lifts its target this fast, in studs per second, and
	-- a knockout throws them KnockoutThrow times as far and higher.
	Lift = 22,
	KnockoutThrow = 1.5,
	KnockoutLift = 40,
	-- Swings and specials arriving up to this much early still count, to
	-- allow for network jitter. A fraction of the cooldown.
	CooldownSlack = 0.1,
}
