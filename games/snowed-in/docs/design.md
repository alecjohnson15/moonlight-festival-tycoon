# Design notes

What Snowed In is trying to be, and the rules the code keeps to. The numbers
live in `src/shared/Config/`; this explains why they are what they are.

## The pitch

A cosy-scary co-op night survival game, original IP: a buried mountain town,
a hearth that must not go out, and a rescue train you have to call. It sits
in the "survive N nights" genre, made distinct by:

- **A shared life bar.** The hearth's flame is the team's life, so everyone's
  day work (chopping, digging, feeding, building) visibly keeps everyone
  alive. Warmth is personal; the hearth is shared.
- **A goal beyond surviving.** Four radio parts frozen at four landmarks give
  the day a direction and a reason to split up, and a run a proper ending
  (the train pulls in at dawn).
- **Roles that need each other.** Scout finds, Builder builds, Cook feeds,
  Ranger fights, Medic thaws. Three are free; two are earnable in about three
  wins or bought as passes.
- **A home between runs.** Every player has a cabin on the town square whose
  decorations are saved, so progress shows in the world, not just a menu.

## Audience and rating

Players 9 to 12, so the rating is Mild: cartoon snow monsters with glowing
eyes that puff into snow; players never die, they freeze in ice and are
thawed. No blood, no gore, no jump scares. No chat-like text input anywhere
(cabins are decorated from lists). No personal data beyond what Roblox gives
a game (user id, display name).

## The run

| Part | Length | What happens |
| --- | --- | --- |
| Intermission | 30 s | Pick a role, look round |
| First day | 3.5 min | Learn the loop; a few guards wait at each landmark |
| Day | 2.5 min | Gather, build, find a radio part |
| Dusk | 20 s | Horn, sky turns, get back |
| Night | 2 min | Waves come for the hearth; cold bites almost 4x faster |
| Dawn | 12 s | Chime, supply crates drop, frozen players wake |

Ten nights is about 52 minutes. The hearth starts at 80 flame and burns 7 a
minute by day, 18 by night: it survives the first night unfed and goes out
on the second day if nobody feeds it (`tests/Balance.spec.luau` checks this).
A day's fuel is about a minute of one player's chopping, so feeding never
crowds out exploring. Coal is worth three wood and is slower to reach.

Waves are bought with a points budget that grows each night and scales with
players (0.6x solo up to 2x at six or more). Bosses come on nights 5 and 10,
with health scaled the same way. If the radio isn't fixed by night 10 the
run goes into overtime with faster-growing waves until night 15.

### Pacing and milestones

`tools/RunModel.luau` plays whole runs second by second from these numbers
for 1, 2, 4 and 8 players, at three radio paces (steady, eager, never), and
`lune run tools/simulate_run` prints it. Its guesses about how players spend
their time are listed in `RunModel.Assumptions`. The team milestones and
their design targets (`shared/Milestones.luau`, checked against the model
by `tests/Pacing.spec.luau`) are: first hearth upgrade (3 min), first night
(6), first part found (13) and fitted (15), the Old Yeti (25), three parts
in (33), the radio fixed (40) and the rescue (52). The guide makes the first
hearth upgrade the first day's team goal, so there is a win in the first few
minutes. A team that goes for the radio every day can fix it by about
minute 23; the train still comes after night 10, which keeps the ten-night
challenge.

### Nights that differ

Every night has a theme, planned for the whole run from a seed
(`shared/Waves.luau`): Frostling Crowd (many small ones at the fire: swing
and use turrets), Hound Pack (fast, they hunt players: stay together), Brute
Siege (they smash walls: keep wood for repairs, traps slow them), Wisp Swarm
(they fly over walls and throw ice: slings, flares and turrets) and Whiteout
(a bit of everything). Night 1 is always the crowd, each monster's first
night is its own theme so it gets introduced, and no theme comes twice in a
row. The theme's name and tip show in the HUD from the morning before and in
the guide at dusk.

### Bosses

The yetis wind up each slam: a red ring shows where it will land for about a
second, so players can step out. After a slam the boss is out of breath for
about two seconds and takes double damage: that is the moment to hit it. At
two-thirds and one-third health (the Elder Yeti at three-quarters, half and
a quarter) it roars and calls a few frostlings (hounds for the Elder Yeti). The boss bar says what
is happening ("SLAM coming", "out of breath! Hit it now!").

### Radio parts

