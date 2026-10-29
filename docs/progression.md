# Progression: the upgrade tree and its pacing

A full playthrough of the plot takes about 90 minutes of income, and along the
way every building makes the player pick one of two or three paths. Picking a
path locks the others on that building for good, like choosing a tower's
upgrade path in a tower defence game. The numbers live in
`src/shared/Config/Balance.luau`; the names players see live in the theme pack.

## The tree

Each of the six buildings works the same way:

1. **Build it.** Buildings unlock in order: stall, pumpkin patch, kitchen,
   haunted maze, fortune teller's moon, ghost train.
2. **Two shared upgrades.** Everyone buys these.
3. **Pick a path.** Two or three pads appear, each with the path's name, what
   it does, and a warning that picking it locks the others. Stepping on one
   buys tier 1 of that path, and the other pads disappear.
4. **Four tiers** along the chosen path, each bought from the same pad.

That makes 42 purchases on every route (6 buildings, 2 shared upgrades each,
4 path tiers each), and 3 × 2 × 2 × 2 × 2 × 3 = 144 different routes.

| Building | Path | Playstyle |
| --- | --- | --- |
| Creepy Treat Stall | Sweet Shop | The stall makes far more of its own goods. |
| | Ghoul Grub Bar | A snack vendor: every visitor buys something. |
| | Night Market | Everything sold on the plot, goods and vendor sales, sells for more. |
| Pumpkin Patch | Bumper Crop | Grows far more pumpkins for the kitchen and stall. |
| | Pick-Your-Own | Visitors pay to pick their own. |
| Witch's Kitchen | Enchanted Pies | Every cooked good is worth far more. |
| | Creepy Café | A café that sells to every visitor. |
| Haunted Maze | Endless Maze | Bigger: lets in and draws more visitors. |
| | Scream Maze | Scarier: every visitor pays more. |
| Fortune Teller | Moon Beacon | Draws bigger crowds to the whole plot. |
| | Fortune Teller | Every visitor pays more for a fortune. |
| Ghost Train | Midnight Express | Longer trains for bigger crowds. |
| | Terror Train | Scarier: every rider pays more. |
| | Ghost Parade | Parades pull in visitors for everything. |

The building names above are the Moonlight Festival theme's; the ids in
`Balance.luau` are theme-neutral (`stall_vendor_2`, `attraction_3_draw_4`).

The paths lean two ways. Production paths (Sweet Shop, Bumper Crop, Enchanted
Pies) grow the goods chain. Crowd paths (the vendors, the beacon, the parade)
earn from visitors, so they get stronger as the attractions draw more people.
Night Market sits between the two because its markup raises both.

## How a choice is stored and enforced

- An upgrade on a path names its `Building` and `Path` in `Balance.luau`.
- A player's chosen path is whichever path they own any upgrade on. Saving the
  owned upgrades saves the choice, so the save format didn't change and older
  saves load as they are.
- The server refuses a purchase on a locked path (`PathLocked` in
  `Progression.canPurchase`), whatever the client sends. The pads only reflect
  what the server allows.
- `Progression.validate` rejects a tree where paths don't start after the same
  upgrade, a path isn't one line of tiers, a tier requires an upgrade on
  another path, or a building has only one path.
- Helpers for other systems: `Progression.paths`, `chosenPaths`, `pathLocked`,
  `pathTier` and `pathComplete`.

## The pacing rule

The old rule was "no next upgrade is more than 120 seconds away". That rule
can't make a 90 minute game: with a 2 minute cap and 42 purchases, the whole
tree would be over in well under 90 minutes unless purchases were made tiny.

The new rule, in `tests/Pacing.luau` and checked by `tests/Earnings.spec.luau`,
plays every one of the 144 routes. Each simulated player earns passive income
only and always buys the cheapest upgrade open to them on their route. Every
route must then meet all of these:

| Rule | Limit | Shipped numbers |
| --- | --- | --- |
| Whole tree takes | 80 to 100 minutes | 86 to 97 minutes |
| Slowest route vs fastest | at most 1.2 times as long | 1.12 times |
| Wait for the next upgrade, first 10 minutes | at most 2 minutes | at most 1 min 53 s |
| Wait for the next upgrade, after that | at most 5 minutes | at most about 4 minutes |
| Income gain from each purchase | at least 5% | at least 10% |

Every path averages 89 to 92 minutes across the routes that take it, so no
choice is a trap and none is a shortcut. Real players take a little longer
than the simulation, since they also have to walk to each pad.

### Ghost Catcher and the Moonlight Parade

Ghost Catcher (`Config/Activity.luau`) is the repeatable activity between
purchases: a 25 second round of wisps to catch, then a 72 second rest. Each
wisp pays 0.4 seconds of the plot's income and a perfect round 2 seconds more,
so a player who plays every round from start to finish earns at most about
6.9% more than passive income. In the first few minutes each wisp pays at
least 2 coins, which is worth more than income then and makes the first
rounds a real boost.

The Moonlight Parade (`Config/Parade.luau`) circles the wheel in the
courtyard for a minute every 10 minutes, the first one 2.5 minutes after the
server starts. Each of the first 6 lanterns a player catches in a parade pays
0.3 seconds of their income (at least 2 coins), and if the server catches
60% of the lanterns, everyone who caught one gets 1 second more (at least 5
coins). Catching everything in every parade adds at most about 0.5% to
income. The parade is there to bring the server together, not to pay; what
it really gives is decorations and a colour for the player's festival.

Together, a player who plays every Ghost Catcher round and every parade
earns at most about 7.4% more than passive income, which takes the fastest
route from 86 minutes to just over 80, the floor of the pacing rule
(`tests/Parade.spec.luau` holds it there). A player who skips both is not
held back.

## Retuning

`tools/tune_balance.luau` is a scratch tuner that isn't shipped. It picks costs
and effect sizes so the reference route follows a wait schedule, then adjusts
each path until every route takes about as long, and prints a route report and
Balance-ready `path(...)` blocks.

```sh
lune run tools/tune_balance.luau            # 25% target gain, 90 minutes, 12 rounds
lune run tools/tune_balance.luau 0.25 120   # aim for 2 hours instead
```

It takes about a minute. Paste its blocks into `Balance.luau`, then run
`lune run tests/run` to check them against the pacing rule. To change the
target length, change `PACING.MinMinutes` and `PACING.MaxMinutes` too.

To add a path: add a `path(...)` block in `Balance.luau`, name it under
`Paths` in the theme pack, and give it a spot under the building's `Paths` in
`Config/Layout.luau`. The tests check each of these.
