# Play-testing the first ten minutes

CI proves the code builds, the numbers add up and the models fit. It can't
tell whether the game is fun, readable or smooth, and it never runs the
server services or client scripts. This is the script for the play-tests
that do, with the targets from the project lead review. Run it on every build
that changes the first ten minutes, and keep the results table at the end.

## Setting up

1. Build or serve the place (see Getting started in the README) and open it
   in Studio. With no `Workspace.Plots` folder, the server makes the plots,
   the plaza, the courtyard and the spawn itself.
2. For sound, upload `assets/audio` and paste the ids into the theme (README,
   step 6). Without them, claiming, buying, a pad you can't afford, weapon
   swings and Ghost Catcher play plain Roblox sounds, and there is no music.
3. Clear your save before a first-time run: in Studio's command bar, with
   API access on, remove the key `player_<your user id>` from the
   `PlayerSaves` DataStore, or test with a fresh account on a published copy.

## What to watch

Use a tester who hasn't played the game. Don't explain anything; note where
they hesitate and what they say. Time each step from when they spawn.

| Step | Target | What to note |
| --- | --- | --- |
| Find and claim a plot | under 30 seconds (median) | Did they see the wheel, the arrows and the gold beacons? Did they read the goal line? |
| First satisfying action | under 60 seconds | Usually the free stall, then the first "+N / sec". Did the build-up and the coin pop feel good? |
| Find the next purchase unaided | 8 of 10 testers | Did the goal line and beam lead them? Did anyone step on a pad they couldn't afford, and did the note make sense? |
| Understand a path choice | 8 of 10 testers | At the stall's three paths (about 620 coins): did the first step's preview card and hologram make the trade clear? Did anyone pick by accident? |
| Find Ghost Catcher | most testers within 5 minutes | Did the guide's nudge bring them? Did they get the rules from the first round? Did they go back for another? |
| Idle time | no stretch over 30 seconds without a reason | Write down every one and what the tester was waiting for or looking for. |

Ask at the end: what were you trying to do next, what was the most fun, and
what was confusing?

## Performance and devices

- **Frame rate:** at least 30 FPS on a mid-range phone, with six plots built
  and visitors walking. Use Studio's device emulator for layout, and a real
  phone (published test place) for frame rate: open the Developer Console
  (F9) and watch the Performance stats, or `Shift+F5` for the frame time.
- **Mobile layout:** the goal line, notes, path card, Ghost Catcher panel and
  wardrobe button must not overlap each other or the thumbstick and jump
  button on a small phone.
- **Six players:** in Studio, Test > Clients and Servers with 6 players. Check
  every player can claim, buy, play Ghost Catcher at the same time, and fight
  in the arena, and that the server frame rate holds.

## Saves

Leave and rejoin (or stop and start the test server) and check that coins,
everything bought, the chosen paths, cosmetics and what's equipped, arena KOs
and Ghost Catcher's best round are all kept. Rejoin within a minute of
leaving too, to check the session lock hands the save over.

## Not measured yet

Funnel and retention numbers (how many players claim, reach each purchase,
come back the next day) need analytics events, which the game doesn't send
yet. They're part of the plan for the next review steps.

## Results

Copy this table for each round of testing.

| Date | Build (commit) | Testers | Claim median | First action | Found next buy | Understood paths | Played Ghost Catcher | Idle stretches | Phone FPS | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | |
