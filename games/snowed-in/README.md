# Snowed In: Survive 10 Nights

A co-op survival game for Roblox, for 1 to 8 players. A blizzard has buried
the mountain town of Pinehollow. Keep the Great Hearth burning for 10 nights,
fix the radio, and catch the rescue train.

It lives in this repo next to Halloween Tycoon but is its own Rojo project:
its own `default.project.json`, code, tests, sounds and CI workflow
(`.github/workflows/game-snowed-in.yml`). Nothing here touches the tycoon.

## How a run goes

- **Day** (2.5 minutes, 3.5 on the first): chop pines, dig coal, stone and
  scrap, catch fish and pick frostberries. Drop what you carry at the
  stockpile, feed the hearth, upgrade it, build defences, craft weapons and
  team upgrades at the workbench, and cook at the pot.
- **Dusk** (20 s): the horn sounds and the sky turns.
- **Night** (2 minutes): waves of cartoon snow monsters come for the hearth.
  Each night has a theme (Frostling Crowd, Hound Pack, Brute Siege, Wisp
  Swarm, Whiteout) that is forecast the morning before with a tip on how to
  meet it. Away from heat everyone gets cold; at zero warmth you freeze in a
  block of ice until a friend thaws you or you wake up by the hearth.
- **Radio:** four radio parts are frozen at four landmarks, each freed its
  own way: saw the logs at the sawmill, melt the cave ice with a fire tool,
  light the lighthouse with wood, pry the depot crate with scrap. Carry them
  to the radio tower; once all four are fitted the radio calls the train. It
  comes at the dawn after night 10. Miss it and the nights carry on, harder
  each time, up to night 15. A team behind on the radio gets the missing
  parts marked and fewer guards on them.
- **Bosses:** the Old Yeti on night 5 and the Elder Yeti on night 10. They
  wind up their slams (a red ring shows where), are out of breath after one
  (double damage), and roar for help as they weaken.
- **Milestones** (first hearth upgrade, first night, first part...) get a
  banner, and the results screen shows them with what each player did and
  their next goal.
- A run lasts about 52 minutes (`lune run tools/simulate_run` prints it
  night by night from a model of the whole run). Win or lose, everyone earns
  snowflakes and Expedition Pass XP.

## Roles

| Role | Good at | Ability (Q) | Unlock |
| --- | --- | --- | --- |
| Scout | Fast, big pack, finds things | Scout Flare: shows monsters, parts and crates for 12 s | Free |
| Builder | Cheaper building, faster repairs, Blaze Towers | Quick Fix: repairs nearby structures by 40% | Free |
| Cook | Better meals, warms the team | Hot Cocoa: +30 warmth for everyone nearby | Free |
| Ranger | Hits harder, sees monster health | Ember Volley: next 6 hits do double damage | 600 snowflakes or pass |
| Medic | Thaws friends quickly | Heat Pack: thaws every frozen friend nearby | 600 snowflakes or pass |

## Between runs

Snowflakes buy outfits, roles and cabin decorations in the shop. Each player
gets one of the town's eight cabins for the session and decorates its roof,
wreath, lantern, yard, flag and glow; the choices are saved and come back
next time. The Expedition Pass has 13 tiers with a free reward on each, and
a premium row for the Expedition Pass: Premium game pass. Nothing sold for
Robux is random. The Ranger and Medic role passes are early access to roles
anyone can earn with 600 snowflakes; those roles help a team a little (about
5 to 7% on a team of four's hardest night, by the run model), and a team of
free roles can win without them. Everything else sold is to wear or to put on
a cabin.

## Controls

- **Computer:** WASD move, hold **E** to use things, click to swing or shoot,
  **Q** ability, **G** eat, **B** build (click to place, **R** to turn),
  hold **X** on your own build to take it down for half its cost back,
  **Esc** closes menus.
- **Phone and tablet:** on-screen buttons for the ability, eating and
  building; hold on things in town to use them.
- **Controller:** **Y** ability, **X** eat, **R1** place while building,
  **B** closes menus.
- **Settings** (the gear menu): music on or off, effects volume, and reduce
  motion (fewer particles, no camera shake). They are saved with the
  player's progress. The same window shows a diagnostics line (frame rate,
  ping, monsters, builds, server step time).

