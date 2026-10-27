# Moonlight Festival Tycoon

An original Roblox tycoon: players turn an empty plot into a festival, earn coins from what they build and reinvest them. This repository holds the theme-neutral core systems. The festival theme is a placeholder until trend research in August 2027 confirms or replaces it.

## What's here

- **Plots:** each player gets a plot when their save loads. With no `Workspace.Plots` folder in the place, the server generates a greybox row of plots and a spawn plaza, so the game runs from an empty place file.
- **First minute:** the starter stall is free, its "Serve visitor" prompt pays a small reward on a cooldown, and the first paid upgrade is affordable within a minute. A test enforces that last part.
- **Economy:** the server pays income on a tick and owns every coin change. The client only names the upgrade it wants.
- **Saves:** session-locked DataStore saves with a versioned schema, autosave every 60 seconds, and a final save on leave and on shutdown.
- **Purchases:** cosmetics only. The server opens prompts, a developer product is confirmed only after its grant is saved, and a ledger in the save stops a retried receipt granting twice.
- **Theme packs:** every player-facing name and colour lives in `src/shared/Themes/`. Swapping themes is a new file plus one line in `Config/Theme.luau`.

```
src/
  shared/                 ReplicatedStorage.Shared
    Config/
      Balance.luau        upgrade costs, income, serve task
      Layout.luau         plot count and where each upgrade is built
      Catalog.luau        Robux cosmetics (ids are 0 until set up)
      Theme.luau          picks the active theme pack
    Themes/
      MoonlightFestival.luau
    Progression.luau      upgrade rules and income math (pure)
  server/                 ServerScriptService.Server
    init.server.luau      starts services in order
    Services/             DataService, EconomyService, PlotService,
                          UpgradeService, PurchaseService
    Lib/                  Migrations, SessionLock, ReceiptLedger,
                          RateLimiter (pure)
  client/                 StarterPlayerScripts.Client
    Hud.luau              coins, income and the next upgrades
tests/                    Lune tests for the pure modules
docs/rights-register.md   every external asset and dependency
```

Remotes (`RequestUpgrade`, `RequestPurchase`, `StateSync`) are declared in `default.project.json`.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder to get the pinned Rojo, StyLua, Selene and Lune.
2. Install the Rojo plugin in Roblox Studio.
3. Run `rojo serve`, open a new Baseplate place in Studio (or delete the baseplate) and connect from the Rojo plugin.
4. In Game Settings, set **Max Players** to 6 to match `Layout.PlotCount`, and turn on **Security > Enable Studio Access to API Services** if you want saves to work in Studio. Without it, progress lives in memory for that session and the output says so.
5. Press Play.

## Checks

```sh
stylua --check src tests   # formatting
selene src                 # lint
lune run tests/run         # tests for the pure modules
rojo build default.project.json -o build.rbxl
```

CI runs the same four on every pull request. Services that call Roblox APIs (DataStores, MarketplaceService, parts) are tested by playing in Studio.

## Common changes

- **Add an upgrade:** add it to `Config/Balance.luau`, give it a name and colour in the theme pack, and, for a producer, a slot in `Config/Layout.luau`. The tests fail until all three agree.
- **Swap the theme:** copy `Themes/MoonlightFestival.luau`, rename everything in it, and point `Config/Theme.luau` at the new file. Models go in `ReplicatedStorage.Assets` and are named by each upgrade's `Model` field; upgrades without a model stay greybox.
- **Change the save shape:** bump `Migrations.CURRENT_VERSION` and append a step. Never edit a step that has shipped.
- **Sell a cosmetic:** fill in its id in `Config/Catalog.luau` only after a price and value review. The brief rules out paid random rewards, rerolls, fake scarcity, misleading discounts, repeat prompts after a no, and anything that speeds up progression.

## Not built yet

The cosmetic shop UI, the tutorial, real art, visitors, decoration placement, and attraction behaviour beyond income. Upgrades currently earn coins directly; the production chain is expressed through unlock order and can be deepened later.
