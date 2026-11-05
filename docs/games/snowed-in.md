# Snowed In: Survive 10 Nights

*Keep the fire lit. Fix the radio. Catch the last train out.*

| | |
| --- | --- |
| **Genre** | Co-op survival ("survive N nights") |
| **Players** | 1 to 8 per server |
| **Session** | About 52 minutes per run |
| **For** | Ages 9 to 12, aimed at Roblox's **Mild** label (cartoon monsters, no gore) |
| **Status** | Built, all checks pass, **not yet played in Studio**, not yet on Roblox |
| **Code** | `games/snowed-in/` (its own Rojo project), branch `claude/project-thread-wo6c7j` |
| **Pull request** | [PR #14](https://github.com/alecjohnson15/moonlight-festival-tycoon/pull/14) (open) |
| **Place file** | `/mnt/project-files/release/snowed-in.rbxl` |
| **Release kit** | `/mnt/project-files/snowed-in/` (launch.md, passes.json, pass icons, a zip of the sounds and icons) |
| **Build thread** | "Build a co-op base survival game" |

## What it is

A blizzard has buried the mountain town of Pinehollow. The Great Hearth in the
town square is the only thing keeping everyone alive, and the rescue train
won't come until someone fixes the radio. Up to 8 friends chop wood, dig coal,
build defences and fight off waves of cartoon snow monsters for 10 nights.

What makes it different from other "survive the nights" games:

- **A shared life bar.** The hearth's flame is the team's life. Everyone's
  day work visibly keeps everyone alive.
- **A goal beyond surviving.** Four radio parts are frozen at four landmarks.
  Fixing the radio calls the train and gives the run a real ending.
- **Roles that need each other.** Scout finds, Builder builds, Cook feeds,
  Ranger fights, Medic thaws.
- **A home between runs.** Every player gets a cabin on the square and
  decorates it. The choices are saved.

## How a run plays

| Part | Length | What happens |
| --- | --- | --- |
| Intermission | 30 s | Pick a role and look around |
| First day | 3.5 min | Learn the loop; a few guards wait at each landmark |
| Day | 2.5 min | Chop pines, dig coal, stone and scrap, fish, pick frostberries. Feed and upgrade the hearth, build, craft, cook, look for a radio part |
| Dusk | 20 s | The horn sounds and the sky turns. Get back to town |
| Night | 2 min | Waves of snow monsters come for the hearth. Away from heat you get cold almost 4x faster |
| Dawn | 12 s | A chime, supply crates drop, frozen players wake up |

- **Radio:** break the four parts out of the ice at the Sawmill, the Ice
  Cave, the Lighthouse and the Depot, and carry them to the radio tower. Once
  all four are fitted, the train comes at the dawn after night 10. Miss it and
  the nights carry on, harder each time, up to night 15.
- **Bosses:** the Old Yeti on night 5 and the Elder Yeti on night 10.
- **Monsters:** Frostlings, Snow Hounds, Snow Brutes and Ice Wisps. Waves
  scale with the number of players (0.6x solo up to 2x at six or more).
- **Getting knocked out:** the cold and monster hits take warmth. At zero you
  freeze in a block of ice. A friend holds the thaw prompt for 3 seconds (the
  Medic for 1), or after 25 seconds you wake up by the hearth, which costs it
  some flame. Nobody dies.
- **Building:** Log and Stone Walls, Lantern Posts, Ember Traps, Campfires,
  Ember Turrets and Blaze Towers, placed on a grid.
- **Weapons:** Torch, Ember Sling, Flare Pistol, Blaze Blower and the
  Sunstone Cannon, crafted at the workbench.

Win or lose, everyone earns snowflakes and Expedition Pass XP.

## Roles

| Role | Good at | Ability (Q) | How to get it |
| --- | --- | --- | --- |
| Scout | Fast, big pack | Scout Flare: shows monsters, parts and crates for 12 s | Free |
| Builder | Cheaper building, faster repairs, Blaze Towers | Quick Fix: repairs nearby structures by 40% | Free |
| Cook | Better meals, warms the team | Hot Cocoa: +30 warmth for everyone nearby | Free |
| Ranger | Hits harder, sees monster health | Ember Volley: next 6 hits do double damage | 600 snowflakes or pass |
| Medic | Thaws friends quickly | Heat Pack: thaws every frozen friend nearby | 600 snowflakes or pass |

600 snowflakes is about three wins.

## Between runs

- **Shop:** snowflakes buy outfits (hats, backs, trails, pets), roles and
  cabin decorations.
- **Your cabin:** one of the town's eight, with a roof, wreath, lantern,
  yard, flag and glow to choose. Saved and back next time.
- **Expedition Pass:** 13 tiers with a free reward on each, and a premium row
  for pass owners. Every reward is shown before buying and still has to be
  earned by playing.

## Controls

- **Computer:** WASD, hold **E** to use, click to swing or shoot, **Q**
  ability, **G** eat, **B** build (click to place, **R** to turn).
- **Phone and tablet:** on-screen buttons for ability, eating and building.
- **Controller:** **Y** ability, **X** eat, **R1** place while building.

## Money (Robux)

9 game passes, all direct purchases with their contents stated up front. No
loot boxes, no paid random items, no currency packs, nothing that makes a run
easier to win. Snowflakes can't be bought. Supply crates in the snow are free
and always hold the same mix, written on the crate.

| Pass | What it gives | Robux |
| --- | --- | --- |
| Ranger Role | The Ranger role now (also earnable with 600 snowflakes) | 149 |
| Medic Role | The Medic role now (also earnable with 600 snowflakes) | 149 |
| Expedition Pass: Premium | The premium row: 13 extra rewards, still earned by playing | 299 |
| Aurora Cape | A cape that shimmers like the northern lights | 129 |
| Icicle Crown | A crown of glowing icicles | 99 |
| Aurora Trail | A trail of northern lights | 79 |
| Penguin Buddy | A pet penguin in a tiny scarf | 149 |
| Arctic Fox Buddy | A pet arctic fox | 149 |
| Cozy Cabin Pack | Four cabin decorations | 199 |

The 9 pass icons are made (`assets/marketing/passes/` and the release kit).

## Safety and fairness

- The server decides everything that matters: what you carry, the stockpile,
  building, damage, warmth, freezing, radio parts, rewards and purchases.
  Every remote is type- and rate-checked.
- Saves use session locking and migrations, and receipts are recorded so
  nothing is granted twice.
- No text input anywhere; cabins are decorated from lists. No personal data
  beyond the Roblox user id and display name.
- Performance: about 2,100 parts and 7 lights for the town, at most 60
  monsters and 60 structures at once, monsters simulated on the server
  without physics and drawn on clients from pooled models.

## Status

- Built and pushed in PR #14. 90 Lune tests pass, lint and format are clean,
  and CI is green.
- **Nobody has played it in Studio yet.** Play a run before going public.
- 45 original sounds and 3 songs are made but not uploaded. Until they are,
  the game plays built-in Roblox sounds or nothing.
- Pass ids are 0 (the shop shows **Coming soon** until they're set).
- **Store icon and thumbnail are not made yet.** The prompts for your AI image
  tool are in `games/snowed-in/docs/marketing.md`.

## How to publish

The quick way, with an API key (the same as Halloween Tycoon):

1. **Create the experience.** On the
   [Creator Hub](https://create.roblox.com/dashboard/creations), click
   **Create Experience** (an empty one is fine). Or open `snowed-in.rbxl` in
   Studio and use **File > Publish to Roblox > Create new experience** once.
2. **Copy two ids.** The **universe id** is the number after
   `/experiences/` in the address bar. The **place id** is on the Places tab,
   under **⋯ > Copy Place ID**.
3. **Make an Open Cloud API key** on the
   [API Keys page](https://create.roblox.com/dashboard/credentials). Add these
   API systems, choosing this experience where it asks:
   - `universe-places`: write (publish the place file)
   - `universe`: write (name, description, devices)
   - `universe.place`: write (8 players per server)
   - `game-pass`: read and write (the 9 passes)
   - `asset`: read and write (upload the 45 sounds)
   - optional `legacy-universe`: manage (icon and thumbnails, once they exist)

   Set an expiry a few days out and add your PC's IP under Accepted IP
   Addresses (or `0.0.0.0/0` with that short expiry).
4. **Paste the key, the universe id and the place id** in the "Build a co-op
   base survival game" thread and say **"go ahead"**. From your PC, Claude
   uploads the sounds, creates the 9 passes with their icons, puts the ids in
   the game, sets the name, description and server size, and publishes it.
   The game stays private.
5. **You still do:** the content rating questionnaire (below), the store
   icon and thumbnail, and the release. Delete the API key when it's done.

**Content rating answers** (Creator Dashboard > Publish settings > Content
rating). It should come out **Mild**:

| Question | Answer |
| --- | --- |
| Violence | Yes: unrealistic, repeated (cartoon monsters puff into snow; players freeze in ice and are thawed) |
| Fear | Yes: mild, repeated (dark snowy nights, glowing-eyed monsters, a growling yeti, no jump scares) |
| Blood, crude humour, romance, alcohol, drugs, tobacco, strong language, gambling, sensitive issues | None |
| Social hangout, free-form creation, paid random items, paid item trading | No |

**Then soft launch:** set it to Friends, play a whole run with 3 to 6 people
(`games/snowed-in/docs/playtest.md`), check the run is won around minute 52
and that snowflakes, the Expedition Pass and cabin decorations survive a
rejoin, then set it to **Public**. Players under 16 need the same extra steps
as Halloween Tycoon (see the root `docs/launch.md`).

Every later update: open the new place file, **File > Publish to Roblox As**,
pick Snowed In and its place, **Overwrite**.

## Where things are

- `games/snowed-in/README.md`: overview, controls, folder layout, checks.
- `games/snowed-in/docs/design.md`: why the numbers are what they are.
- `games/snowed-in/docs/launch.md`: publishing by hand, the sound table, the
  pass table.
- `games/snowed-in/docs/playtest.md`, `marketing.md`, `rights-register.md`.
- `games/snowed-in/src/shared/Config/`: every number and list (balance,
  roles, enemies, weapons, structures, recipes, cosmetics, decor, Expedition
  Pass, catalog, sounds, map).
- `games/snowed-in/tools/simulate_run.luau` prints a run's pacing night by
  night.
