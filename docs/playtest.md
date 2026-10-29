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
2. For sound, check every sound in the theme has an id (README, step 6).
   Each file's name is its sound's name in snake case: `parade_march.ogg`
   is `ParadeMarch`, `reveal_stall.ogg` is `RevealStall`. If a sound is
   silent in Studio, check the output for an asset permission error. Without
   the ids, claiming, buying, a pad you can't afford,
   weapon swings, Ghost Catcher, the parade and the reaper play plain Roblox
   sounds, every building's reveal plays the same build sound, every place
   keeps one ambience, and there is no music.
3. Clear your save before a first-time run: in Studio's command bar, with
   API access on, remove the key `player_<your user id>` from the
   `PlayerSaves` DataStore, or test with a fresh account on a published copy.
4. To see a parade sooner, set `FirstSeconds` in `src/shared/Config/Parade.luau`
   to 20 for the session (put it back to 150 before committing). Otherwise
   the first parade starts two and a half minutes after the server does.

## What to watch

Use a tester who hasn't played the game. Don't explain anything; note where
they hesitate and what they say. Time each step from when they spawn.

| Step | Target | What to note |
| --- | --- | --- |
| Find and claim a plot | under 30 seconds (median) | Did they see the wheel, the arrows and the gold beacons? Did they read the goal line? |
| First satisfying action | under 60 seconds | Usually the free stall, then the first "+N / sec". Did the build-up, the flash and the stall's own sting feel good? |
| Find the next purchase unaided | 8 of 10 testers | Did the goal line and beam lead them? Did anyone step on a pad they couldn't afford, and did the note make sense? |
| Understand a path choice | 8 of 10 testers | At the stall's three paths (about 620 coins): did the card's "visitors" line and the hologram (shown fully upgraded) make the trade clear? Did anyone pick by accident? |
| Find Ghost Catcher | most testers within 5 minutes | Did the guide's nudge bring them? Did they get the rules from the first round? Did they go back for another? |
| Join the Moonlight Parade | most testers join the first one they're on the server for | Did they notice the 30 second warning and follow the beam to the Wheel? Did they understand catching lanterns and the shared meter? |
| Make the plot theirs | most testers open the Festival board within 10 minutes | Did they find the board beside Ghost Catcher's booth or the Festival button? Did they rename the festival, change colours or place a decoration? |
| Idle time | no stretch over 30 seconds without a reason | Write down every one and what the tester was waiting for or looking for. |

Ask at the end: what were you trying to do next, what was the most fun, and
what was confusing?

## New in review steps 4 to 6

Check each of these once per build that touches it, on your own before a
tester round.

- **Festival board:** the board at the back of your plot, beside Ghost
  Catcher's booth (prompt "Decorate"), and the Festival button open the same
  panel. Shuffle the name, pick a palette and
  place a decoration; everyone on the server should see the change on your
  plot and the name sign. Locked choices say what unlocks them, and a new
  unlock shows a note.
- **Moonlight Parade:** a warning 30 seconds ahead, then three floats and
  marchers circle the Wheel for a minute, letting go of lanterns. Running
  through one catches it ("+N" over it and a twinkle), the meter at the top
  fills for the whole server, a full meter brings confetti and a cheer, and
  the result card says how many you caught and what you earned. The sign by
  the Wheel counts down to the next one. With two or more players, check
  that a lantern only one of you caught counts once.
- **Path looks:** buy each path's steps on one plot. Every step should change
  how the building looks (for example the Creepy Café's tables, the Scream
  Maze's pop-up scares, the Moon Beacon's beam, the Midnight Express's extra
  cars and the Ghost Parade's marching ghosts), with only the new parts
  animating in. The path card's second line says what visitors will do.
  The hologram on a path's first pad shows the path fully upgraded.
- **Visitors:** they queue at the attractions in a short line, sit, jump or
  cheer at the stops a path adds, and walk away carrying what they bought
  (candy floss, toffee apples and so on). None should walk through a wall.
- **Reveals:** each building has its own sting when it or anything for it is
  built, with a quick flash of light where it appears.
- **Sound by place:** walk from the plots to the bonfire, into the graveyard,
  then to the arena. The crowd and fairground organ on the plaza and plots
  should fade to the plain night wind at the bonfire, to a low choir among
  the graves and to drums at the arena, each over about two seconds. The
  music button turns the ambience off too. Near a ghost train you should
  hear it chuffing, with a whistle now and then.
- **Woods trail:** a "Moonlit Trail" sign beside the way to the bonfire leads
  along a lantern-lit path past the graveyard into the woods. At the end, a
  reaper statue turns its head to follow you and whispers once. It should be
  eerie, not frightening (Mild): nothing chases, jumps out or flashes. Check
  you can't get stuck on anything along the trail.
- **Title signs:** the sign on the Wheel's front legs, and the one over the
  gateway to the bonfire on the side you see walking back, read "Halloween
  Tycoon" with "Your Dream Festival" under it. Both lines of the Wheel's
  sign should be readable from the spawn, on a phone too.

## Performance and devices

- **Frame rate:** at least 30 FPS on a mid-range phone, with six plots built
  and visitors walking, and again in the courtyard during a parade. Use
  Studio's device emulator for layout, and a real phone (published test
  place) for frame rate: open the Developer Console (F9) and watch the
  Performance stats, or `Shift+F5` for the frame time.
- **Phone pass:** on a small phone, the goal line, notes, path card, Ghost
  Catcher panel, parade meter and result card, Festival panel and wardrobe
  button must not overlap each other or the thumbstick and jump button, and
  every button must be big enough to tap. Catch a parade lantern using only
  the thumbstick.
- **Fog and lighting:** at the lowest graphics level on a phone, the plaza,
  the trail and the graveyard should still be readable at night. If they're
  too dark or the fog hides the next goal, raise `Lighting.ExposureCompensation`
  or lower `Atmosphere.Density` in `Look` in the theme
  (`src/shared/Themes/MoonlightFestival/init.luau`) and note the values that
  worked.
- **Six players:** in Studio, Test > Clients and Servers with 6 players. Check
  every player can claim, buy, play Ghost Catcher at the same time, catch
  parade lanterns together and fight in the arena, and that the server frame
  rate holds.

## Saves

Leave and rejoin (or stop and start the test server) and check that coins,
everything bought, the chosen paths, cosmetics and what's equipped, arena KOs,
Ghost Catcher's best round, the festival's name, palette and decorations, and
the number of parades joined are all kept. Rejoin within a minute of leaving
too, to check the session lock hands the save over.

## Analytics

The game reports to the Creator Dashboard (Analytics) from a published
place; Studio play-tests don't count. Each player passes through the
onboarding funnel once: Joined, Spawned, Reached a gate, Claimed a plot,
Built the stall, Earned coins, Bought an upgrade, Built an attraction and
Picked a path. Custom events count Ghost Catcher rounds, paths picked (by
building and path), parades joined and returning sessions. After a round of
testing on a published copy, check the funnel shows each step for every
tester, and compare its drop-offs with your notes. Retention (players coming
back the next day) shows there once the game has live players.

## Results

Copy this table for each round of testing.

| Date | Build (commit) | Testers | Claim median | First action | Found next buy | Understood paths | Played Ghost Catcher | Joined a parade | Used the Festival board | Idle stretches | Phone FPS | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | | | | |
