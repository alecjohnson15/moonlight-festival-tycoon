# Play-testing Catwalk Clash

CI proves the code builds, the rules add up and every piece and the map
build without errors. It can't tell whether a show is fun, readable or
smooth, and it never runs the server services or client scripts. This is
the script for the play-tests that do. Run it on every build that changes a
round, the wardrobe or the show, and keep the results table at the end.

## Setting up

1. Open `catwalk-clash.rbxl` in Studio (or `rojo serve` and connect).
2. Solo: press **Play**. Rivals fill the bracket, so a whole show runs.
3. Voting: **Test > Clients and Servers**, 3 players. Two walk, one votes.
   Studio's test players count as different accounts but not as friends,
   so every vote counts in full.
4. Saves: turn on **Security > Enable Studio Access to API Services** to
   test that outfits, Sparkles and Style Score come back after rejoining.
5. Paid items: in Studio every pass counts as owned. To see what a free
   player sees, test the published game with an account that owns nothing.
6. To make rounds quicker while testing, lower `Dressing` in
   `src/shared/Config/Game.luau` (put it back to 150 before committing).

## What to watch

Use a tester who hasn't played the game. Don't explain anything; note where
they hesitate and what they say. Time each step from when they spawn.

| Step | Target | What to note |
| --- | --- | --- |
| Understand what's happening | under 30 seconds | Did the round pill, the tip card and the screens tell them a show is coming? |
| Vote for a theme | most testers vote in their first lobby | Did they see the three cards and the ★ spotlight? |
| First satisfying action | under 60 seconds into dressing | Usually putting on a piece and seeing it on their avatar on the turntable. Did the equip sound and the "✓ theme" badges help? |
| Dress for the theme unaided | 8 of 10 testers | Did they find the theme badges? Did they try the Catalog tab? Did anyone run out of time? |
| Walk the runway | everyone who dressed | Did their character walk and pose by itself? Did they understand their entrance effect? |
| Vote in a matchup | 8 of 10 testers | Did the pink and aqua buttons make sense? Did they wait for the outfits before voting? |
| Understand a result | 8 of 10 testers | Did the split, the judges' card and the line saying how it was decided read clearly? |
| Want another round | most testers stay for a second show | What did they say they'd do differently? |
| Idle time | no stretch over 20 seconds without a reason | Write down every one and what the tester was waiting for. |

Ask at the end: what was the most fun, what was confusing, and what would
you buy if you could?

## Checks for every build

- [ ] A full show runs solo with rivals, from the lobby back to the lobby.
- [ ] With 3 players: walkers can't see vote buttons in their own matchup;
      votes before the outfits have been on show are ignored; the split
      stays hidden until votes close.
- [ ] A walker who leaves mid-matchup loses by walkover, and the show goes
      on.
- [ ] Wardrobe: every slot opens; colours and finishes change the piece;
      painted top and bottom styles change the body; Reset and Save work.
- [ ] Catalog tab: a search returns items; trying one on shows it on the
      avatar and on the runway; Buy opens Roblox's prompt (cancel it).
- [ ] Closet: save, rename, wear, replace and delete an outfit; it's still
      there after rejoining.
- [ ] Style Pass: tiers fill with XP; Claim works on reached tiers; the
      premium track asks for the pass.
- [ ] Shop: Sparkles items buy and equip; Robux items show their price, or
      Coming soon until the pass ids are in.
- [ ] VIP Lounge: the door lets VIPs up and prompts everyone else.
- [ ] Settings: music, effects and Watch only each do what they say.
- [ ] Phone: the wardrobe fits a phone screen and every button is tappable
      (Studio's **Device** emulator, then a real phone).
- [ ] Performance: 30 FPS or better on a mid-range phone with 12 players
      dressed in glowing pieces.

## Results

| Date | Build | Testers | What we found | Fixed in |
| --- | --- | --- | --- | --- |
| | | | | |
