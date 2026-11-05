# Catwalk Clash: design

**Dress up. Strut. Win the crown.** A fashion competition for Roblox
players aged 9 to 12. Every few minutes the lobby picks a theme, everyone
dresses up against the clock, and then the show starts: walkers go down the
runway two at a time, the audience votes, and the winner of the bracket is
crowned.

It's built on the loop that dress-up competitions on Roblox have proven
(a theme, a timer, a runway, a vote) and set out to be twice as good at the
parts players complain about: votes decided by friend groups, rounds where
half the room is idle, nothing to keep between rounds, and looks limited to
whatever the game happens to stock.

## A round

| Phase | Time | What happens |
| --- | --- | --- |
| Lobby | 22 s | Players hang out in Glow Plaza. The last 15 s is the theme vote: three cards, one of them the week's spotlight theme (pays double, marked ★). |
| Reveal | 5 s | The winning theme lands on the big screens with a fanfare. |
| Dressing | 150 s | Each contestant gets their own booth backstage and the Wardrobe opens. **Theme look** builds a starting outfit for the theme from what you own, **Undo** and **Redo** step back through your changes, and a first-show guide shows the three steps. Pressing **Ready** when everyone's done cuts it to 8 s. Late joiners can still enter with 40 s left. |
| Showtime | 7 s, then about 17 s a matchup | Every contestant first poses on stage together for the lineup, so the whole room sees every look before anyone is knocked out. Then a head-to-head bracket: both walkers stride down their own lane at once with their entrance effect, strike their pose, and the audience votes ◀ left or right ▶ (pink or aqua). The judges add their votes, the split is revealed with a short note from the judges, and the winner moves on. Players who join mid-show see the bracket and the current matchup straight away. |
| Crowning | 14 s | The champion takes the podium with a crown, fireworks and confetti, and becomes the Hall of Fame statue in the plaza until the next show. |

A whole round runs 4 to 7 minutes. With fewer than four players, rivals
(ten original characters with their own taste and skill) fill the bracket,
so a show always happens, even solo.

## What makes it "2x better"

