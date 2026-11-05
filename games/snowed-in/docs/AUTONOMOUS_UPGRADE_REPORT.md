# Snowed In: overnight upgrade report

The overnight pass on `games/snowed-in` asked for by the "top-100 ambition"
directive (P0 first, then P1), on branch `claude/project-thread-wo6c7j`
(PR #14), 2026-11-05.

Nothing in this pass has been played. No Studio session, no device, no
players. Everything below is checked by reading the source, by tests and by
a deterministic model of a run. None of that replaces a play-test, and this
report makes no claim about ranking, retention or fun.

## Commits

| Commit | What |
| --- | --- |
| `685655d` | The gameplay and systems changes (all of `src/`, `default.project.json`) |
| `634e084` | Tests for the new rules, `tools/RunModel.luau`, `tests/Pacing.spec.luau`, the new `tools/simulate_run` |
| `c128dd4` | README, design and launch docs; honest wording on the role passes |
| this one | This report |

## What changed, by directive item

The labels say what reading the source showed before the change:
**CONFIRMED** (the problem was there), **PARTIAL** (part of it was handled),
**NOT FOUND** (already handled, nothing to fix) and **UNVERIFIED** (can't be
told from source).

### P0

| Item | Suspected gap | Label | What the source showed | What was done |
| --- | --- | --- | --- | --- |
| SI-01 | A 52-minute run with no early win | PARTIAL | The run is 51.3 min to the rescue dawn (Cycle and Balance). There were notices, but nothing marked progress before the train | Team milestones with banners and a results line (`shared/Milestones`, `server/Lib/Celebrate`). The guide's first-day goal is now the first hearth upgrade, so the first milestone lands at 1.2 to 2.5 min in the model |
| SI-01 | No pacing simulation for 1/2/4/8 players | PARTIAL | `tools/simulate_run` printed the clock and wave budgets only | `tools/RunModel.luau` plays whole runs second by second. `tests/Pacing.spec` checks it, and `simulate_run` prints it |
| SI-02 | Days without real choices | UNVERIFIED | This is about feel. The model says resources stop being scarce for 4 or more players by about night 5 (fuel is 4 to 7% of what they gather) | Night themes give each day something to prepare for. A deeper sink for big teams is left as next-day work |
| SI-02 | A central expedition board | NOT FOUND | There was no board | Did part of it: the HUD and guide show tonight's theme and tip from the morning before, and the radio goal plus landmark markers when a team is behind. No board in the world yet (deferred) |
| SI-02 | Anti-grief for shared building | CONFIRMED | One player could fill the whole 60-structure cap | Each player gets a share (at least 15). Players can take down their own builds for half the cost back. A leaver's builds can be taken down by anyone. The stockpile is still shared with no veto, on purpose: a veto would hand one player the power the directive warns about |
| SI-03 | Monsters differ only in numbers | PARTIAL | Targeting (fire, players or buildings) and flying already differ | Five night themes, each built round one monster with its own counter tip, planned from a seed. Night 1 is always the gentle crowd, each monster's first night is its own theme, and no theme repeats on consecutive nights |
| SI-03 | No telegraphed waves | NOT FOUND | There was no forecast | Tonight's theme and tip from the morning before |
| SI-03 | Bosses are health sponges | CONFIRMED | They slammed with no warning and had no phases | A wind-up with a red ring where the slam lands, then about 2 s out of breath taking double damage, then roars for help at health marks. The boss bar says what is coming |
| SI-04 | Parts lost when a carrier leaves, falls or freezes | PARTIAL | Freezing, leaving and losing the character already dropped the part. Nothing brought back a part dropped out of reach | `shared/Radio`: one part per carrier and one carrier per part. Drops are kept inside the wall, and a part left loose for 90 s goes back to its landmark. Fitted parts are counted from the parts, so the count can't drift |
| SI-04 | Fitting a part after the run ended | CONFIRMED | A part could be fitted in the Lost phase | Freeing, picking up and fitting need a run in play |
| SI-04 | Train before the requirements | NOT FOUND | Cycle sends the train only with the radio called and the last night reached | Covered by new tests: four parts fitted at once, fitting twice, the last part on night 10, a late call in overtime |
| SI-04 | Rewards paid more than once | PARTIAL | A run paid once per phase change, but nothing stopped a second finish for the same run | The save records the run's id (`LastRunId`), so a run pays once |
| SI-04 | Unfair late-join rewards | CONFIRMED | A player joining in the last minute got the win bonus, the parts and the Rescue trophy. Anyone present at the end got the Yeti trophy | The win bonus needs 3 nights present, parts need one night, and the Yeti trophy goes only to players who saw the fight |
| SI-04 | Hearth out at dawn, last player leaves, save failure | NOT FOUND | The run is lost whenever the flame hits 0 in play. Everyone leaving resets the server. Session locks and receipts were already there | Nothing to change. Leaving mid-run now puts the player's backpack into the stockpile instead of losing it |
| SI-05 | Paid roles help despite "nothing makes a run easier to win" | CONFIRMED | Ranger hits 25% harder (+ Volley); Medic thaws in 1 s and has a cold aura. The claim was in Catalog, README, design and launch docs | The model measures the help (below). The wording is now accurate in all four places. **Prices, entitlements and ratings were not changed** |
| SI-05 | Role stacking, hard role needs | PARTIAL | No role is required by the rules | The model runs eight 4-player mixes: every one wins, and all are within 12% of a mixed free team on the hardest night |

### P1

| Item | Suspected gap | Label | What the source showed | What was done |
| --- | --- | --- | --- | --- |
| SI-06 | One kind of structure dominates; no previews | UNVERIFIED | The build preview and costs exist; layout balance can't be told without play | Build share and refunds (above); the build hint shows "yours n/share" and the take-down key. Layout simulations deferred |
| SI-07 | Freezing isn't legible | CONFIRMED | Warmth showed, time to freeze did not | The HUD shows "freezes in N s" when losing warmth |
| SI-07 | Freeze stun-loops | CONFIRMED | A thawed player could be chilled again at once | 4 s of thaw grace (with a "Just thawed" buff) |
| SI-08 | Four copies of one objective | CONFIRMED | Every landmark was "break the ice, carry it" | Saw the logs (three goes, anyone helps), melt the ice with a fire tool, light the lighthouse with 6 wood, pry the crate with 4 scrap. The guide gives each hint |
| SI-08 | Catch-up | NOT FOUND | No help for teams behind | From night 4, a team behind the "one part every two nights" pace gets the missing parts marked and one guard fewer at each |
| SI-08 | Parts hard to find in a storm | PARTIAL | Landmark markers only came with the Signal Flares upgrade | They also show while a team is behind |
| SI-09 | Weak debrief, no next goal | PARTIAL | The results screen showed team bests only | Milestones reached, what this player did, a late-join note, and their next goal (cheapest locked role, next pass tier, a trophy) |
| SI-09 | Economy unmodelled | NOT FOUND | No model existed | Modelled below. Records, contracts and rotating conditions are deferred (they need design) |
| SI-10 | 0.6x solo scaling may not offset fewer hands | PARTIAL | Only the waves scaled with players | With 1 or 2 players gathering holds are 30% or 15% quicker and the hearth burns at 80% or 90%. The model says a solo player wins at the steady pace either way, and the help cuts the share of gathering that goes on fuel from 21% to 16% |
| SI-11 | No settings for motion and audio | CONFIRMED | There was a music toggle only, and it wasn't saved | Saved settings: music, effects volume (sound groups) and reduce motion (fewer particles, no camera shake), checked by the server |
| SI-11 | Phone HUD and controller | UNVERIFIED | No device to check | Take-down has controller (ButtonY) and touch prompts; phone layout still unverified |
| SI-12 | No performance counters | CONFIRMED | Nothing measured anything | A diagnostics line in Settings: frame rate, ping, monsters drawn, builds, server step time (published each second). No numbers are claimed: nothing has been measured on a device |
| SI-12 | Instrumentation | CONFIRMED | No analytics | Roblox funnels: an onboarding funnel for new players and a funnel through every run, plus RunWon/RunLost events. The only extra field is the role; everything is wrapped in pcall |
| SI-13 | Sound audit | PARTIAL | Tests checked node and weapon sounds and their files | A test now checks that every sound name played anywhere in client code exists. Music and effects have their own sound groups (volume buses). The 45 sounds and 3 songs are unchanged; uploading them is still the owner's step |

## Switches

Every new mechanic can be turned off in `src/shared/Config/Features.luau`
(all on by default). Set one to `false` and rebuild to roll it back. The
tests check the "off" paths for the boss phases, themes and assist.

| Switch | On | Off |
| --- | --- | --- |
| `NightThemes` | Themed, forecast nights | The old random mix |
| `BossPhases` | Wind-up ring, out of breath, roars | Instant slams |
| `LandmarkTrials` | Four different trials | A 4 s "break the ice" everywhere |
| `RadioCatchUp` | Markers and fewer guards when behind | No help |
| `SoloAssist` | Quicker holds, slower burn for 1 to 2 players | Same numbers for all |
| `ThawGrace` | 4 s grace after a thaw | No grace |
| `BuildShare` | Per-player share, take-down refunds | Anyone fills the cap, nothing comes down |
| `Milestones` | Banners and results line | None |

Settings, analytics, diagnostics, the softlock rules, the reward rules and
the late-join rules are fixes, not experiments, so they have no switch.

## What the run model says

`lune run tools/simulate_run` prints all of it. The model plays the game's
real numbers (balance, recipes, weapons, roles, the town layout's actual node
distances, the wave and guard rules), but how players spend their time is a
guess. Each guess is listed and explained in `RunModel.Assumptions`: share
of the day spent gathering, accuracy, fight uptime, expedition overhead, and
so on. Treat the numbers as "do the rules hang together", not as predictions.

**Milestones (minutes, steady pace):**

| | Hearth up | Night 1 | First part | First fit | Old Yeti | One to go | Radio | Rescue |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Design target | 3 | 6 | 13 | 15 | 25 | 33 | 40 | 52 |
| 1 player | 2.5 | 6.0 | 12.2 | 12.9 | 25.6 | 32.8 | 42.9 | 51.3 |
| 4 players | 1.6 | 6.0 | 12.1 | 12.8 | 24.9 | 32.9 | 43.0 | 51.3 |
| 8 players | 1.2 | 6.0 | 12.1 | 12.8 | 24.8 | 32.9 | 43.0 | 51.3 |

The directive asked for something at about 3, 8, 15, 25 and 40 minutes: the
first upgrade (about 2), the first new kind of night (the Hound Pack, forecast
at 6 and arriving at about 9), the first radio part (12 to 13), the Old Yeti
(25) and the radio fixed (43). A team that goes for a part every day
("eager") fixes the radio at about minute 23 for 2 to 8 players (28 solo).
The train still waits for night 10.

**Difficulty:** every modelled team clears every wave. Pressure is the
night's monster health over what the team can deal in a night. Its peak is
0.59 solo, 0.30 for two, 0.20 for four and 0.17 for eight, always on a boss
night. Without the radio, waves keep growing through overtime and the run
ends at night 15 as it should. **Finding:** a team that crafts weapons out-
damages the normal waves by a wide margin from about night 3, so the hearth's
burn, not the monsters, does most of the damage to the fire. If play-tests
find the late nights easy, `Balance.Waves.NightGrowth` is the dial (the model
shows the effect at once).

**Roles (team of 4, hardest night, lower is easier):**

| Mix | vs a free mix |
| --- | --- |
| Scout, Builder, Cook, Ranger | 6% easier |
| Scout, Builder, Cook, Medic | 7% easier |
| Four Rangers | 12% easier |
| Four Scouts / four Builders | 9% harder |
| Four Cooks / four Medics | the same |

The Ranger's own damage is about a third higher than other roles' (25% plus
Ember Volley). The Scout gathers about a third more than any other role. The
model is plain about it: the paid roles help a little and are not needed.
They can be earned with 600 snowflakes, which is 3.1 wins or about 4.5 runs
(about 3.2 hours) at a 50% win rate.

**Snowflakes:** a win with four pays 191 and a loss on night 6 pays 76. At a
50% win rate the pass takes about 8 runs, and the shop's 2,210 snowflakes of
roles and items take about 17.

## Test and build commands and results

From `games/snowed-in`, with the tools in `rokit.toml`:

```
stylua --check src tests tools    # passes
selene src                        # 0 errors, 0 warnings, 0 parse errors
lune run tests/run                # 159 passed, 0 failed (90 before this pass)
rojo build default.project.json -o snowed-in.rbxl   # builds
lune run tools/simulate_run       # prints the model
```

The rebuilt place file is `/mnt/project-files/release/snowed-in.rbxl`.

## Verified and inferred

**Verified by tests:**
- the radio rules (trials, carrying, dropping, sending home, fitting four at
  once, fitting twice, no fitting after a run, reset)
- the train's timing
- catch-up
- boss wind-ups (the slam lands where the ring was, a player who steps out
  isn't hit), out of breath taking double damage, roars once per mark, and
  the instant slam with the switch off
- theme plans (the same seed gives the same plan, the opening, introductions,
  no repeats, exact budgets)
- the codec carrying the new poses
- build shares and refunds
- assist
- reward credit and paying once per run id
- next goal, settings validation and save migration
- funnels and milestones
- the source audit that every sound, milestone and funnel step named in code
  exists
- the model's pacing, difficulty, fairness and economy checks

**Checked by reading only, not run:** the server glue in the services, the
remote handlers, the analytics calls, and every client screen (HUD lines,
guide steps, boss bar, telegraph ring, settings window, diagnostics,
results). Lune has no Roblox events, so none of this ran. A static check
of calls between modules found no call to a function that doesn't exist.

**Inferred (the model's guesses):** every minute and pressure figure above.

## Risks

1. **None of this has been played.** The server glue is the most likely
   place for a runtime error (for example a nil attribute on first join).
   The first Studio run should watch the Output window.
2. **The new screens are unchecked.** The telegraph ring, boss poses,
   settings and diagnostics windows, results layout and HUD lines have not
   been seen on a phone or a PC.
3. **Feel is unknown.** Whether the trials are fun, whether 1.2 s is the
   right wind-up, whether themes read as different nights, whether late
   nights are too easy (the model hints they are).
4. **Analytics is untested.** The AnalyticsService calls have not run
   against Roblox. They are wrapped, so a failure warns but doesn't break
   the game.
5. **Mobile is unchecked.** The longer HUD lines (forecast, freeze
   countdown) use scaled text with a minimum size, but nobody has seen them
   on a small phone.

## Deferred

- A world expedition board at the base (danger, radio progress, team needs).
- Range and coverage previews when placing lanterns, turrets and towers, and
  scripted layout simulations to find dominant chokepoints.
- Persistent expedition records, challenge contracts or rotating
  conditions.
- Something to spend on for big teams late in a run (the model shows them
  maxing the hearth by night 5).
- A first-run accelerated path for brand new solo players.
- Uploading the sounds and making the passes (owner steps, unchanged).

## Next-day review, in order

1. Open the place file in Studio, start a 1-player local server, and watch
   Output for errors through a day, a night and a radio part. Then try a
   3-player local server.
2. Play night 5 and check that the Old Yeti's ring, its out-of-breath window
   and its roars read clearly. Tune `Enemies.Yeti.Windup` and `Tired` if not.
3. Free one part at each landmark and check that each trial's hint is clear.
4. Check the phone layout (Studio device emulator): the HUD lines, the
   settings window and the results screen.
5. Decide whether the late nights need more pressure (`NightGrowth`) after
   a real run.
6. Read the role pass wording in `docs/launch.md` before writing the store
   text.
7. Publish and run a soft launch, then read the Onboarding and Run funnels.