Each landmark frees its part its own way (`Config/Map.luau`, rules in
`shared/Radio.luau`): saw the sawmill's frozen logs (three goes, anyone can
help), melt the ice cave's block with a fire tool in hand, light the
lighthouse fire with 6 wood from your backpack, pry the depot crate with 4
scrap. Guards wait at each landmark. A player carries one part at a time; a
carrier who freezes, leaves or falls drops it where they were, and a part
left loose for 90 seconds goes back to its landmark, so it can't be lost. A
team behind the expected pace (one part every two nights from night 4) gets
the missing parts marked on screen and one guard fewer at each.

### Small teams

With one or two players the gathering holds are 30% (or 15%) quicker and the
hearth burns at 80% (or 90%) of its rate (`Balance.SoloAssist`). The run
model says a solo player wins at the steady pace and spends about a sixth
of what they gather on fuel; without the help it is about a fifth.

### Building

Each player may own an even share of the base's 60 structures (at least 15),
so one player can't spend the whole cap. A player can take down their own
build for half its cost back (nothing for a badly damaged one). Builds of a
player who leaves can be taken down by anyone.

## Knockouts

The cold and monster hits both take warmth, and at zero a player freezes
in a block of ice.
A teammate holds the thaw prompt for 3 seconds (the Medic for 1), or after 25
seconds they wake up by the hearth, which costs it 4 flame. So getting
frozen is never a long sit-out, but a careless team pays for it in flame.
After a thaw a player can't be chilled again for 4 seconds, so nobody is
frozen over and over on the spot. The HUD shows how long until you freeze
when you are losing warmth.

## After a run

The results screen shows whether the train came, the team's milestones, the
team's best, what this player did (things gathered, flame fed, builds,
repairs, friends thawed, parts freed and fitted, monsters bopped), what they
earned and their next goal (the cheapest locked role, the next pass tier, a
trophy). A run pays each player once: the save records the run's id. A
player who joined late gets the win bonus only after 3 nights, and the radio
parts only after seeing a night.

## Money

All Robux items are game passes with their contents stated up front. No loot
boxes, no paid random items, no currency packs. The two role passes are early
access to the Ranger and the Medic, roles anyone can earn with 600 snowflakes
(three to five runs). They are sidegrades with a small real edge: the Ranger
hits about a third harder and the Medic thaws in a second, which the run
model (tools/RunModel.luau) puts at a 5 to 7% easier hardest night for a team
of four. Free roles win every modelled run without them. The rest are
outfits, pets, a trail and cabin decorations. The Expedition Pass
premium row is shown in full before buying and still has to be earned by
playing. Snowflakes can't be bought.

## Server authority and safety

The server decides everything that matters: what a player carries, what's
in the stockpile, where a structure may go and what it costs, all damage,
warmth, freezing, radio parts, rewards and purchases. Every remote checks its
argument types and has a rate limit (`server/Lib/Net.luau`). Saves use
session locking and migrations (`server/Lib/SessionLock.luau`,
`Migrations.luau`), and receipts are recorded so nothing is granted twice.

## Performance

- The town is about 2,100 parts with 7 lights, all built from code
  (`shared/World/Town.luau`) and checked by the tests.
- Each structure has a part budget (`Config/Structures.luau`, checked by
  `tests/Config.spec.luau`) and a run holds at most 60 structures.
- At most 60 monsters are alive at once; extra spawns wait. Monsters are
  simulated on the server without physics (`shared/EnemySim.luau`) and sent
  ten times a second as one packed buffer (`shared/Codec.luau`). Clients draw
  them from pooled models with `BulkMoveTo`, and update far ones less often.
- Monster models stay under 40 parts each.
- The Settings window has a diagnostics line: frame rate, ping, monsters
  drawn, builds out of 60, and how long the server's monster step takes
  (published once a second). These are counters for testers, not measured
  results: no device has been measured yet.

## Settings and accessibility

Music on or off, effects volume (100, 50 or 0%), and reduce motion (fewer
particles, no camera shake), saved with the player's progress and checked
by the server.

## Analytics

The server reports two funnels through Roblox's AnalyticsService
(`server/Lib/Analytics.luau`, steps in `shared/Funnel.luau`): a new player's
first session (joined, picked a role, gathered, dropped off, fed the hearth,
survived night 1, found a part, fitted a part, finished a run) and every run
(started, survived night 1, found a part, fitted a part, night 5, radio
fixed, rescued), plus a RunWon or RunLost event with the night reached. The
only extra field is the player's role. Nothing else about the player is
sent, and every call is wrapped so a failure can't break the game.

## Sound

Every sound and the three songs are synthesised by `tools/make_sounds.py`
(numpy and ffmpeg), so they are original and can be rebuilt. Until uploaded,
each sound falls back to a built-in Roblox sound or stays silent.
