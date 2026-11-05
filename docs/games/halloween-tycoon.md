# Halloween Tycoon: Your Dream Festival

*Build the spookiest festival on Roblox.*

| | |
| --- | --- |
| **Genre** | Tycoon (Simulation) |
| **Players** | 6 per server (one plot each) |
| **Session** | About 90 minutes to finish a full upgrade route |
| **For** | Ages 9 to 12, aimed at Roblox's **Mild** label (spooky, never gory) |
| **Status** | Live on Roblox since 2026-10-30. A few setup steps are still open (see below) |
| **Code** | Repository root (`src/`, `tests/`, `docs/`). The repo, folders and code still use the old working title "Moonlight Festival" |
| **Place file** | `/mnt/project-files/release/halloween-tycoon.rbxl` (has all 14 pass ids) |
| **Experience** | Universe id `10773736001` ([Creator Hub](https://create.roblox.com/dashboard/creations/experiences/10773736001/overview)) |
| **Publishing thread** | "Publish the game to Roblox" |

## What it is

A classic Roblox tycoon with a haunted night festival theme. You claim an empty
plot, step on glowing pads to build things, earn coins every second and spend
them on the next pad. Everything is built from parts in code: a treat stall
with glowing potions, a misty pumpkin patch with a scarecrow, a witch's
cottage kitchen, a hedge maze with a hooded reaper statue, a giant grinning
pumpkin with bats circling it, and a ghost train looping through a haunted
house. The whole map sits under a huge moon in thick coloured fog.

## How a session plays

1. **Arrive.** You spawn on the plaza facing the Moonlight Wheel. Gold beacons
   mark the free plots.
2. **Claim a plot** by walking into its gate. Your name goes on it and you
   respawn there from then on. Target: under 30 seconds.
3. **Build.** Step on the free **Creepy Treat Stall** pad. The first paid
   upgrade is affordable within a minute (a test checks this). Pads you can
   afford glow; the rest turn red and tell you how much more you need.
4. **Grow the production chain.** The Haunted Pumpkin Patch grows pumpkins,
   the Witch's Pie Kitchen cooks them into pies, and the stall sells
   everything that reaches it. Cooked goods are worth more.
5. **Add attractions.** The Lost Lantern Maze (a walkthrough), the Grinning
   Giant Pumpkin (a showpiece that draws a crowd) and the Phantom Ghost Train
   (a ride). Visitors in Halloween costumes walk in, queue, sit and cheer.
6. **Pick a path.** After two shared upgrades, each building forks into 2 or 3
   paths of 4 tiers, like tower paths in a tower defence game. Picking one
   locks the others for good. Stepping on a path's first pad shows a preview
   and a see-through model first; step again within 12 seconds to choose it.
7. **Finish the route.** 42 purchases per route, 144 possible routes, every
   route takes 80 to 100 minutes (the tests play all 144).

A small card in the corner always says what to do next, and for the first six
purchases a beam leads you to the next pad.

### The 15 paths

| Building | Paths |
| --- | --- |
| Creepy Treat Stall | Sweet Shop, Ghoul Grub Bar, Night Market |
| Haunted Pumpkin Patch | Bumper Crop, Pick-Your-Own |
| Witch's Pie Kitchen | Enchanted Pies, Creepy Café |
| Lost Lantern Maze | Endless Maze, Scream Maze |
| Grinning Giant Pumpkin | Moon Beacon, Fortune Teller |
| Phantom Ghost Train | Midnight Express, Terror Train, Ghost Parade |

Every tier adds something you can see in the building's yard.

## Things to do between purchases

- **Ghost Catcher:** a booth on every plot. Step on its pad and catch 12 wisps
  in 25 seconds by running through them. Pays a slice of your income, every
  72 seconds. Your best round is saved.
- **Moonlight Parade:** every 10 minutes (the first after 2.5 minutes) floats
  and marching ghosts circle the Wheel letting go of lanterns. Everyone on the
  server catches them to fill one shared meter, with confetti and a small
  bonus when it fills.
- **Your own festival:** name your festival from three word lists, pick a
  colour scheme and choose decorations for six spots. More unlock as you
  build, catch wisps and join parades. A trophy shelf shows finished paths.
- **Bonk Arena (PvP):** an opt-in stage past the bonfire. Walk on to fight,
  walk off to be safe. Cartoon bonks with special moves; knocked-out players
  tumble out dizzy. Nobody dies and no coins change hands. KOs are saved and
  shown on the leaderboard.
- **Woods trail:** a lantern-lit path to a reaper statue whose head turns to
  watch you and whispers once. Eerie, never a jump scare.

## Earned items (free)

Ten things to wear, hold or have follow you, unlocked by milestones every
route reaches, spread over the 90 minutes: Trick-or-Treat Lantern, Witch's
Cape, Pumpkin Head, Big Wooden Mallet, Werewolf Claws, Witch's Broom, Ember
Trail, Pumpkling pet, Phantom Aura, and the Crescent Moon Blade for the last
purchase. The Haunted Wardrobe shows all of them with a turning preview.

## Money (Robux)

14 game passes, all direct purchases with their contents stated up front. No
loot boxes, rerolls, timers or repeat prompts. Nothing paid changes coins or
income.

| Group | Passes | Robux |
| --- | --- | --- |
| Deluxe looks | Moonstone Mallet 99, Neon Bat Wings 129, Ghostfire Crown 99, Toxic Ghostfire Aura 99, Spooky Rainbow Trail 79 | 79 to 129 |
| Brainrot Buddies (original pets) | Pipistrello Pizzetta, Fantasmino Gelatino, Candelino Wobblino, Zucchino Zombino | 149 each |
| Legendary weapons | Storm-Stone Hammer, Ghostlight Blade, Reaper's Scythe, Drowned Trident, Foxfire Fan | 499 each |

The Legendary weapons are the one exception to "looks only", by mencho's
choice: in the Bonk Arena they are about 10% better in one stat than the best
earned weapon. The edge is arena-only, capped by a test, and lives in
`src/shared/Config/Weapons.luau`.

## Safety and fairness

- The server owns every coin change, every hit and every purchase. Pads only
  say which upgrade a player wants.
- Saves are session-locked with a versioned schema, autosave every 60 s and a
  save on leave and shutdown. A receipt ledger stops a purchase granting
  twice.
- No child personal data. Festival names come from word lists; nobody types
  anything other players see.

## Status

- Published on Roblox on 2026-10-30. The project notes say its audience was
  set to ages 16+ and trusted friends; check the Creator Hub to confirm.
- All 14 passes exist and are on sale; their ids are in
  `src/shared/Config/Catalog.luau` (PR #13, merged).
- All 32 sounds are uploaded to mencho's Roblox account and wired in.
- 162 tests pass in CI (StyLua, Selene, Lune tests, Rojo build).
- Store art is in `assets/marketing/` (thumbnail-vs and the single-avatar icon
  were the picks). Store text is in `docs/store-page.md`.
- A maxed-out showcase build for screenshots is at
  `/mnt/project-files/release/halloween-tycoon-showcase.rbxl` (Studio only).

## What's still open

The last update in the "Publish the game to Roblox" thread (2026-10-30) was
waiting on these. Skip any you've already done.

1. **Publish the build with the pass ids.** Open
   `release/halloween-tycoon.rbxl` in Studio, then **File > Publish to Roblox
   As**, pick Halloween Tycoon, its place, and **Overwrite**. Or add
   **universe-places: Write** to an API key and ask in that thread.
2. **Reply `yes` in the publishing thread** if you want your PC to set the
   name, description, 6 players per server, devices, icon, thumbnails and
   pictures for the 3 passes you made by hand. If you deleted the old API
   key, make a new one with `game-pass` (read, write), `universe` (write),
   `universe.place` (write), `universe-places` (write) and `legacy-universe`
   (manage), paste it in that thread and say "go ahead".
3. **Content rating questionnaire** (Creator Dashboard > Publish settings >
   Content rating): violence yes (unrealistic, repeated, the opt-in arena),
   fear yes (mild), blood none, everything else none or no, paid random
   items no, trading no. The full table is in `docs/launch.md`.
4. **Players under 16** (later): age check, 2-Step Verification, the 1,000
   Robux refundable fee or two months of Plus/Premium, then 250 highly
   engaged age-checked players in 60 days and a safety review. The
   **Audience Reach** page shows progress.
5. **Play-test** with `docs/playtest.md`: claim under 30 s, first satisfying
   action under 60 s, a 6-player server, saves after rejoining, and phone
   frame rate.

## Where things are

- `README.md`: everything the game does, in detail.
- `docs/launch.md`: publishing step by step, the questionnaire, the pass table.
- `docs/progression.md`: the branching paths and the 90 minute pacing rule.
- `docs/arena.md`: the Bonk Arena and weapon balance.
- `docs/playtest.md`: the Studio play-test checklist.
- `docs/rights-register.md`: where every asset comes from.
- `src/shared/Config/`: every number (costs, layout, cosmetics, catalog,
  weapons, Ghost Catcher, festival, parade).
- `src/shared/Themes/MoonlightFestival/`: names, colours, sounds and every
  model.
