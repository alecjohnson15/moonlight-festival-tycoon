# Moonlight Festival Tycoon

An original Roblox tycoon: players turn an empty plot into a festival, earn coins from what they build and reinvest them. This repository holds the theme-neutral core systems. The festival theme is a placeholder until trend research in August 2027 confirms or replaces it.

## What's here

- **Arrival:** players spawn on the plaza facing the arrival courtyard between the middle two plots, where the Moonlight Wheel, a big ferris wheel lit in pale moonlight gold, turns slowly. Glowing arrows either side of the spawn point to the nearest gates.
- **Plots:** players spawn on the plaza and claim a plot by walking into its gate. The gate then turns see-through and shows the owner's name, and they respawn on their plot from then on. With no `Workspace.Plots` folder in the place, the server generates a row of plots, gates and a spawn plaza, so the game runs from an empty place file. A place that brings its own plots can give each one a `Gate` part.
- **Buy buttons:** everything is bought by stepping on round pads on the plot floor, each showing its name, price and what it adds per second. A pad appears, fading in, once its requirement is owned. Stepping on it builds the upgrade, which rises out of the ground part by part with a burst of sparks while "+N / sec" rises off it, and the pad fades away. On your own screen, pads you can afford glow and pulse, and the rest turn red. Stepping on one you can't afford yet says how many more coins it needs. The first pad of each path only previews the path on the first step (what it does, what it adds, what it locks, and a see-through model of what it builds); stepping off and on again within 12 seconds picks it.
- **Guide:** a line at the bottom of the screen always says what to do next: claim a gate, step on a named pad, or save up for the next one with a coin bar. For the first six purchases, and whenever you could buy something but haven't for 40 seconds, a beam runs from you to that goal with an arrow over it. Free gates shine with a tall gold beacon until you have a plot. Saving up for something more than 20 seconds away, it suggests Ghost Catcher.
- **Ghost Catcher:** the repeatable thing to do between purchases. Every claimed plot has a booth at the back of its walkway; step on its pad and, for 25 seconds, twelve wisps pop up one after another along the walkway, each waiting six seconds to be caught by running through it. Each pays a bit of your income (at least 2 coins), and catching all twelve pays a bonus. The booth's board counts down the 72 seconds to the next round, and your best round is saved. The server places the wisps and decides every catch. Played nonstop it adds at most about 7% to income, so the 90 minute pacing holds (see [docs/progression.md](docs/progression.md)).
- **Your own festival:** every plot gets a name ("The Grinning Lantern Carnival", picked from three word lists and changeable), a name sign over its gate, a board by the walkway to decorate from, and a trophy shelf with a cup for each finished path, your best Ghost Catcher round, your arena KOs and your parades. Press **Festival** on the left, or the board's **Decorate** prompt, to rename it, pick a colour scheme for the stall, the booth and the decorations, and choose what stands in each of six spots round the plot (hay bales, a graveyard corner, pumpkins, a witch's cauldron, a lantern arch, a moon fountain, a bat topiary, a ghost statue, a parade float or a skeleton drummer). More pieces and colours unlock by building things every route gets, by Ghost Catcher scores and by joining parades, and a note says when one does. Choices are saved.
- **The Moonlight Parade:** every 10 minutes (the first 2.5 minutes after a server starts) three floats and a band of marching ghosts circle the Moonlight Wheel for a minute, letting go of glowing lanterns. Everyone on the server can catch them by running through them, and every catch fills one shared meter. The goal line counts down to it and leads you there, a sign in the courtyard says when the next one starts, and when the meter fills there's confetti, a cheer and a small bonus for everyone who caught one. Parades unlock festival decorations and a colour, and pay too little to change the pacing. Next to the parade's sign, a board lists the server's best Ghost Catchers.
- **First minute:** claim a gate, step on the free Creepy Treat Stall pad, and the first paid upgrade is affordable within a minute. A test enforces that last part.
- **Production chain:** the pumpkin patch grows goods, the kitchen cooks as many as it has room for, and the stall sells everything that reaches it, plus what it makes itself. Cooked goods sell for more, so a full kitchen is the next thing to upgrade, and its label says "(full)" when goods are going past it.
- **Visitors and attractions:** every attraction draws visitors, and there are three types. A walkthrough charges each visitor up to its capacity, a ride runs in rounds and pays per seat filled, and a showpiece is free to visit and earns by drawing a crowd for the others.
- **Economy:** the server pays income on a tick into the Coins leaderstat and owns every coin change. A button touch only names the upgrade the player wants, and only the plot's owner can buy from it. Button gains are worked out with the same code the server pays from.
- **Plot activity:** pumpkins, pies and toffee apples travel along the chain, and visitors in Halloween costume (sheet ghosts, pumpkin kids, skeletons, witches and mummies) hop or float to the stall and the attractions. Rides on your own plot show a countdown and each round's takings. All of this is drawn on each client and changes nothing.
- **The look:** a haunted night under a huge moon, in thick coloured fog. Every upgrade is a model built from parts in code: a treat stall with a shelf of glowing potions, a misty pumpkin patch with a scarecrow, a witch's cottage with green windows and a smoking chimney, a bubbling cauldron, a hedge maze with a hooded reaper statue, a giant grinning pumpkin with bats circling it, and a ghost train looping through a haunted house. Each build is washed in red, green or purple light. Every upgrade adds something you can see: the first ones each have their own model (a potion shelf over the stall, a toffee apple cauldron, a grub bar or night market banners beside it, scarecrow guards, glowing compost or a pick-your-own stand by the patch, rolling pins circling the cauldron), and the rest put up pennants in their path's colour at the building's corners, one per tier, or string lanterns across it. Plots have fences, lantern posts lit in the plot's own colour, string lights, an arch over the gate, gravestones, skeletons and cobwebs. Around them are dead woods, a graveyard with a crypt, a bonfire, a pond with floating lanterns, a windmill and drifting mist. Ghosts and the pumpkin float, the train runs round its track, bats circle and lights flicker, all moved on each client.
- **HUD and sound:** a cash counter with a moon coin that counts up and pops "+N" as you earn (the Coins leaderstat stays), income and visitors per second, and a music button. The theme has slots for two songs that play in turn, an eerie ambience and sounds for claiming, buying, a pad you can't afford yet, building and ride payouts. The songs are original upbeat Halloween instrumentals with a pop shape: "Moonlit Mischief" (a theremin hook in A minor, 124 bpm) and "Haunted Arcade" (an arcade lead and harpsichord in D minor, 116 bpm). The original audio is in `assets/audio` and plays once it is uploaded (see Getting started).
- **PvP arena:** a raised round stage past the bonfire, through the gateway at the back of the plaza. Fighting is opt-in: walking onto the stage makes you a fighter, walking off makes you safe, and nobody outside can hit or be hit. Anyone who walks in empty-handed is lent a Pumpkin Bonker, and a weapon from the cosmetics (a Tool with a `Weapon` attribute) is used instead when you have one. Click to swing, and press **E** (gamepad X, or the on-screen button) for your weapon's special move: a ground slam, a charge, a whirl or a flying wave, each drawn with its own effects. The server decides every hit. Knocking someone out throws them out of the ring dizzy (nobody dies, and no coins change hands) and scores a KO, saved and shown on the leaderboard. Weapons and their balance are in `Config/Weapons.luau`, and the design is in [docs/arena.md](docs/arena.md).
- **Rating:** spooky rather than gory, aimed at Roblox's **Mild** maturity label for players aged 9 to 12: dark, foggy lighting, ghosts, skeletons, gravestones and a reaper statue (mild fear), and cartoon bonks in the opt-in arena (repeated mild violence, with knockback and dizzy stars but no blood or gore). Answer the Maturity & Compliance questionnaire to match before publishing.
- **Saves:** session-locked DataStore saves with a versioned schema, autosave every 60 seconds, and a final save on leave and on shutdown.
- **Flex items:** ten things to wear, hold or have follow you, spread over the whole 90 minute run so other players can see how far you've got. They come from milestones every route reaches: the Trick-or-Treat Lantern with the first stall, a Witch's Cape and a Pumpkin Head for picking the stall's and the patch's paths, the Big Wooden Mallet with the maze, Werewolf Claws with the giant pumpkin, a Witch's Broom for finishing the stall's path, an Ember Trail with the ghost train, a Pumpkling pet and a Phantom Aura for finishing the patch's and the maze's paths and, for the last purchase of the run, the Crescent Moon Blade. A new item goes straight on if its slot is empty, a note pops up, and everyone on the server sees it. There are six slots (head, back, held, pet, aura, trail), one item each, and the choice is saved.
- **Wardrobe:** a button on the left (shown once you've earned your first item) opens a panel with a turning preview of every item, in four tabs: Earned, Deluxe, Brainrot Buddies and Legendary. Earned items say what to build to unlock them; paid ones show their price and exactly what they are.
- **Held items and weapons:** the held item is a Roblox Tool in your hotbar. Weapons swing with the built-in Slash or Lunge tool animation when clicked, and every player hears a thump or whoosh and sees a dust puff where it lands. Each weapon carries a `Weapon` attribute that the PvP arena reads its stats from (`Config/Weapons.luau`).
- **Purchases:** direct game-pass purchases with the contents stated up front, and no loot boxes, rerolls, timers or repeat prompts. Deluxe looks (a Moonstone Mallet that swings exactly like the wooden one, Neon Bat Wings, a Ghostfire Crown, an aura and a trail) and Brainrot Buddies (four original nonsense pets: Pipistrello Pizzetta, Fantasmino Gelatino, Candelino Wobblino and Zucchino Zombino) are looks only. The five Legendary weapons (Storm-Stone Hammer, Ghostlight Blade, Reaper's Scythe, Drowned Trident, Foxfire Fan) are a little stronger than the best earned weapon in the PvP arena only; that was the project owner's call, and their edge lives in `Config/Weapons.luau`. Nothing paid changes coins or income. The server opens prompts, a developer product is confirmed only after its grant is saved, and a ledger in the save stops a retried receipt granting twice. In Studio, every paid item counts as owned so it can be tried on; live servers never do this.
- **Theme packs:** every player-facing name, colour, sound and model lives in a theme pack under `src/shared/Themes/`. Swapping themes is a new pack folder plus one line in `Config/Theme.luau`.

```
src/
  shared/                 ReplicatedStorage.Shared
    Config/
      Balance.luau        upgrade costs, income, goods and visitors
      Layout.luau         plot size, gate, buy buttons, build slots, the booth
      Cosmetics.luau      everything players can wear, and how it unlocks
      Catalog.luau        Robux cosmetics (ids are 0 until set up)
      Theme.luau          picks the active theme pack
      Arena.luau          the arena's size, place and rules of a fight
      Weapons.luau        every arena weapon's stats and special move
      Activity.luau       Ghost Catcher's rounds, wisps and rewards
      Festival.luau       festival colours and decorations, and what unlocks them
      Parade.luau         the Moonlight Parade's timing, lanterns and rewards
    Themes/
      MoonlightFestival/
        init.luau         names, colours, the night's look, sounds
        Props.luau        a model for each upgrade
        Scenery.luau      plot dressing and the land around the plots
        Crowd.luau        visitors in costume and the goods on the move
        Wearables.luau    a model or effect for each cosmetic
        Pieces.luau       pumpkins, lanterns, ghosts, fences and the rest
        Arena.luau        the arena's dressing, the bonker, special moves' looks
        Courtyard.luau    the arrival courtyard and the Moonlight Wheel
        Activity.luau     Ghost Catcher's booth and wisps
        Festival.luau     festival decorations, name sign, board and trophy shelf
        Parade.luau       the parade's floats, marchers and lanterns
    Kit.luau              helpers for building models from parts
    Progression.luau      what can be bought, when (pure)
    Earnings.luau         production chain, visitors, attractions (pure)
    Wardrobe.luau         who owns which cosmetic, what goes where (pure)
    Combat.luau           who an arena hit reaches, and how it throws
    Activity.luau         Ghost Catcher's wisps, catches and pay (pure)
    Festival.luau         festival names, unlocks and choices (pure)
    Parade.luau           when parades run, lanterns, catches and pay (pure)
    Format.luau           number formatting for labels
  server/                 ServerScriptService.Server
    init.server.luau      starts services in order
    Services/             DataService, EconomyService, PlotService,
                          ArenaService, WorldService, ProductionService,
                          AttractionService, UpgradeService,
                          ActivityService, FestivalService,
                          ParadeService, PurchaseService,
                          CosmeticService
    Lib/                  Migrations, SessionLock, ReceiptLedger,
                          RateLimiter (pure)
  client/                 StarterPlayerScripts.Client
    Hud.luau              cash counter, income, visitors, music button
    Guide.luau            the next goal, guide beam, notes, path previews
    Activity.luau         Ghost Catcher's wisps, timer and results
    FestivalBoard.luau    the festival panel: name, colours, decorations
    Parade.luau           the parade, its lanterns, the courtyard sign
    PlotActivity.luau     goods and visitors moving on every plot
    Motion.luau           floating, spinning, the ghost train, flicker
    BuildEffects.luau     the build-up when something is bought
    Sounds.luau           music, ambience and sound effects
    Wardrobe.luau         the wardrobe panel and unlock notes
    Pets.luau             every player's pet, following them
    Swing.luau            the thump and dust when a weapon lands
    Arena.luau            the arena panel, special move button, knockback
    ArenaEffects.luau     hit sparks, knockouts and special move effects
tests/                    Lune tests, including the theme's models
tools/make_sounds.py      makes the original audio in assets/audio
tools/make_arena_sounds.py  makes the arena's sounds in assets/audio
tools/tune_balance.luau   picks upgrade costs to hit the pacing target
docs/progression.md       the upgrade paths and the 90 minute pacing rule
docs/arena.md             the arena's rules, weapons and the paid edge
docs/rights-register.md   every external asset and dependency
```

The remotes are declared in `default.project.json`: `RequestPurchase` (open a purchase prompt), `EquipCosmetic` (wear or take off an item), `CosmeticSwung` (the server telling clients a weapon swung), `ArenaAction` (a fighter's special move), `ArenaEffect` (the server telling clients what to draw in the arena), `Activity` (Ghost Catcher rounds), `Festival` (renaming and decorating a festival, and the server opening the panel), `Parade` (the server telling clients about the parade, and a client that joins mid-parade asking for it) and `Notice` (notes for the guide). A client only names what it wants; the server checks it. Gates and buy buttons use touches, and arena swings use the weapon Tool's `Activated`, which the server sees directly.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder to get the pinned Rojo, StyLua, Selene and Lune.
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open a new Baseplate place in Studio (or delete the baseplate) and connect from the Rojo plugin.
4. In Game Settings, set **Max Players** to 6 to match `Layout.PlotCount`, and turn on **Security > Enable Studio Access to API Services** if you want saves to work in Studio. Without it, progress lives in memory for that session and the output says so.
5. Press Play, walk off the plaza into a plot's gate to claim it, then step on the glowing **Creepy Treat Stall** pad.
6. Optional, for sound: upload the seventeen files in `assets/audio` (Studio: **Window > Asset Manager**, then **Bulk Import**). Right-click each upload, choose **Copy Asset ID**, and paste it as `"rbxassetid://<id>"` into `Sounds` in `src/shared/Themes/MoonlightFestival/init.luau`, or for the four `arena_*` files, into `Sounds` in `Themes/MoonlightFestival/Arena.luau`. Until then there is no music (the music button stays hidden), and claiming, buying, a pad you can't afford yet and weapon swings play plain sounds that come with Roblox.
7. To try the arena, walk through the gateway behind the spawn, past the bonfire and up the ramp. With **Test > Clients and Servers** set to 2 players you can fight yourself.

## Checks

```sh
stylua --check src tests tools   # formatting
selene src                       # lint
lune run tests/run               # tests, including the theme's models
rojo build default.project.json -o build.rbxl
```

StyLua must be built with its `luau` feature: `cargo install stylua --features luau` (the release binaries Rokit downloads are built with it). Without it StyLua skips every `.luau` file and the check passes having read nothing, which is what CI did until October 2026. CI now checks that StyLua passes a tidy Luau file and fails an untidy one before trusting the result.

CI runs the same four on every pull request. What they cover, and what they don't:

- **Formatting and lint** read every Luau file under `src`, `tests` and `tools` (lint: `src` only).
- **Tests** run the pure modules (`Progression`, `Earnings`, `Wardrobe`, `Combat`, `Activity`, `Festival`, `Parade`, the save schema, the receipt ledger and rate limiter) and the config, including every route through the upgrade tree against the pacing rule. They also build the theme's models and scenery with Lune's Roblox library, which catches bad property names and types, and check that models fit their slots and stay clear of pads, gates and walkways.
- **The build** checks that Rojo can assemble the place.
- **Not covered:** the server services and client scripts never run in CI, because they need a live Roblox engine (DataStores, MarketplaceService, terrain, touches, physics, the camera and UI). Nothing measures fun, readability, frame rate, memory or mobile layout. Those are checked by playing in Studio and on real devices; see [docs/playtest.md](docs/playtest.md).

A fully built plot, on its heaviest paths, with its Ghost Catcher booth and its heaviest festival decorations, is about 1,450 parts and 51 lights, and the land around the plots about 3,800 parts; a test keeps a plot under 1,500 parts and 60 lights. `Lighting.Technology` is set to Future in `default.project.json`, as scripts can't change it.

## Common changes

- **Add an upgrade:** add it to `Config/Balance.luau` (the comment at the top explains each kind and its fields), give it a name and colour in the theme pack, and give it a buy button in `Config/Layout.luau`, plus a slot for a new building. Give it a model in the theme's `Props.luau`, built inside its slot (an upgrade to a building is added inside that building's slot or its yard); an upgrade to a building with no model of its own gets a pennant or lanterns automatically. The tests fail until all of these agree, and also if any route through the upgrade paths breaks the pacing rule in `docs/progression.md`.
- **Add a good:** add it to `Items` in `Config/Balance.luau` with its sale value, and to `Items` in the theme pack with a plural name and colour.
- **Swap the theme:** copy the `Themes/MoonlightFestival` folder, change its names, colours, look, sounds, models and scenery, and point `Config/Theme.luau` at the new folder. An artist's model can replace a built one: put it in `ReplicatedStorage.Assets` and name it in the upgrade's `Model` field. An upgrade with neither stays a greybox block.
- **Change the sounds:** edit `tools/make_sounds.py` and run it (Python 3 with numpy, and ffmpeg), then upload the new files and update the ids.
- **Change the save shape:** bump `Migrations.CURRENT_VERSION` and append a step. Never edit a step that has shipped.
- **Add a cosmetic:** add it to `Config/Cosmetics.luau` with its slot, line and unlock (or `Premium = true` and a matching `Config/Catalog.luau` entry), name it in the theme pack's `Cosmetics`, and give it a look in `Wearables.luau`. The tests check each item fits the body, can't touch or collide, that every paid look of a weapon fights like an earned one, and that every route through the upgrade tree earns every free item in the order they're listed. Unlock free items from things every route buys, or from `Building` with no `Path` (any path of that building), since an item that needs one path can't be earned on the others.
- **Tune the arena:** fight rules (health, shield time, knockout time, knockback lift) are in `Config/Arena.luau`; weapon styles, tiers, special moves and the premium edge are in `Config/Weapons.luau`, and the tests fail if a paid weapon gets more than a slight edge. To add a weapon, add it to `Roster` there and give its special a look in the theme's `Arena.luau`.
- **Sell a cosmetic:** create a game pass on the Roblox website for each item in `Config/Catalog.luau` (`SuggestedRobux` is a starting price), and paste its id into `PassId` only after a price and value review. The brief rules out paid random rewards, rerolls, fake scarcity, misleading discounts, repeat prompts after a no, and anything that speeds up progression.

## Not built yet

A full tutorial (the guide's goal line and beam cover the first steps), emotes and plot decorations for the shop, analytics for a funnel and retention, and uploaded art: every model is built from parts in code until an artist's models replace them. Arena weapons swing with Roblox's built-in tool slash animation until custom animations are uploaded. Visitors are a rate, not individual characters: the costumed walkers on each plot are decoration, and nothing about a visitor is simulated or saved. Ride rounds restart when a player rejoins, and nothing is earned while offline.