**Head-to-head brackets with live audience voting.** Instead of rating
everyone 1 to 5 stars at once, two walkers face off at a time. Matchups are
short, there's always a clear winner, and everyone who isn't walking is
voting, so nobody waits with nothing to do. The bracket is drawn at random
each show, so byes (when the numbers aren't a power of two) land by luck
rather than going to the highest Style Scores. A simulation in
`tests/Tournament.spec.luau` showed why: seeding by score gave the top score
a bye every time and the lowest never, which cut the lowest score's chance
of the crown with five walkers from about 20% to 14%. `Game.Show.Seeding =
"Rating"` brings the old seeding back.

**Server-side voting that resists brigading.** The server decides
everything; a client can only say "pink" or "aqua".

- Walkers can't vote in their own matchup.
- Votes only count once both outfits have been on show for 2.5 s, and close
  2 s after the pose, so nobody votes blind or late.
- One vote per account per matchup (the last tap counts), rate limited.
- A vote is "suspect" when the voter is a Roblox friend of the walker they
  voted for, or their account is under 7 days old. The first two suspect
  votes for each walker count fully; every suspect vote after that counts
  half. So a friend cheering on a friend is normal and counts, but a big
  friend group or a batch of fresh accounts can't decide a matchup alone.
  Voting against a friend is never suspect. The Profile window explains
  this in plain words, and the vote counts players see are plain counts,
  never weights. `Game.Voting.Mode = "Flat"` brings back the old rule (every
  friend of either walker and every new account at half). It is a limit,
  not a guarantee: no rule makes a vote perfectly fair.
- The running split is hidden until votes close, so nobody follows the
  crowd.
- Three judges (Madame Velour, DJ Pixel and Nana Stitch) score how well each
  look fits the theme. They are fixed rules, not AI: they read the pieces'
  tags, catalog item names and colours. After each matchup they give each
  walker a star rating for the theme and up to two compliments (such as
  "Colour match" or "Head-to-toe look"), never the exact formula. Their votes decide quiet servers and fade as the
  audience grows (3 votes each, minus 0.25 per audience vote, never below
  0.5). Ties go to the judges' scores, then Style Score, then a coin.

**A persistent wardrobe and a Style Score profile.** 152 original pieces
over ten slots, all built in code, each in any of 36 palette colours and eight
finishes (matte, satin, shiny, sequin, glow, metal, glass and frost). The painted clothes (tee, long sleeves,
tank or suit; pants, shorts or briefs; shoes and gloves) go on the avatar
itself. Up to four outfits save to the closet (24 with Big Closet). The
Style Score is an Elo rating: beating a stronger walker earns more, and
matches against rivals count half. Your first 10 walks can only raise it,
so a new player isn't knocked down a rank by their first losses. It sets
your rank (Newcomer to Legend) on your name tag and puts you on the world
leaderboard.

**The whole Roblox catalog.** The Catalog tab searches Roblox's real
avatar shop (hats, hair, faces, tops, jackets, dresses, shoes and more,
including layered clothing), and anything can be tried on for free and
worn on the runway. Judges match catalog item names against the theme's
words. Items can be favourited and bought with Roblox's own prompt.

**Runway effects and cosmetics.** 15 entrances (spotlight, sparkle trail,
confetti, petal shower, bubbles, paparazzi flashes, fireworks, starfall,
thunder, a golden carpet and more) and 14 poses, all original. The camera
cuts from the wide runway shot to a close-up for the poses and then the
podium, like a broadcast (or switch to Free look), and the crowd of fans
along the runway hop and wave glowsticks. **Reduced motion** in Settings
turns off the camera flashes and makes the camera cut instead of swoop.

**A season pass.** Season 1, "Glow Up", runs from 1 November 2026 to
1 February 2027: 30 tiers of XP earned by playing, with a free reward on
every tier and a premium reward for Style Pass owners. Every reward is on
the board before anyone buys. Tiers can't be bought or skipped.

**UGC creator revenue sharing.** When a player buys a catalog item they
tried on, the sale goes through Roblox's own prompt: the item's creator is
paid as usual, and Roblox pays this game its commission for the sale. The
game never sells catalog items as its own and never hides that they're
real Robux purchases.

**A steady theme drip.** 69 themes, 10 of them seasonal (Halloween,
winter, Valentine's, spring and summer) that appear by themselves inside
their date windows. The weekly spotlight theme rotates every Monday, and
recent themes rest for 8 rounds so shows don't repeat.

**Things to come back for.** Three daily challenges (the same for everyone
that day, so friends chase them together), a login streak that grows for
seven days, Sparkles for walking, winning, voting and "good taste" (voting
with the crowd's pick), and the Hall of Fame statue.

## Fair play and money

- Paid pieces are tagged like free ones, so money can't buy points.
  `docs/theme-coverage.md` lists, for every theme, how many slots free and
  earned pieces can fill and the best score each reaches. A test
  (`tests/Judge.spec.luau`) checks that for every theme, a brand-new player
  with only free pieces can reach the judges' "nailed it" score, and that
  pieces bought with Robux never score higher than pieces bought with
  Sparkles earned by playing.
- No loot boxes, no random rewards for Robux, no rerolls, no timers, no vote
  boosts. Every pass and pack says exactly what it gives.
- The money comes from four places: game passes (collections, VIP, Color
  Studio, Big Closet, poses, entrances), the Style Pass each season,
  Sparkles packs (fixed amounts), and the commission on catalog sales. The
  strategy target is about $9 per player over their lifetime; the Creator
  Dashboard's revenue per paying user and conversion show how close it gets,
  and the prices in `Config/Catalog.luau` are starting points to tune.

## Safety

- Aimed at Roblox's **Mild** label for ages 9 to 12, and in practice it has
  nothing above Minimal: no violence, no fear, no romance.
- No child personal data. The save holds game progress keyed by Roblox user
  id, nothing else. Analytics are Roblox's own, with no names or free text.
- Nobody types anything other players see: outfit names come from word
  lists, and the only text box (catalog search) goes to Roblox's search and
  is never shown to others.

## Where things are

```
src/
  shared/                   ReplicatedStorage.Shared
    Config/                 every number and list, tuned without code changes
      Game.luau             round timings, voting weights, rewards, cooldowns
      Themes.luau           69 themes, tags, colours, catalog words, seasons
      Wardrobe.luau         152 pieces: slot, tags, colours, shapes, price
      Poses.luau            14 poses as R15 joint angles
      Entrances.luau        15 runway entrances
      Season.luau           the Style Pass season and its 30 tiers
      Catalog.luau          Robux passes and Sparkles packs
      People.luau           the judges and rivals
      Quests.luau Ranks.luau Palette.luau Words.luau Layout.luau Sounds.luau
    Build/                  the map and the wardrobe pieces, made from parts
    Bracket.luau Voting.luau Judge.luau StyleScore.luau ThemePicker.luau
    Progress.luau Look.luau RivalStyle.luau      pure logic, all tested
  server/                   ServerScriptService.Server
    Services/               rounds, looks, catalog, profile, shop, world,
                            purchases, saves and analytics
  client/                   StarterPlayerScripts.Client
    Wardrobe Show Camera Effects Menus Hud ThemeVote Tips Sounds ...
tests/                      Lune tests: `lune run tests/run`
tools/make_sounds.py        makes the music and sound effects
```
