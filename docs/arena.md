# PvP arena

An opt-in place to fight other players with themed weapons, added on 2026-10-27 at the owner's request ("maybe add a pvp area", then themed weapons, some free and some paid). The numbers are first guesses for playtesting.

## Where it is

A raised round stage, 32 studs in radius, straight past the bonfire through the gateway at the back of the plaza. Its entrance faces the plaza, up a short ramp, under an arch with the name **BONK ARENA**. A low stone wall marks the edge, a glowing purple ring on the floor sits just inside it, and four braziers send beams of light up through the fog so it can be seen from the spawn. A ghost referee floats over the middle. `ArenaService` makes the stage and ramp; the theme's `Arena.luau` dresses it.

## How a fight works

- **Opt in by walking in.** Standing on the stage makes you a fighter, and stepping off makes you safe. Nobody outside can hit or be hit, so the plaza and plots stay peaceful.
- **Arriving.** You get a 2-second shield (the Roblox force field bubble) so nobody can bonk you at the door. If you have no weapon, the arena lends you a **Pumpkin Bonker** and takes it back when you leave. If you have a weapon from the cosmetics, it is equipped instead.
- **Swing** by clicking or tapping (the Tool's normal activation). **Special move** with **E**, gamepad **X**, or the on-screen button on phones and tablets. The panel under the cash counter shows the move's name and a bar that fills as it gets ready.
- **Hits** take health and throw the target back and a little up. The server decides every hit: who was in reach and in front, whether the cooldown had passed, and how much damage. A client only says it swung or used its special.
- **Knockouts.** At no health you are not killed. You tumble with dizzy stars for 2 seconds and are put outside the entrance at full health, facing back in, so you can walk straight back. Whoever knocked you out scores a **KO**.
- **Rewards.** KOs are saved and shown as a **KOs** column on the leaderboard, and a streak shows on screen ("3 in a row!"). Fights never give or take coins, so friends can't farm each other for money and the tycoon's pacing is untouched.

## Weapons

Every weapon is a **style** at a **tier**. The style sets how it fights; the tier sets how hard it hits. All of it is in `src/shared/Config/Weapons.luau`.

| Style | Feel | Damage | Swing every | Reach | Arc either side | Knockback |
| --- | --- | --- | --- | --- | --- | --- |
| Mallet | slow, heavy, throws people | 16 | 0.8 s | 7.5 | 55° | 60 |
| Sweep | long and wide, lighter | 11 | 0.65 s | 9.5 | 75° | 45 |
| Claw | quick and close | 8 | 0.4 s | 6 | 60° | 28 |
| Blade | in between | 12 | 0.6 s | 8 | 60° | 40 |

| Tier | Damage | Who gets it |
| --- | --- | --- |
| Starter | ×1.0 | the loaned bonker |
| Earned | ×1.1 | free weapons unlocked by playing |
| Elite | ×1.2 | the best free weapon, unlocked near the end of a full run |
| Premium | ×1.2, plus one edge | bought with Robux |

Special moves, on their own cooldown:

| Kind | What it does | Damage | Cooldown |
| --- | --- | --- | --- |
| Slam | leap and pound the ground, hitting everyone within 11 studs | 24 | 8 s |
| Dash | charge 26 studs forward, hitting everyone in the way | 20 | 6 s |
| Spin | whirl round, hitting everyone within 10 studs | 18 | 7 s |
| Wave | send a wave 45 studs forward that hits the first person it reaches | 20 | 7 s |

Special damage is scaled by tier too.

### Roster

| Weapon id | Name of its special | Style | Tier | Special | Edge |
| --- | --- | --- | --- | --- | --- |
| `bonker` | Pumpkin Pound | Mallet | Starter | Slam | |
| `mallet` | Ground Thump | Mallet | Earned | Slam | |
| `broom` | Broom Dash | Sweep | Earned | Dash | |
| `claws` | Moon Pounce | Claw | Earned | Dash | |
| `moon_saber` | Crescent Wave | Blade | Elite | Wave | |
| `thunder_hammer` | Thunderfall | Mallet | Premium | Slam | +10% knockback |
| `ghost_blade` | Phantom Crescent | Blade | Premium | Wave | +10% reach |
| `reaper_scythe` | Soul Whirl | Sweep | Premium | Spin | +10% arc |
| `trident` | Riptide Charge | Blade | Premium | Dash | +10% damage |
| `foxfire_fan` | Foxfire Whirl | Claw | Premium | Spin | swings 10% faster |

The weapons' names, models, unlocks and prices belong to the cosmetics (`Config/Cosmetics.luau` and the theme's `Wearables.luau`, from the flex items and paid cosmetics work). A held cosmetic names one of the weapon ids above, so a paid skin of a free weapon fights exactly like it. Designs are original, drawing on public-domain myth and folklore (a Norse-style thunder hammer, a sea god's trident, a kitsune's foxfire fan) and nothing trademarked: the moon saber and ghost blade are glowing blades with their own hilts and sounds, not lightsabers.

