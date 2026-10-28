# Moonlight Festival Tycoon

An original Roblox tycoon: players turn an empty plot into a festival, earn coins from what they build and reinvest them. This repository holds the theme-neutral core systems. The festival theme is a placeholder until trend research in August 2027 confirms or replaces it.

## What's here

- **Plots:** players spawn on the plaza and claim a plot by walking into its gate. The gate then turns see-through and shows the owner's name, and they respawn on their plot from then on. With no `Workspace.Plots` folder in the place, the server generates a row of plots, gates and a spawn plaza, so the game runs from an empty place file. A place that brings its own plots can give each one a `Gate` part.
- **Buy buttons:** everything is bought by stepping on round pads on the plot floor, each showing its name, price and what it adds per second. A pad appears, fading in, once its requirement is owned. Stepping on it builds the upgrade, which rises out of the ground part by part with a burst of sparks, and the pad fades away. On your own screen, pads you can afford glow and pulse, and the rest turn red.
- **First minute:** claim a gate, step on the free Creepy Treat Stall pad, and the first paid upgrade is affordable within a minute. A test enforces that last part.
- **Production chain:** the pumpkin patch grows goods, the kitchen cooks as many as it has room for, and the stall sells everything that reaches it, plus what it makes itself. Cooked goods sell for more, so a full kitchen is the next thing to upgrade, and its label says "(full)" when goods are going past it.
- **Visitors and attractions:** every attraction draws visitors, and there are three types. A walkthrough charges each visitor up to its capacity, a ride runs in rounds and pays per seat filled, and a showpiece is free to visit and earns by drawing a crowd for the others.
- **Economy:** the server pays income on a tick into the Coins leaderstat and owns every coin change. A button touch only names the upgrade the player wants, and only the plot's owner can buy from it. Button gains are worked out with the same code the server pays from.
- **Plot activity:** pumpkins, pies and toffee apples travel along the chain, and visitors in Halloween costume (sheet ghosts, pumpkin kids, skeletons, witches and mummies) hop or float to the stall and the attractions. Rides on your own plot show a countdown and each round's takings. All of this is drawn on each client and changes nothing.
- **The look:** a haunted night under a huge moon, in thick coloured fog. Every upgrade is a model built from parts in code: a treat stall with a shelf of glowing potions, a misty pumpkin patch with a scarecrow, a witch's cottage with green windows and a smoking chimney, a bubbling cauldron, a hedge maze with a hooded reaper statue, a giant grinning pumpkin with bats circling it, and a ghost train looping through a haunted house. Each build is washed in red, green or purple light. Plots have fences, lantern posts lit in the plot's own colour, string lights, an arch over the gate, gravestones, skeletons and cobwebs. Around them are dead woods, a graveyard with a crypt, a bonfire, a pond with floating lanterns, a windmill and drifting mist. Ghosts and the pumpkin float, the train runs round its track, bats circle and lights flicker, all moved on each client.
- **HUD and sound:** a cash counter with a moon coin that counts up and pops "+N" as you earn (the Coins leaderstat stays), income and visitors per second, and a music button. The theme has slots for two songs that play in turn, an eerie ambience and sounds for claiming, buying, building and ride payouts. The songs are original upbeat Halloween instrumentals with a pop shape: "Moonlit Mischief" (a theremin hook in A minor, 124 bpm) and "Haunted Arcade" (an arcade lead and harpsichord in D minor, 116 bpm). The original audio is in `assets/audio` and plays once it is uploaded (see Getting started).
- **Rating:** spooky rather than gory, aimed at Roblox's **Mild** maturity label (mild fear) for players aged 9 to 12: dark, foggy lighting, ghosts, skeletons, gravestones and a reaper statue, with no blood, gore or violence. Answer the Maturity & Compliance questionnaire to match before publishing.
- **Saves:** session-locked DataStore saves with a versioned schema, autosave every 60 seconds, and a final save on leave and on shutdown.
- **Purchases:** cosmetics only. The server opens prompts, a developer product is confirmed only after its grant is saved, and a ledger in the save stops a retried receipt granting twice.
- **Theme packs:** every player-facing name, colour, sound and model lives in a theme pack under `src/shared/Themes/`. Swapping themes is a new pack folder plus one line in `Config/Theme.luau`.

