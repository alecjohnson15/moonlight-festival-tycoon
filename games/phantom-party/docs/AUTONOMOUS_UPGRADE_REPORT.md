# Phantom Party: autonomous upgrade report

Overnight pass of 2026-11-05 on `games/phantom-party`, branch
`claude/project-thread-mpq3h7` (PR #16), working from the owner's upgrade
directive. **Nothing here has been played by a person.** Every result
below comes from reading the source, pure-rule tests, headless map builds
and models run in Lune. They catch logic and layout mistakes. They can't
tell whether the game is fun, readable or smooth on a phone. This pass
doesn't make the game "top-100 ready", and nothing in this report claims
that.

Monetization, product entitlements and the content rating are unchanged.
No game pass, price or paid item was touched.

## 1. Gap table

Each suspected gap from the directive was checked in the source before any
work, and labelled with one of these:

- **CONFIRMED**: the defect is real.
- **PARTIAL**: some of it was already there.
- **NOT FOUND**: the feature didn't exist. No defect was claimed beyond
  that.
- **UNVERIFIED**: it can't be settled without a person playing.

| Item | Suspected gap | Label | What the source showed | What changed |
| --- | --- | --- | --- | --- |
| PP-01 | Clues are shallow; the Truth Bell is the only deduction | CONFIRMED | Pages only filled the bell: 10 a page, a live room tracker from 50, and a full reveal at 100 that could repeat (`PickupService`, `Config/Rewards`) | Leads in four families (witness, commotion, footprints, tampering): imperfect, server-decided, expiring. Added a notebook UI and a paced bell (PP-07) |
| PP-01 | Evidence notebook | NOT FOUND | No clue UI apart from the bell meter | `client/Leads.luau`: kind, room and age for each lead, with "Leads, not proof" |
| PP-01/12 | Private role leakage | CONFIRMED | The Swing effect sent the Phantom's user id to every client (`CombatService`) | Effects carry no id or role and go only to players in range. Covered by a source scan test |
| PP-02 | Participation cliff after going out | PARTIAL | A spectator bar already followed living players without showing roles. Apart from that, an out player had nothing to do | Plaza wisp hunt (pays nothing, can't reach the round), a next-party countdown and a card for mid-round joiners |
| PP-02 | Ghost chat leaks | CONFIRMED (whispers) | The proximity rule covered the general channel, but whisper channels bypassed it (`ChatService`) | Every text channel, whispers included, now follows `Rules/Chat` |
| PP-03 | Tags and shots through walls | CONFIRMED | Swings and spherecasts had no line-of-sight check | Swings need a clear line. Shots and throws can't start behind a wall. Flag: `Combat.LineOfSight` |
| PP-03 | Client-trusted origin | PARTIAL | Already capped at 10 studs from the server position, but a shot could start on the far side of a wall | `Rules/Combat.origin` falls back to the server position |
| PP-03 | Silent outcomes and missing telegraphs | PARTIAL | Everyone sees a drawn blade, but the attacker got no hit feedback and nearby guests got no draw warning | Hit marker (tagged, missed, caught, innocent), draw warning within 45 studs, controller bindings |
| PP-03 | Round-end and late hits | PARTIAL | Knockdowns after the round ended were already ignored, but a throw could still land after its thrower was out | The throw stops when the thrower is no longer standing. The landing event is recorded |
| PP-03 | Spawn trapping | NOT FOUND | The blade was already sheathed for the first 8 s | Spawn spacing is now tested: closest pair 16 studs (Manor) and 12 (Carnival); blade reach is 7 |
| PP-03 | Latency-reordered events, two attackers at once | UNVERIFIED | Can't be shown headless | Pure rules are tested. Needs a multi-client session |
| PP-04 | One authoritative win function | PARTIAL | `Round.outcome` existed, but a Phantom who left counted as caught, all guests leaving counted as "every guest was tagged", and a no-Phantom flag went into a parameter named `practice` | Five named reasons in a fixed order (PhantomLeft, PhantomOut, GuestsLeft, AllTagged, Time), checked against an independent referee for every mix of states |
| PP-04 | Revive, Saboteur and blaster rules | PARTIAL | Rules were spread through `CombatService` | `Round.canRevive` and `Round.canPickUp`, with tests: the Phantom and Saboteur can't be revived, and the blaster goes only to a standing guest |
| PP-05 | Contextual onboarding | NOT FOUND | Only the role card | 13 first-time tips: one at a time, non-blocking, worded for keyboard, touch or controller, and saved |
| PP-05 | Practice limits | PARTIAL | Practice already paid nothing, but the card didn't say what it can't teach | "PRACTICE ROUND" heading, with a footer naming its limits |
| PP-06 | Role droughts | CONFIRMED (model) | Longest wait for a Phantom turn at 12 players: 88 rounds | Tickets weighted squared, cap 20. Longest wait at 12 players is now 30 rounds |
| PP-06 | Weak low-population play | PARTIAL | Two players make a Phantom against Guardian duel with no deduction | Honest "Duel" label and card text. Rules specific to 3 or 4 players are deferred |
| PP-07 | Bell runaway | CONFIRMED (model) | At 12 players the bell rang 2.77 times a round, and 58% of rounds rang in the first minute | Pages needed scale with the guests, it rings once, and the hint is a 12 s snapshot. Rollback values are in config |
| PP-07 | Tearing pages leaves no trace | PARTIAL | Shadows could tear pages, but nothing showed it | Torn pages leave scraps and a Tampering lead |
| PP-07 | Clue farming | PARTIAL | Pay per page had no cap | Pay is capped at 10 pages a round |
| PP-08 | Map validation | NOT FOUND | Tests only counted markers and parts | Walk-through test. It found 3 CONFIRMED marker defects, all fixed (section 3) |
| PP-08 | Map modifiers | NOT FOUND | None | Deferred on purpose: the directive says to add one only if it's integrated and tested |
| PP-08 | Firing corridors, escape loops, route lengths | UNVERIFIED | No tooling existed | Deferred (section 7) |
| PP-09 | Recap, MVP, mastery | NOT FOUND | The results card showed the winner, who was who and the pay | Decisive-moment line, party star, and 11 mastery goals across five roles |
| PP-09 | Roles shown before the end | NOT FOUND | The reveal list goes out only in the Results message | No change needed |
| PP-10 | Trade crash gap | CONFIRMED | `docs/design.md` itself named it: two saves, one after the other | Two-phase journal with recovery on load, tested by crashing after every step. Documented as not truly atomic |
| PP-10 | Economy pace | UNVERIFIED | Only an estimate is possible (section 5) | No change. Prices are an owner call |
| PP-11 | Captions and reduce motion | NOT FOUND | No such settings | Both added and saved on the server. Captions say which way a sound came from |
| PP-11 | Colourblind-safe indicators | PARTIAL | Role chip and results already used words | Leads and hit markers use words as well as colour |
| PP-11 | Audio | CONFIRMED (owner-dependent) | All 33 sound ids are empty. One-shot sounds fall back to stock Roblox sounds; music and ambience stay silent until uploaded | No change. Needs the owner's upload |
| PP-11 | Mobile button layout | UNVERIFIED | Needs a device | New UI is placed clear of the thumbstick and jump area on touch screens, but nobody has seen it |
| PP-12 | Instrumentation | PARTIAL | First-time funnel plus three unchecked events. A fourth, PassClaimed, was documented but never sent | Whitelisted events with listed values only, capped numbers and a 30-a-minute limit per player |
| PP-12 | Remote validation, rate limits, DataStore failure | PARTIAL | Type checks, cooldowns and a rate limiter on every remote were already there | The journal covers an unreachable trade store. Studio falls back to an in-memory journal with a warning |
| PP-12 | Runtime performance | UNVERIFIED | Lune can't measure it | Part and light budgets are still enforced. New effects reuse the existing range filter |
| Extra | Cosmetic identity tell | CONFIRMED (risk) | The knockout burst uses the attacker's equipped effect, and some effects are paid. A witness who knows who owns an effect can name the tagger | **Not changed**: changing it would alter a paid item. Owner decision (section 8) |

## 2. Commits

| Commit | What |
| --- | --- |
| `f69e871` | One round-end rule, line of sight for tags and shots, private effects, whisper guard, hit feedback, draw warning, controller bindings |
| `779e78f` | Leads, notebook, paced Truth Bell, fairer role deal, models and `tools/simulate` |
| `ffe98c2` | Crash-safe trades through a two-phase journal; save version 2 |
| `76b1896` | First-time tips, mid-round join card, plaza wisp hunt, saved settings |
| `2070524` | Round recap, party star, mastery goals, cleaned analytics, captions, reduce motion |
| `68b3209` | Map walk-through test and the three markers it caught |
| this commit | Docs: this report, `docs/design.md`, `README.md` |

## 3. Changed files (all under `games/phantom-party/`)

**New:**

- **client:** `src/client/Captions.luau`, `Leads.luau`, `Tips.luau`
- **server:** `src/server/Lib/TradeJournal.luau`, `src/server/Services/EvidenceService.luau`, `WispService.luau`
- **shared config:** `src/shared/Config/Captions.luau`, `Evidence.luau`, `Mastery.luau`, `Telemetry.luau`, `Tips.luau`
- **shared rules:** `src/shared/Rules/Bell.luau`, `Evidence.luau`, `Mastery.luau`, `Recap.luau`, `Telemetry.luau`, `Tips.luau`, `Wisps.luau`
- **tests:** `tests/Accessibility.spec.luau`, `Evidence.spec.luau`, `Fairness.spec.luau`, `MapCheck.luau`, `Maps.spec.luau`, `Models.luau`, `Onboarding.spec.luau`, `Recap.spec.luau`, `Sims.spec.luau`, `Telemetry.spec.luau`, `Trades.spec.luau`
- **tools and docs:** `tools/simulate.luau`, `docs/AUTONOMOUS_UPGRADE_REPORT.md`

**Changed:**

- **client:** `src/client/Controls.luau`, `Corner.luau`, `Crates.luau`, `Effects.luau`, `Emotes.luau`, `Hud.luau`, `Motion.luau`, `RoleCard.luau`, `Settings.luau`, `Sounds.luau`, `Spectate.luau`, `State.luau`, `TradePanel.luau`, `Ui.luau`, `init.client.luau`
- **server:** `src/server/Lib/Match.luau`, `Migrations.luau`; `src/server/Services/AnalyticsService.luau`, `ChatService.luau`, `CombatService.luau`, `DataService.luau`, `LobbyService.luau`, `PickupService.luau`, `ProfileService.luau`, `RoundService.luau`, `TradeService.luau`; `src/server/init.server.luau`
- **shared config:** `src/shared/Config/Combat.luau`, `Rewards.luau`
- **shared look:** `src/shared/Look/Lobby.luau`, `Maps/Carnival.luau`, `Maps/Manor.luau`
- **shared rules:** `src/shared/Rules/Combat.luau`, `Deal.luau`, `Progress.luau`, `Round.luau`, `Trade.luau`
- **tests:** `tests/Rules.spec.luau`, `Saves.spec.luau`, `run.luau`
- **docs:** `docs/design.md`, `README.md`

**Map fixes the walk-through found:**

- **Manor coin:** it sat inside the fountain rim, at (-6, -40). It moved to (-6, -46).
- **Carnival big-top coin:** it sat inside the king pole. It moved 1.5 studs onto the pedestal.
- **Carnival clue page:** it floated 7 studs over the big top's doorway, where the bleachers stop. It moved onto the middle bleacher row, away from the doors.

## 4. Commands and results

All commands were run from `games/phantom-party` with the CI tool versions: StyLua 2.6.0 (Luau), Selene 0.31.0, Lune 0.11.1 and Rojo 7.7.1.

| Command | Result |
| --- | --- |
| `stylua --check src tests tools` | clean |
| `selene src` | 0 errors, 0 warnings, 0 parse errors |
| `lune run tests/run` | **183 passed, 0 failed** (73 before this pass) |
| `rojo build -o phantom-party.rbxl` | builds |
| `lune run tools/simulate` | the tables below |

**Role deal over 10,000 modelled rounds.** Share per player runs from lowest to highest.

| Players | Phantom share | Fair | Longest Phantom wait |
| --- | --- | --- | --- |
| 2 | 50% to 50% | 50% | 5 rounds |
| 4 | 24% to 26% | 25% | 9 rounds |
| 8 | 12% to 13% | 13% | 22 rounds |
| 12 | 8% to 9% | 8% | 30 rounds (88 with the old weighting) |

Guardian, Medic and Saboteur shares are equally even (full table: `lune run tools/simulate`).

**Truth Bell over 3,000 modelled rounds.**

| Players | Pages to fill | Rang at all | Rang in first minute | Rings a round | Median first ring | Old: first minute | Old: rings a round |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | 9 | 79% | 0% | 0.79 | 133 s | 0% | 0.66 |
| 5 | 11 | 100% | 3% | 1.00 | 93 s | 9% | 1.59 |
| 8 | 13 | 100% | 0% | 1.00 | 95 s | 20% | 1.91 |
| 12 | 16 | 100% | 0% | 1.00 | 94 s | 58% | 2.77 |

## 5. Verified versus inferred

**Verified by tests (logic only, not feel):**

- Every round-end outcome agrees with an independent referee.
- Walls block swings, shot origins and throw views.
- No effect line sends a role or user id.
- Every chat channel is guarded.
- Leads expire, are capped and never name anyone.
- A glimpse is right at the configured rate whatever the party size.
- The bell's pacing and its rollback values behave as described.
- Trades end all-or-nothing after a crash at any step, with any mix of autosaves, and stay idempotent.
- The v1 to v2 save migration keeps coins, XP, items, outfit, pass and stats.
- Tips never repeat and never take input.
- Wisps pay nothing.
- Recap lines exist for every reason.
- The party star never picks a Shadow or a stand-in.
- Mastery goals need a win, a catch or a revive, and pay nothing.
- Telemetry sends only listed events and values, within the per-player limit.
- Captions are only for real sounds, and every sound played in the world has one.
- Every UI bounce goes through the Reduce motion switch.
- Every spawn, page, coin and passage end on both maps is clear, on a floor and reachable.

**Inferred (models and estimates, not measurements):**

- **Bell pacing.** It assumes a guest alone finds a page in about 70 s, with more guests finding pages faster. It leaves out tearing and tagged guests, both of which flatter the guests.
- **Economy pace.** A typical guest round pays about 25 to 35 coins and 60 to 70 XP. That puts the first 300-coin boutique item at about 10 rounds (about 40 minutes at 3.6 minutes a round), a 600-coin crate at about 20, and the full 30-tier pass (7,500 XP) at about 110 rounds. That is more than the "about 70" `docs/design.md` quotes, which assumes winning more often.
- **The map walk-through** treats wedges as full boxes, doesn't climb ladders, and allows a 4-stud step or jump.

**Not verified at all:**

- How anything looks, sounds or feels.
- Phone layout and frame rate.
- DataStore behaviour on live servers.
- Analytics arriving in the Creator Dashboard.
- Whether leads make deduction fun or just add noise.

## 6. Flags, defaults and rollback

| Flag | Default | Rollback |
| --- | --- | --- |
| `Config/Combat.LineOfSight` | true | false: hits ignore walls, as before |
| `Config/Evidence.Enabled` (plus `.Footprints.Enabled`, `.Blackout.Enabled`) | true | false: no leads; the notebook stays empty |
| `Config/Rewards.Bell` | Base 8, PerGuest 0.75, Min 8, Max 18, TrackRoom false, MaxRings 1 | Base 10, PerGuest 0, Min 10, Max 10, TrackRoom true, MaxRings math.huge (tested) |
| `Rules/Deal.WEIGHT_POWER`, `MAX_TICKETS` | 2, 20 | 1, 10 |
| `Config/Mastery.Enabled` | true | false: nothing recorded or shown; saved counts kept |
| `Config/Telemetry.Enabled` (or `Off` per event) | true | false: funnel steps only |
| `Rewards.ClueCap` | 10 | a large number |
| Trade journal | always on | Not a flag. Reverting `ffe98c2` brings back sequential saves; save version 2 stays readable because the migration only adds fields |

Save version 2 is forward-only: a version 1 server would refuse a version 2 save (`FutureVersion`) rather than overwrite it. Don't run an older build against the same DataStore once this one is live.

## 7. Deferred, with reasons

- **Map gameplay modifiers** (rotating carnival paths, timed manor passages). The directive says not to add one unless it's integrated and tested, and each needs a feel check first.
- **Rules specific to 3 or 4 players.** There's only an honest "Small" label so far. A real low-population ruleset needs a design call and play.
- **Stand-in cover for small rounds.** Rejected: practice dummies look different from players, so they'd make deduction worse, not better.
- **Firing corridors, escape loops and route-length metrics.** `tests/MapCheck` is the base for them.
- **Role ticket progression on the results card.** It shows something like "your Phantom chance went up"; wording it without hinting at the deal is a design call.
- **The masquerade identity pass.** Silhouettes, iconography and stingers need art direction.
- **P2 items:** disguise affordance, rotating events, party queue, a third map.
- **Inventory search and a duplicate-handling audit (PP-10).**

## 8. Next-day review, in priority order

1. **Multi-client Studio session** (Test > Clients and Servers, 3 or more players). Check:
   - round-end reasons on the results card;
   - whether line of sight blocks fair tags at doorways and corners;
   - how many leads arrive and whether they help;
   - bell timing;
   - tips timing;
   - the results card with a party star on a phone-sized window.
2. **Owner decision: the knockout-effect tell.** Options:
   - show a neutral burst during the round and the owned effect only on the results card or in the plaza; or
   - keep it and say so in the item text.

   This touches a paid item, so it was left alone.
3. **Bell tuning after real rounds.** The model says it rings once in nearly every round at 4 or more players, about 90 s in. If that feels like a guaranteed reveal, raise `Rewards.Bell.Base` or `PerGuest`.
4. **Trade journal with real DataStores.** Turn on Enable Studio Access to API Services, trade, and stop the server mid-settle. Both players should rejoin with the same, consistent result.
5. **Economy pace (owner call).** About 40 minutes to the first boutique item, and the pass takes longer than the docs say.
6. **Phone layout.** Check the captions strip, tips banner, leads pill and hit marker against the thumbstick, jump button and chat.
7. **After publishing,** confirm the custom events appear in the Creator Dashboard.

## 9. What still needs the owner

- **Audio.** Upload the 33 sounds in `assets/audio` and paste their ids into `Config/Sounds.luau`. One-shot sounds use stock fallbacks until then; music and ambience are silent.
- **Game pass ids.** They're still 0. They get created with the Open Cloud key that was already asked for in this thread.
- **Store icon and thumbnails** (`docs/marketing.md` has the prompts).
- **Studio play-through and publishing.** Nothing in this pass needed or attempted either.
