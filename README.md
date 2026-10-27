# Moonlight Festival Tycoon

An original Roblox tycoon: players turn an empty plot into a festival, earn coins from what they build and reinvest them. This repository holds the theme-neutral core systems. The festival theme is a placeholder until trend research in August 2027 confirms or replaces it.

## What's here

- **Plots:** players spawn on the plaza and claim a plot by walking into its gate. The gate then turns see-through and shows the owner's name, and they respawn on their plot from then on. With no `Workspace.Plots` folder in the place, the server generates a greybox row of plots, gates and a spawn plaza, so the game runs from an empty place file. A place that brings its own plots can give each one a `Gate` part.
- **Buy buttons:** everything is bought by stepping on buttons on the plot floor, each showing its name, price and what it adds per second. A button appears, fading in, once its requirement is owned. Stepping on it builds the upgrade with a small effect, and the button fades away. Buttons turn red on your own screen while you can't afford them.
- **First minute:** claim a gate, step on the free Snack Stall button, and the first paid upgrade is affordable within a minute. A test enforces that last part.
- **Production chain:** the pumpkin patch grows goods, the kitchen cooks as many as it has room for, and the stall sells everything that reaches it, plus what it makes itself. Cooked goods sell for more, so a full kitchen is the next thing to upgrade, and its label says "(full)" when goods are going past it.
- **Visitors and attractions:** every attraction draws visitors, and there are three types. A walkthrough charges each visitor up to its capacity, a ride runs in rounds and pays per seat filled, and a showpiece is free to visit and earns by drawing a crowd for the others.
- **Economy:** the server pays income on a tick into the Coins leaderstat and owns every coin change. A button touch only names the upgrade the player wants, and only the plot's owner can buy from it. Button gains are worked out with the same code the server pays from.
- **Plot activity:** goods roll along the chain and greybox visitors walk to the stall and the attractions. Rides on your own plot show a countdown and each round's takings. All of this is drawn on each client and changes nothing.
- **Saves:** session-locked DataStore saves with a versioned schema, autosave every 60 seconds, and a final save on leave and on shutdown.
- **Purchases:** cosmetics only. The server opens prompts, a developer product is confirmed only after its grant is saved, and a ledger in the save stops a retried receipt granting twice.
- **Theme packs:** every player-facing name and colour lives in `src/shared/Themes/`. Swapping themes is a new file plus one line in `Config/Theme.luau`.

```
src/
  shared/                 ReplicatedStorage.Shared
    Config/
      Balance.luau        upgrade costs, income, goods and visitors
      Layout.luau         plot size, gate, buy buttons and build slots
      Catalog.luau        Robux cosmetics (ids are 0 until set up)
      Theme.luau          picks the active theme pack
    Themes/
      MoonlightFestival.luau
    Progression.luau      what can be bought, when (pure)
    Earnings.luau         production chain, visitors, attractions (pure)
    Format.luau           number formatting for labels
  server/                 ServerScriptService.Server
    init.server.luau      starts services in order
    Services/             DataService, EconomyService, PlotService,
                          ProductionService, AttractionService,
                          UpgradeService, PurchaseService
    Lib/                  Migrations, SessionLock, ReceiptLedger,
                          RateLimiter (pure)
  client/                 StarterPlayerScripts.Client
    Hud.luau              coins, income, visitors and the claim hint
    PlotActivity.luau     goods and visitors moving on every plot
tests/                    Lune tests for the pure modules
docs/rights-register.md   every external asset and dependency
```

The one remote, `RequestPurchase` for the cosmetic shop, is declared in `default.project.json`. Gates and buy buttons use touches, which the server sees directly.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder to get the pinned Rojo, StyLua, Selene and Lune.
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open a new Baseplate place in Studio (or delete the baseplate) and connect from the Rojo plugin.
4. In Game Settings, set **Max Players** to 6 to match `Layout.PlotCount`, and turn on **Security > Enable Studio Access to API Services** if you want saves to work in Studio. Without it, progress lives in memory for that session and the output says so.
5. Press Play, walk off the plaza into a plot's gate to claim it, then step on the green **Snack Stall** button.

## Checks

```sh
stylua --check src tests   # formatting
selene src                 # lint
lune run tests/run         # tests for the pure modules
rojo build default.project.json -o build.rbxl
```

CI runs the same four on every pull request. Services that call Roblox APIs (DataStores, MarketplaceService, parts) are tested by playing in Studio.

## Common changes

- **Add an upgrade:** add it to `Config/Balance.luau` (the comment at the top explains each kind and its fields), give it a name and colour in the theme pack, and give it a buy button in `Config/Layout.luau`, plus a slot for anything but a boost. The tests fail until all three agree, and also if the upgrade earns nothing when it first becomes available or leaves a gap of more than two minutes before the next one.
- **Add a good:** add it to `Items` in `Config/Balance.luau` with its sale value, and to `Items` in the theme pack with a plural name and colour.
- **Swap the theme:** copy `Themes/MoonlightFestival.luau`, rename everything in it, and point `Config/Theme.luau` at the new file. Models go in `ReplicatedStorage.Assets` and are named by each upgrade's `Model` field; upgrades without a model stay greybox.
- **Change the save shape:** bump `Migrations.CURRENT_VERSION` and append a step. Never edit a step that has shipped.
- **Sell a cosmetic:** fill in its id in `Config/Catalog.luau` only after a price and value review. The brief rules out paid random rewards, rerolls, fake scarcity, misleading discounts, repeat prompts after a no, and anything that speeds up progression.

## Not built yet

The cosmetic shop UI, the tutorial, real art and decoration placement. Visitors are a rate, not individual characters: the walkers on each plot are decoration, and nothing about a visitor is simulated or saved. Ride rounds restart when a player rejoins, and nothing is earned while offline.
