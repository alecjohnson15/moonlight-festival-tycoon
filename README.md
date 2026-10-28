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
- **Flex items:** almost every upgrade unlocks something to wear, hold or have follow you: a Trick-or-Treat Lantern for the first stall, then a Witch's Cape, a Pumpkin Head, the Big Wooden Mallet, an Ember Trail, a Witch's Broom, a Pumpkling pet, Werewolf Claws, a Phantom Aura and, for building everything, the Crescent Moon Blade. A new item goes straight on if its slot is empty, a note pops up, and everyone on the server sees it. There are six slots (head, back, held, pet, aura, trail), one item each, and the choice is saved.
- **Wardrobe:** a button on the left (shown once you've earned your first item) opens a panel with a turning preview of every item, in four tabs: Earned, Deluxe, Brainrot Buddies and Legendary. Earned items say what to build to unlock them; paid ones show their price and exactly what they are.
- **Held items and weapons:** the held item is a Roblox Tool in your hotbar. Weapons swing with the built-in Slash or Lunge tool animation when clicked, and every player hears a thump or whoosh and sees a dust puff where it lands. Each weapon carries a `Weapon` attribute that the PvP arena reads its stats from (`Config/Weapons.luau`).
- **Purchases:** direct game-pass purchases with the contents stated up front, and no loot boxes, rerolls, timers or repeat prompts. Deluxe looks (a Moonstone Mallet that swings exactly like the wooden one, Neon Bat Wings, a Ghostfire Crown, an aura and a trail) and Brainrot Buddies (four original nonsense pets: Pipistrello Pizzetta, Fantasmino Gelatino, Candelino Wobblino and Zucchino Zombino) are looks only. The five Legendary weapons (Storm-Stone Hammer, Ghostlight Blade, Reaper's Scythe, Drowned Trident, Foxfire Fan) are a little stronger than the best earned weapon in the PvP arena only; that was the project owner's call, and their edge lives in `Config/Weapons.luau`. Nothing paid changes coins or income. The server opens prompts, a developer product is confirmed only after its grant is saved, and a ledger in the save stops a retried receipt granting twice. In Studio, every paid item counts as owned so it can be tried on; live servers never do this.
- **Theme packs:** every player-facing name, colour, sound and model lives in a theme pack under `src/shared/Themes/`. Swapping themes is a new pack folder plus one line in `Config/Theme.luau`.

```
src/
  shared/                 ReplicatedStorage.Shared
    Config/
      Balance.luau        upgrade costs, income, goods and visitors
      Layout.luau         plot size, gate, buy buttons and build slots
      Cosmetics.luau      everything players can wear, and how it unlocks
      Catalog.luau        Robux cosmetics (ids are 0 until set up)
      Theme.luau          picks the active theme pack
    Themes/
      MoonlightFestival/
        init.luau         names, colours, the night's look, sounds
        Props.luau        a model for each upgrade
        Scenery.luau      plot dressing and the land around the plots
        Crowd.luau        visitors in costume and the goods on the move
        Wearables.luau    a model or effect for each cosmetic
        Pieces.luau       pumpkins, lanterns, ghosts, fences and the rest
    Kit.luau              helpers for building models from parts
    Progression.luau      what can be bought, when (pure)
    Earnings.luau         production chain, visitors, attractions (pure)
    Wardrobe.luau         who owns which cosmetic, what goes where (pure)
    Format.luau           number formatting for labels
  server/                 ServerScriptService.Server
    init.server.luau      starts services in order
    Services/             DataService, EconomyService, PlotService,
                          WorldService, ProductionService,
                          AttractionService, UpgradeService,
                          PurchaseService, CosmeticService
    Lib/                  Migrations, SessionLock, ReceiptLedger,
                          RateLimiter (pure)
  client/                 StarterPlayerScripts.Client
    Hud.luau              cash counter, income, visitors, claim hint
    PlotActivity.luau     goods and visitors moving on every plot
    Motion.luau           floating, spinning, the ghost train, flicker
    BuildEffects.luau     the build-up when something is bought
    Sounds.luau           music, ambience and sound effects
    Wardrobe.luau         the wardrobe panel and unlock notes
    Pets.luau             every player's pet, following them
    Swing.luau            the thump and dust when a weapon lands
tests/                    Lune tests, including the theme's models
tools/make_sounds.py      makes the original audio in assets/audio
docs/rights-register.md   every external asset and dependency
```

The remotes are declared in `default.project.json`: `RequestPurchase` (open a purchase prompt), `EquipCosmetic` (wear or take off an item) and `CosmeticSwung` (the server telling clients a weapon swung). A client only names what it wants; the server checks it. Gates and buy buttons use touches, which the server sees directly.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder to get the pinned Rojo, StyLua, Selene and Lune.
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open a new Baseplate place in Studio (or delete the baseplate) and connect from the Rojo plugin.
4. In Game Settings, set **Max Players** to 6 to match `Layout.PlotCount`, and turn on **Security > Enable Studio Access to API Services** if you want saves to work in Studio. Without it, progress lives in memory for that session and the output says so.
5. Press Play, walk off the plaza into a plot's gate to claim it, then step on the glowing **Creepy Treat Stall** pad.
6. Optional, for sound: upload the nine files in `assets/audio` (Studio: **Window > Asset Manager**, then **Bulk Import**). Right-click each upload, choose **Copy Asset ID**, and paste it into `Sounds` in `src/shared/Themes/MoonlightFestival/init.luau` as `"rbxassetid://<id>"`. Until then the game is silent and the music button stays hidden.

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

- **Add an upgrade:** add it to `Config/Balance.luau` (the comment at the top explains each kind and its fields), give it a name and colour in the theme pack, and give it a buy button in `Config/Layout.luau`, plus a slot for anything but a boost. Give it a model in the theme's `Props.luau`, built inside its slot (a boost's model is added inside the slot of the station it boosts). The tests fail until all of these agree, and also if the upgrade earns nothing when it first becomes available or leaves a gap of more than two minutes before the next one.
- **Add a good:** add it to `Items` in `Config/Balance.luau` with its sale value, and to `Items` in the theme pack with a plural name and colour.
- **Swap the theme:** copy the `Themes/MoonlightFestival` folder, change its names, colours, look, sounds, models and scenery, and point `Config/Theme.luau` at the new folder. An artist's model can replace a built one: put it in `ReplicatedStorage.Assets` and name it in the upgrade's `Model` field. An upgrade with neither stays a greybox block.
- **Change the sounds:** edit `tools/make_sounds.py` and run it (Python 3 with numpy, and ffmpeg), then upload the new files and update the ids.
- **Change the save shape:** bump `Migrations.CURRENT_VERSION` and append a step. Never edit a step that has shipped.
- **Add a cosmetic:** add it to `Config/Cosmetics.luau` with its slot, line and unlock (or `Premium = true` and a matching `Config/Catalog.luau` entry), name it in the theme pack's `Cosmetics`, and give it a look in `Wearables.luau`. The tests check each item fits the body, can't touch or collide, and that every paid look of a weapon fights like an earned one.
- **Sell a cosmetic:** create a game pass on the Roblox website for each item in `Config/Catalog.luau` (`SuggestedRobux` is a starting price), and paste its id into `PassId` only after a price and value review. The brief rules out paid random rewards, rerolls, fake scarcity, misleading discounts, repeat prompts after a no, and anything that speeds up progression.

## Not built yet

The tutorial, emotes and plot decorations for the shop, and uploaded art: every model is built from parts in code until an artist's models replace them. Visitors are a rate, not individual characters: the costumed walkers on each plot are decoration, and nothing about a visitor is simulated or saved. Ride rounds restart when a player rejoins, and nothing is earned while offline.