```
src/
  shared/                 ReplicatedStorage.Shared
    Config/
      Balance.luau        upgrade costs, income, goods and visitors
      Layout.luau         plot size, gate, buy buttons and build slots
      Catalog.luau        Robux cosmetics (ids are 0 until set up)
      Theme.luau          picks the active theme pack
    Themes/
      MoonlightFestival/
        init.luau         names, colours, the night's look, sounds
        Props.luau        a model for each upgrade
        Scenery.luau      plot dressing and the land around the plots
        Crowd.luau        visitors in costume and the goods on the move
        Pieces.luau       pumpkins, lanterns, ghosts, fences and the rest
    Kit.luau              helpers for building models from parts
    Progression.luau      what can be bought, when (pure)
    Earnings.luau         production chain, visitors, attractions (pure)
    Format.luau           number formatting for labels
  server/                 ServerScriptService.Server
    init.server.luau      starts services in order
    Services/             DataService, EconomyService, PlotService,
                          WorldService, ProductionService,
                          AttractionService, UpgradeService,
                          PurchaseService
    Lib/                  Migrations, SessionLock, ReceiptLedger,
                          RateLimiter (pure)
  client/                 StarterPlayerScripts.Client
    Hud.luau              cash counter, income, visitors, claim hint
    PlotActivity.luau     goods and visitors moving on every plot
    Motion.luau           floating, spinning, the ghost train, flicker
    BuildEffects.luau     the build-up when something is bought
    Sounds.luau           music, ambience and sound effects
tests/                    Lune tests, including the theme's models
tools/make_sounds.py      makes the original audio in assets/audio
tools/tune_balance.luau   picks upgrade costs to hit the pacing target
docs/progression.md       the upgrade paths and the 90 minute pacing rule
docs/rights-register.md   every external asset and dependency
```

The one remote, `RequestPurchase` for the cosmetic shop, is declared in `default.project.json`. Gates and buy buttons use touches, which the server sees directly.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder to get the pinned Rojo, StyLua, Selene and Lune.
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open a new Baseplate place in Studio (or delete the baseplate) and connect from the Rojo plugin.
4. In Game Settings, set **Max Players** to 6 to match `Layout.PlotCount`, and turn on **Security > Enable Studio Access to API Services** if you want saves to work in Studio. Without it, progress lives in memory for that session and the output says so.
5. Press Play, walk off the plaza into a plot's gate to claim it, then step on the glowing **Creepy Treat Stall** pad.
6. Optional, for sound: upload the seven files in `assets/audio` (Studio: **Window > Asset Manager**, then **Bulk Import**). Right-click each upload, choose **Copy Asset ID**, and paste it into `Sounds` in `src/shared/Themes/MoonlightFestival/init.luau` as `"rbxassetid://<id>"`. Until then the game is silent and the music button stays hidden.

## Checks

```sh
stylua --check src tests   # formatting
selene src                 # lint
lune run tests/run         # tests, including the theme's models
rojo build default.project.json -o build.rbxl
```

CI runs the same four on every pull request. The theme's models and scenery are built in the tests with Lune's Roblox library, which checks every property they set and that each model fits its slot. Services that call Roblox APIs (DataStores, MarketplaceService, terrain, players) are tested by playing in Studio.

A fully built plot is about 1,200 parts and 43 lights, and the land around the plots about 3,300 parts; a test keeps a plot under 1,500 parts and 60 lights. `Lighting.Technology` is set to Future in `default.project.json`, as scripts can't change it.

## Common changes

- **Add an upgrade:** add it to `Config/Balance.luau` (the comment at the top explains each kind and its fields), give it a name and colour in the theme pack, and give it a buy button in `Config/Layout.luau`, plus a slot for a new building. Give it a model in the theme's `Props.luau`, built inside its slot (an upgrade to a building is added inside that building's slot). The tests fail until all of these agree, and also if any route through the upgrade paths breaks the pacing rule in `docs/progression.md`.
- **Add a good:** add it to `Items` in `Config/Balance.luau` with its sale value, and to `Items` in the theme pack with a plural name and colour.
- **Swap the theme:** copy the `Themes/MoonlightFestival` folder, change its names, colours, look, sounds, models and scenery, and point `Config/Theme.luau` at the new folder. An artist's model can replace a built one: put it in `ReplicatedStorage.Assets` and name it in the upgrade's `Model` field. An upgrade with neither stays a greybox block.
- **Change the sounds:** edit `tools/make_sounds.py` and run it (Python 3 with numpy, and ffmpeg), then upload the new files and update the ids.
- **Change the save shape:** bump `Migrations.CURRENT_VERSION` and append a step. Never edit a step that has shipped.
- **Sell a cosmetic:** fill in its id in `Config/Catalog.luau` only after a price and value review. The brief rules out paid random rewards, rerolls, fake scarcity, misleading discounts, repeat prompts after a no, and anything that speeds up progression.

## Not built yet

The cosmetic shop UI, the tutorial, and uploaded art: every model is built from parts in code until an artist's models replace them. Visitors are a rate, not individual characters: the costumed walkers on each plot are decoration, and nothing about a visitor is simulated or saved. Ride rounds restart when a player rejoins, and nothing is earned while offline.