## Feature switches

The newer mechanics each have a switch in `src/shared/Config/Features.luau`,
all on: `NightThemes`, `BossPhases`, `LandmarkTrials`, `RadioCatchUp`,
`SoloAssist`, `ThawGrace`, `BuildShare` and `Milestones`. Turning one off
and rebuilding puts that part back the way it was before;
`docs/AUTONOMOUS_UPGRADE_REPORT.md` says what each changes.

## Layout

```
src/
  shared/          Code both sides use (ReplicatedStorage.Shared)
    Config/        Every number and list: Balance, Roles, Enemies, Weapons,
                   Structures, Recipes, Resources, Cosmetics, Decor,
                   Expedition, Catalog (game passes), Sounds, Map
    World/         Code-built models: the town, landmarks, buildings,
                   monsters, gear, wearables, cabin decorations
    Waves, EnemySim, Combat, Warmth, Stock, Grid, Cycle, Codec, Profile,
    Radio (the radio part rules), Assist (small-team help), Milestones,
    Funnel (analytics steps); Config/Features holds the switches
  server/          ServerScriptService.Server
    Services/      GameLoop, World, Gather, Build, Craft, Monster,
                   Objective, Ability, Team, Player, Cabin, Pass, Profile,
                   Data, Results
    Lib/           Net (remote checks), RateLimiter, SessionLock,
                   ReceiptLedger, Migrations, Heat, RunStats, Sim,
                   Analytics (Roblox funnels and events), Celebrate
  client/          StarterPlayerScripts.Client: HUD, guide, menus, build
                   mode, monster view, effects, sky, sounds, markers, pets,
                   settings, diagnostics
tests/             Lune specs (no Studio needed)
tools/             make_sounds.py (the sound and music generator),
                   RunModel.luau (a deterministic model of a whole run),
                   simulate_run.luau (prints it for 1 to 8 players),
                   make_manifest.luau (writes publish/manifest.json)
publish/           publish.ps1: uploads sounds, makes passes, wires ids,
                   builds and publishes with an Open Cloud key
assets/audio/      45 generated .ogg files to upload
assets/marketing/  Pass icons; the store icon and thumbnails go here
docs/              launch.md, design.md, marketing.md, playtest.md,
                   rights-register.md, AUTONOMOUS_UPGRADE_REPORT.md
```

The server owns everything that matters: resources, the hearth, building,
damage, warmth, freezing, rewards and purchases. Clients send requests
(`ReplicatedStorage.Remotes`), and every remote is type- and rate-checked in
`server/Lib/Net.luau`. Monsters are simulated on the server and sent to
clients ten times a second as one packed buffer (`shared/Codec.luau`);
clients draw them from pooled models.

## Working on it

Tools are pinned in `rokit.toml` (Rojo 7.7.1, StyLua 2.6.0 with Luau, Selene
0.31.0, Lune 0.11.1). From this folder:

```
rokit install
stylua src tests tools        # format
selene src                    # lint
lune run tests/run            # tests
lune run tools/simulate_run   # the run model: pacing, difficulty, roles, economy
rojo serve                    # live sync into Studio
rojo build default.project.json -o snowed-in.rbxl
python3 tools/make_sounds.py  # rebuild assets/audio (needs numpy and ffmpeg)
```

CI runs the same format, lint, test and build steps on every pull request
that touches this folder.

## Publishing

`docs/launch.md` walks through it: publish, upload the sounds, the content
rating answers, the nine game passes and their icons, and the soft launch.
With an Open Cloud key, `publish/publish.ps1` does the sounds, passes,
settings and publish in one run (`publish/README.md`).
