# Autonomous upgrade report: Catwalk Clash

The overnight pass of 5 November 2026 on `games/catwalk-clash`, following
`catwalk-clash-top100-directive.md`. It was done on branch
`claude/project-thread-boq9ks` (PR #15).

**What this report is not.** Nobody has played this build. It has not been run
in Roblox Studio, on a phone, or with other players. Everything below is
backed by source inspection, Lune tests, deterministic simulations and a
headless Rojo build, and none of those can say whether the game is fun,
looks good, or will find an audience. Nothing here claims the game is "top-100
ready". Monetization, product entitlements and the content rating were not
changed.

## Summary

- **Fairer voting.** A friend voting *against* their friend no longer counts
  half. Friends and brand-new accounts used to count half across the board.
  Now the first two such votes for a walker count fully, and only extra ones
  are halved. The rules are explained in game.
- **Fairer brackets.** A simulation showed that seeding by Style Score gave
  the top score a bye every time and the lowest score never. The draw is now
  random, and the lowest score's crown chance with five walkers went from 14%
  to 19.9% (fair share 20%).
- **Every look is seen.** An opening lineup puts every contestant on stage
  before the first matchup. Players who join mid-show now get the bracket and
  the current matchup straight away.
- **Easier dressing.** The wardrobe has Undo and Redo, and a **Theme look**
  button that builds an editable themed outfit from pieces you own. A
  three-step guide shows on your first show.
- **Honest judges.** The judges are documented as rules, not AI. They now
  give star ratings and compliments instead of the exact score. Tests guard
  against cheap exploits.
- **New players are protected.** Your first 10 walks can only raise your
  Style Score.
- **Season end.** After 1 February 2027 the game stops selling the Season 1
  pass and says the season is over. Reached rewards stay claimable.
- **More.** Reduced motion, vote buttons that don't rely on colour, more
  analytics events, a theme coverage matrix for all 69 themes, and 25 new
  tests (56 → 81).

## Commits

| Commit | What |
| --- | --- |
| `3e627fd` | Fairer voting and brackets, protected new players: capped suspect votes, random draw, opening lineup, judge feedback, mid-show catch-up, Theme look, undo/redo, first-show guide, reduced motion, Season 1 end handling, analytics events, tests |
| `b93594c` | In-game voting rules, theme coverage matrix, rivals-only and season-end tests, docs, CI also checks `tools/` |
| The commit that adds this file | This report |

The base before this pass is `b4f2327`.

## Changed files

Paths are under `games/catwalk-clash/` unless they start with `.github`.

| File | Change |
| --- | --- |
| `.github/workflows/game-catwalk-clash.yml` | Formats and lints `tools/` too |
| `README.md` | Feature list and commands updated |
| `docs/design.md` | Voting, bracket, lineup, judges, Style Score, reduced motion |
| `docs/launch.md` | Take the Season 1 pass off sale on Roblox on 1 Feb 2027 |
| `docs/theme-coverage.md` | New: per-theme tags, colours, season, free/earned coverage, best score, closest theme |
| `docs/AUTONOMOUS_UPGRADE_REPORT.md` | New: this report |
| `src/client/Camera.luau` | Cuts instead of swoops with reduced motion |
| `src/client/Effects.luau` | No flashes with reduced motion |
| `src/client/Menus.luau` | "How voting works" in Profile; Reduced motion setting; season-over pass board |
| `src/client/Show.luau` | Lineup, ◀/▶ named vote buttons, judges' notes, kinder walker toast |
| `src/client/Tips.luau` | First-show three-step guide |
| `src/client/Wardrobe.luau` | Undo, Redo, Theme look, action hooks |
| `src/server/Lib/Saves.luau` | `Settings.ReducedMotion` (filled in for old saves) |
| `src/server/Services/AnalyticsService.luau` | Event list |
| `src/server/Services/CatalogService.luau` | `CatalogSearch`, `CatalogBuyPrompt` events |
| `src/server/Services/PurchaseService.luau` | Won't prompt the Season 1 pass after the season ends |
| `src/server/Services/RoundService.luau` | Suspect ballots, seeding flag, lineup, mid-show catch-up, judge feedback, `ReadyPressed`/`MatchWalked`/`ThemePlayed`/`JoinedMidShow` |
| `src/server/Services/ShopService.luau` | `ReducedMotion` setting, `OutfitSaved` event |
| `src/shared/Bracket.luau` | `Bracket.seeded(list, mode, rng)` |
| `src/shared/Config/Game.luau` | `Show` flags, voting mode, `ProtectedWalks` |
| `src/shared/Config/Layout.luau` | Lineup spots and camera |
| `src/shared/Config/Themes.luau` | Three themes re-tagged so no two share a tag set |
| `src/shared/Judge.luau` | Rules-not-AI header, `Judge.feedback` |
| `src/shared/StyleScore.luau` | Protected first walks |
| `src/shared/Stylist.luau` | New: Theme look builder |
| `src/shared/Voting.luau` | `isSuspect`, `ballot`, capped tally |
| `tests/Judge.spec.luau` | Exploit, feedback, Stylist, theme and protection tests |
| `tests/Progress.spec.luau` | Season-end test |
| `tests/Tournament.spec.luau` | New: bracket simulations |
| `tests/Voting.spec.luau` | Capped mode, friend direction, plain counts, property test |
| `tests/run.luau` | Runs the tournament spec |
| `tools/theme_matrix.luau` | New: writes `docs/theme-coverage.md` |

## Gap table

Labels, as the directive asks:

- **CONFIRMED**: the suspected problem was real.
- **PARTIAL**: the problem was partly real, or partly handled already.
- **NOT FOUND**: the source already handles it.
- **UNVERIFIED**: it can't be checked without running the game.

### P0

| Item | Suspected gap | Label | What was found / done | Evidence |
| --- | --- | --- | --- | --- |
| CC-01 | No undo/redo | CONFIRMED | Added Undo/Redo (40 steps) | `Wardrobe.luau` |
| CC-01 | No quick start or randomize | CONFIRMED | **Theme look** picks owned pieces that fit, at random among equals, and paints them in theme colours. It is a start to edit, not a finished look | `Stylist.luau`; tests: owned-only, nails every theme for a new player, varies per press |
| CC-01 | Favourites / recent items | PARTIAL | Catalog items could already be favourited. Wardrobe pieces have no favourites or recent list (deferred) | `CatalogService.luau` |
| CC-01 | Slot collisions, duplicates | NOT FOUND | One piece per slot by design; duplicate catalog ids are dropped by `Look.sanitize` | `Look.luau` |
| CC-01 | R15 / attachment failures | PARTIAL | Poses only turn R15 joints (test); launch needs R15 (launch.md). Catalog attachment failures at runtime are unverified | `tests/Wardrobe.spec.luau` |
| CC-01 | Clipping, repetitive silhouettes, mobile density | UNVERIFIED | Needs eyes on a device. Every piece builds and stays under 40 parts (test) | |
| CC-01 | Free coverage | NOT FOUND | Already tested; now also tested through Theme look | `tests/Judge.spec.luau` |
| CC-02 | Rating seeding is unfair | CONFIRMED | Top score bye 100% vs lowest 0%; lowest score's crown 14% vs 19.9% under a random draw. Default is now Random | `tests/Tournament.spec.luau` |
| CC-02 | Some looks never shown | PARTIAL | Everyone already walked at least once (2–16 entrants, 50 runs each, both modes), but losers were seen once, late. Added a 7 s opening **lineup** of every look | `RoundService.runLineup` |
| CC-02 | Unbounded show | NOT FOUND | n − 1 matchups always; 12 walkers take 210 s including the lineup | simulation |
| CC-02 | Withdrawals break it | NOT FOUND | 2,000 random-withdrawal runs: always finishes, never sends out someone who left | simulation |
| CC-02 | One entrant, zero votes, ties | NOT FOUND | Server skips shows under 2 entrants and rivals fill to 4; judges decide empty rooms; ties go judges → Style Score → coin | Tournament and Voting specs |
| CC-02 | Swiss or groups instead | Considered | Not adopted: they need more matchups than the ~17 s each budget allows. The lineup gives exposure without lengthening the show | |
| CC-03 | Judges called "AI" | NOT FOUND | No game text called them AI (the word came from the brief). Code and docs now say "rules, not AI" | `Judge.luau`, `design.md` |
| CC-03 | Exact score shown | CONFIRMED | The walker toast showed the theme score. Now: theme stars and up to two compliments, no digits | `Judge.feedback`; test checks no digits |
| CC-03 | One-tag spam, one piece | NOT FOUND | Tag points cap at 54; one piece can't nail a theme (test) | |
| CC-03 | Catalog-name stuffing | NOT FOUND | Word points cap at 24; names alone can't nail (test) | |
| CC-03 | Empty outfit | NOT FOUND | Scores under 20 (test) | |
| CC-03 | Invisible pieces | NOT FOUND | Most transparent finish (Glass) is 0.25, still visible | `Build/Pieces.luau` |
| CC-03 | Monochrome dominance | PARTIAL | One theme colour head to toe earns the full colour points, but those cap at 16 of 100. Left as is: a single-colour look is legitimate | `Judge.themeScore` |
| CC-03 | Judges outweigh crowds | NOT FOUND | 3 votes each, minus 0.25 per audience vote, floor 0.5 | `Voting.judgeWeight` |
| CC-04 | Friend half-weight is unfair | CONFIRMED | It applied to a friend of *either* walker, so voting against your friend was halved, and every friend or new account was halved. Now a vote is suspect only if it's for a friend or from an account under 7 days; the first 2 suspect votes per walker count fully | `Voting.luau`; 500-case property test |
| CC-04 | Friendship asymmetric, lookup failures | NOT FOUND | Stored both ways; a failed lookup counts as "not friends", so the vote counts in full | `RoundService.checkFriends` |
| CC-04 | Weights exposed | NOT FOUND | Players see plain counts only (test) | |
| CC-04 | Forgery, replay, self-vote, client timing | NOT FOUND | Server checks match id, server-time window, one ballot per user id, rate limit, walkers barred; rivals don't vote | `Voting.canVote`, `RoundService.onCastVote` |
| CC-04 | No plain-language rules | CONFIRMED | Added "How voting works" to the Profile window. It promises a limit, not perfect fairness | `Menus.renderProfile` |
| CC-05 | No first-outfit guide | PARTIAL | Phase tips existed. Added a three-step checklist card in the corner on the first show. It never blocks input | `Tips.luau` |
| CC-05 | Mid-show joiners stranded | CONFIRMED | They got the phase but not the bracket or current matchup until the next one. Now sent both 3 s after joining | `RoundService.syncLateJoiner` |
| CC-05 | Editable starter outfit | PARTIAL | A default look already existed; Theme look gives an editable themed start | |
| CC-05 | Visual theme examples | UNVERIFIED / deferred | Needs art | |

### P1

| Item | Suspected gap | Label | What was found / done | Evidence |
| --- | --- | --- | --- | --- |
| CC-06 | No reduced motion | CONFIRMED | Setting added (saved): no flashes, camera cuts | `Effects`, `Camera`, `Saves` |
| CC-06 | Only win/lose feedback | PARTIAL | Added judges' notes and "Great walk!" plus Style Score change | `Show.luau` |
| CC-06 | Framing, clipping, lighting, pacing feel | UNVERIFIED | Needs Studio | |
| CC-07 | Themes differ only in title | PARTIAL | 3 themes shared a tag set with another. Now re-tagged, and a test keeps every set unique. Still, 33 of 69 themes share two-thirds of their tags with their closest theme | `docs/theme-coverage.md` |
| CC-07 | Coverage matrix | CONFIRMED absent | Added; the hardest themes for free pieces score 59 against 55 to nail | `tools/theme_matrix.luau` |
| CC-07 | Spotlight scheduling, dead seasonal windows | NOT FOUND | Tests: options and spotlight every day for 3 years; all windows valid | `tests/Judge.spec.luau` |
| CC-07 | Season rollover after 2027-02-01 | CONFIRMED | The board said "hasn't started yet" and still offered the pass. Fixed; XP stops, reached rewards stay claimable (test). Season 2 config not written | `Menus`, `PurchaseService`, `Progress.spec` |
| CC-08 | Catalog ids trusted | NOT FOUND | Server re-checks each id with `GetProductInfoAsync` and an asset-type allow list | `CatalogService.items` |
| CC-08 | Slow search, outages | NOT FOUND | `pcall`, 300 s cache, rate limit; the wardrobe doesn't depend on the catalog. Behaviour during a real outage is unverified | |
| CC-08 | Purchases | NOT FOUND | Roblox's own prompt only; game never sells catalog items as its own | |
| CC-09 | Rivals not disclosed | NOT FOUND | Labelled "Studio model"; the lineup marks them "(model)"; they only fill to 4 entrants | |
| CC-09 | Scripted champion | NOT FOUND (with a tuning note) | 1,500 rivals-only shows (judges decide): all 10 rivals win sometimes, but crown rates range from 5% (Dot Dazzle) to 57% (Regal Rue) of the shows they enter | simulation |
| CC-10 | Elo loss spiral | CONFIRMED | A new player could drop a rank after their first loss. The first 10 walks now can't lose points | `StyleScore.luau`, test |
| CC-10 | Big Closet, Color Studio | Audit only | Free players get 4 outfit slots and all 36 palette colours. Big Closet (24 slots) and Color Studio (full picker) are convenience and range on top. **Not changed**, as instructed | `Config/Catalog.luau` |
| CC-10 | Participation vs rank rewards | NOT FOUND | Sparkles already pay for walking and voting, not only winning | |
| CC-11 | Colour-only vote sides | CONFIRMED | Buttons now read "◀ Name" and "Name ▶" | `Show.luau` |
| CC-11 | Controller, safe area, phone layout | UNVERIFIED | Needs devices | |
| CC-11 | Sound | NOT FOUND | 20 original sounds made by `tools/make_sounds.py`, listed in `docs/rights-register.md`. Mix levels unverified | |
| CC-12 | Telemetry gaps | PARTIAL | A 9-step funnel existed. `ThemePlayed` was documented but never logged (fixed). Added `ReadyPressed`, `MatchWalked`, `JoinedMidShow`, `CatalogSearch`, `CatalogBuyPrompt`, `OutfitSaved` | `AnalyticsService.luau` |
| CC-12 | Saves, receipts | NOT FOUND | Session lock, `UpdateAsync` with retries, receipts granted once by `PurchaseId` | `DataService`, `PurchaseService` |
| CC-12 | State machine under stress | PARTIAL | Bracket and voting are simulated and property-tested. The round loop in `RoundService` needs the Roblox runtime | |
| CC-12 | Client performance | PARTIAL | Part budgets tested (152 pieces, 1,231 parts; map 693 parts, 38 lights). FPS unverified | |

## Feature flags and rollback

All are in `src/shared/Config/Game.luau`.

| Flag | Default | Roll back with |
| --- | --- | --- |
| `Show.Seeding` | `"Random"` | `"Rating"` (old seeding by Style Score) |
| `Show.Lineup` | `true` | `false` (no opening lineup) |
| `Show.LineupSeconds` | `7` | Any length |
| `Show.JudgeFeedback` | `true` | `false` (no judges' notes) |
| `Voting.Mode` | `"Capped"` | `"Flat"` (old rule: every friend of either walker and every new account at half) |
| `Voting.SuspectFullVotes` | `2` | `0` makes every suspect vote count `SuspectWeight` |
| `Voting.SuspectWeight` | `0.5` | Any weight |
| `StyleScore.ProtectedWalks` | `10` | `0` (no protection) |

Reduced motion is a player setting, off by default. Old saves get it filled
in automatically, with no migration.

## Commands and results

Run from `games/catwalk-clash` at the final commit:

| Command | Result |
| --- | --- |
| `stylua --check src tests tools` | Clean |
| `selene src tests tools` | 0 errors, 0 warnings |
| `lune run tests/run` | **81 passed, 0 failed** (56 at `b4f2327`) |
| `rojo build default.project.json -o catwalk-clash.rbxl` | Built |
| `lune run tools/theme_matrix` | Wrote `docs/theme-coverage.md` (69 themes) |

Simulation output from the test run:

```
longest show: 12 walkers, 210 s
bye chance, top vs lowest score: Rating 1 vs 0; Random 60% vs 59%
lowest score's crown chance with 5 walkers: Rating 14%, Random 19.9% (fair share 20%)
rivals-only shows: 10/10 rivals won; crown rate per show entered from 5% (Dot Dazzle) to 57% (Regal Rue), fair share 25%
```

The release place file was rebuilt from this commit at
`/mnt/project-files/release/catwalk-clash.rbxl`.

## Verified vs inferred

**Verified by automated evidence**

- Bracket invariants for 2–16 entrants, withdrawals, bye distribution and crown fairness.
- Capped voting maths, vote direction, plain counts, and judge fade.
- The judges' exploit caps, and that feedback contains no digits.
- Free and earned theme coverage, and Theme look nailing every theme.
- Theme tag uniqueness, scheduling and season end.
- Style Score protection.
- Part budgets, and that the place builds.

**Inferred from reading the code, not run**

- The lineup places walkers on stage and returns them.
- Mid-show joiners receive the bracket and current matchup.
- The Undo/Redo/Theme look buttons work and fit the wardrobe.
- The first-show guide ticks its steps.
- Reduced motion stops flashes and swoops.
- The pass board shows "season over" after the end date.
- Analytics events reach the Creator Dashboard.

**Unknown until people play**

- Whether the show is fun to watch, and whether the lineup feels like a celebration or a delay.
- Whether capped votes feel fair to players.
- Whether Theme look makes outfits feel samey.
- Phone and controller usability.
- Clipping, visual quality and performance.

## Remaining risks

1. **Never run in Studio.** The new runtime code (lineup, catch-up, wardrobe
   buttons, guide) could fail at runtime in ways a build can't catch.
2. **Lineup placement.** Twelve spots in two rows at stage height were
   computed from the layout, not seen. They could overlap set dressing or
   the camera could frame them badly.
3. **Theme look homogenizing.** If everyone presses it, looks may converge.
   It is random among equally fitting pieces, but the risk is real. Watch
   `ThemeLook` against win rates once analytics flow.
4. **Theme overlap.** Unique tag sets don't make themes play differently.
   33 themes share two-thirds of their tags with their closest one.
5. **Hardest free themes.** Five themes (Space Explorer, Future Fashion and
   others) reach 59 with free pieces, just over the 55 needed to nail them.
6. **Rival skill spread.** In rivals-only shows, Regal Rue (skill 0.8) wins
   57% of the shows they enter. Whether that feels like a fair challenge or
   a scripted favourite needs players.
7. **Capped voting still lets two friends count fully per walker.** This is
   by design for small honest groups, but on a 4–6 player server two friends
   can still decide a close matchup.
8. **Season 1 pass after 1 February 2027.** The game stops offering it, but
   it stays on sale on its Roblox page until taken off sale there (noted in
   `docs/launch.md`).

## Deferred work

- Favourites and recently used list for wardrobe pieces.
- Visual theme examples on the theme reveal.
- Phone-first wardrobe density pass, controller navigation and safe areas.
- Theme modifiers (accessory focus, material spotlight) to separate
  overlapping themes.
- Time-to-first-unlock and Sparkles economy calculation.
- Personal lookbook / gallery of past outfits.
- Season 2 config.
- A free baseline review of Big Closet and Color Studio. That is an owner
  decision because it changes what paid passes give.
- Clearer wording on catalog commission in `docs/design.md`. Roblox's
  affiliate terms decide what is paid.

## Prioritized next-day review

1. **Read the voting change** (`Voting.luau`, `design.md` "Server-side
   voting"). It is the change players will feel most. `Voting.Mode = "Flat"`
   undoes it.
2. **Read the bracket change and lineup** (`Bracket.seeded`,
   `RoundService.runLineup`). Flags: `Show.Seeding`, `Show.Lineup`.
3. **When someone next plays a show**, the riskiest unseen parts are the
   lineup positions and camera, the wardrobe's new tool row on a phone, and
   the first-show guide.
4. **Decide on Big Closet / Color Studio baselines.** These were audited
   only.
5. **Skim `docs/theme-coverage.md`** for themes worth merging or giving a
   modifier.
6. **Rival skill spread.** Decide whether 5%–57% crown rates are the
   intended challenge.
