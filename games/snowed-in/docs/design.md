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

## Knockouts

The cold and monster hits both take warmth, and at zero a player freezes
in a block of ice.
A teammate holds the thaw prompt for 3 seconds (the Medic for 1), or after 25
seconds they wake up by the hearth, which costs it 4 flame. So getting
frozen is never a long sit-out, but a careless team pays for it in flame.

## Money

All Robux items are game passes with their contents stated up front. No loot
boxes, no paid random items, no currency packs, no paid power in a run: the
two role passes unlock roles anyone can earn with 600 snowflakes, and the
rest are outfits, pets, a trail and cabin decorations. The Expedition Pass
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

## Sound

Every sound and the three songs are synthesised by `tools/make_sounds.py`
(numpy and ffmpeg), so they are original and can be rebuilt. Until uploaded,
each sound falls back to a built-in Roblox sound or stays silent.