Each special has its own effects, drawn on every client by `client/ArenaEffects.luau`. The premium ones are the showiest: Thunderfall calls six lightning bolts down round where the hammer lands, with a pillar of light, two shockwaves and a camera shake; Soul Whirl spins green spirits round the reaper; Foxfire Whirl sends blue fox-flames spiralling out; Riptide Charge leaves a spray of water and bursts into geysers; Phantom Crescent flies out trailing ghostly wisps.

## Paid weapons have a small edge

This is the owner's decision (2026-10-27): about five expensive weapons that are "lowkey pay to win but not excessive", with only a "slight edge over the most expensive" free items. It is an exception to the brief's rule that purchases are cosmetic only, and it applies only in the arena: paid weapons never touch coins, income or tycoon progress.

How it's kept slight:

- A premium weapon hits exactly as hard as an Elite (best free) weapon of its style, plus **one** edge: a single stat 10% better (`PREMIUM_EDGE = 1.1`).
- Its special move hits exactly as hard as an Elite one. The difference is how it looks.
- In practice a premium weapon needs at most one fewer swing to knock someone out than the best free weapon. Against the best free weapon, the moon saber, none of them knocks out faster: a full-health player takes 3.6 s of swinging with the saber and 3.6 to 4.6 s with the premium weapons, which instead get reach, knockback, a wider arc or a quicker swing.
- `tests/Arena.spec.luau` fails if the edge goes over 15%, if a premium weapon differs from Elite in more than its one edge stat, if its special hits harder than Elite, or if it knocks out in more than one fewer hit.

To make paid weapons exactly as strong as the best free weapon (no edge, the brief's original rule), set `PREMIUM_EDGE` to `1` in `Config/Weapons.luau`. Revisit this before launch alongside the brief.

## Safety and rating

- Opt-in only, and the arena is a clearly bounded space away from the plots.
- Cartoon violence: bonks, knockback, dizzy stars and sparks. No blood, gore or death. Combined with the spooky look, the game should answer the Maturity & Compliance questionnaire for **Mild** (repeated mild violence, mild fear), which fits players aged 9 to 12.
- Messages show Roblox display names only, and nothing about a fight is sent anywhere or stored beyond each player's own KO count.

## How the pieces fit

- `Config/Arena.luau`: where the stage goes, its size, and the rules (health, shield, knockout time, knockback lift, cooldown slack for network jitter).
- `Config/Weapons.luau`: styles, tiers, specials, roster and the premium edge. It returns a plain map of weapon id to stats, so other code can read `Weapons[id].Cooldown`.
- `shared/Combat.luau`: the pure geometry of who a swing, slam, charge or wave reaches, and which way a hit throws someone. Tested.
- `server/Services/ArenaService.luau`: makes the stage, makes and unmakes fighters as they walk in and out, lends the bonker, listens to `Activated` on any Tool with a `Weapon` attribute, runs specials, deals hits and knockouts, and saves KOs (`Arena.KOs` in the save).
- Remotes: `ArenaAction` (client to server, `"Special"`) and `ArenaEffect` (server to every client: `"Hit"`, `"KnockOut"`, `"Special"` and `"Impact"`, with who, which weapon, and a velocity or position). A hit player's own client applies the throw, because it is the one that moves its character.
- `client/Arena.luau` and `client/ArenaEffects.luau`: the panel, the special move button, the player's own leaps and charges, messages, and all the effects.
- The swing animation, swing sound and dust puff are played by the cosmetics code for any Tool with a `Weapon` attribute, the bonker included, using Roblox's built-in tool slash animation.

## Not done yet

- The arena's four sounds are made by `tools/make_arena_sounds.py` and need uploading like the rest (see the README).
- Custom swing animations would need uploaded animation assets; for now every weapon uses the built-in slash, with the special moves' movement done in code.
- Balance needs playtesting with real players, especially the Claw style's many small hits and how far knockback throws people.
