# Publishing Catwalk Clash

How to put Catwalk Clash on Roblox, from the place file to a public game.
Do every step on the same Roblox account: Roblox only plays audio in games
its owner may use, so the account that uploads the sounds should publish the
game too.

Roblox changes these screens often. If a button has moved, the
[publishing guide](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
has the current one.

**The quick way.** With an empty experience and an Open Cloud API key,
`publish/publish.ps1` does steps 2, 5 and 6 and most of 3 and 4 in one run
from the linked PC: it uploads the sounds, makes the passes and Sparkles
packs with their icons, puts every id in Config, builds the place, sets the
name, description, 12-player servers and devices, and publishes. Make the
experience and the key as `publish/README.md` says, paste the key, universe
id and place id in the project chat and say "go ahead"; delete the key when
it's done. You still do the genre, the Avatar and Security settings in
step 4, the questionnaire (step 7) and the release (step 8).

## Before you start

- **Can you publish public games?** Check
  [your eligibility page](https://create.roblox.com/settings/eligibility/public-publish).
  Since December 2025 the account needs ID verification, or a real-money or
  gift card purchase made on or after 1 January 2025.
- **Players under 16** (the 9 to 12 year olds the game is for) take more:
  an age-checked account, 2-Step Verification, the publishing fee or two
  months of Roblox Plus or Premium, and then 250 highly engaged, age-checked
  players within 60 days plus a safety review. Every new game opens to
  players aged 16 and up first, so this can wait until after launch. The
  **Audience Reach** page of the Creator Dashboard shows progress.
- **The name:** search Roblox for "Catwalk Clash". If a big game already
  uses it, pick another and change `Name` in `src/shared/Config/Game.luau`.

## 1. Open the place file

Download `catwalk-clash.rbxl` and double-click it, or in Studio choose
**File > Open from File**. It holds the whole game; Rojo isn't needed.

Press **Play** for a quick look. In Studio every paid item counts as owned
so it can be tried on (the live game never does that), and with one player
the bracket is filled with rivals, so a full show runs solo. Set
**Test > Clients and Servers** to 2 or 3 players to try voting.

## 2. Upload the sounds

The 20 sounds in `assets/audio` are original, made by
`tools/make_sounds.py`. In Studio open **Window > Asset Manager**, click
**Bulk Import** and pick all 20 files. Roblox checks each one; once they show
up, right-click each and **Copy Asset ID**.

Paste the ids into the project chat, one per line, like
`music_lobby 1234567890`. Claude puts them into
`src/shared/Config/Sounds.luau` and sends a new place file. Until then the
game uses plain Roblox sounds for clicks and has no music.

## 3. Publish it (still private)

**File > Publish to Roblox**, then **Create new experience**. Fill in:

- **Name:** `Catwalk Clash`
- **Description:** the long description in `docs/marketing.md`.
- **Genre:** Roleplay & Avatar Sim, subgenre Dress Up (or the closest
  match).
- **Creator:** your own account.
- **Devices:** computer, phone and tablet. Leave console off until it's been
  tried with a controller.

Save. The game now exists on Roblox, but only you can play it.

## 4. Experience settings

Open **File > Experience Settings**.

- **Places:** click **⋯** next to the place, **Configure Place**, and set
  the server size (max players) to **12**. There are twelve dressing booths;
  rivals fill the bracket when there are fewer players.
- **Avatar:** check **Avatar type** says **R15**. The place file sets it,
  but look once: the poses, the clothes painting and the catalog try-on all
  need R15 bodies.
- **Security:** turn on **Allow Third Party Sales**. Without it the
  Catalog tab's **Buy** button can't sell other creators' items, and the
  game earns no commission on them. **Enable Studio Access to API Services**
  only matters for testing saves in Studio.
- Leave everything else as it is.

## 5. Game passes and Sparkles packs

Creator Dashboard, the game, **Monetization > Passes > Create pass**, once
for each pass below. Type the name and description, **Create pass**, open
it, turn on **Item for Sale** on its **Sales** page and set the price. Then
click **⋯** on the pass and **Copy Asset ID**.

Then **Monetization > Developer Products > Create**, once for each Sparkles
pack, and copy each product id.

Prices are the suggested starting points from `Config/Catalog.luau`. Change
them if you like, but keep the descriptions exact: they state everything the
item gives.

| Id | Kind | Name | Description | Robux |
| --- | --- | --- | --- | --- |
| `style_pass_s1` | Pass | Style Pass: Season 1 | The Style Pass premium track for Season 1: 30 extra rewards, including the Legend Crown, Runway Wings, Spotlight Gown, Golden Hour aura and Sparkles. Every reward is listed on the pass board before you buy. | 399 |
| `vip` | Pass | VIP | A gold VIP name tag, the rooftop VIP Lounge, and the Golden Carpet runway entrance. | 249 |
| `royal_gala` | Pass | Royal Gala Collection | 6 royal pieces: Royal Ringlets, Frost Crown, Gala Bodice, Velvet Train, Gala Gown and Crystal Slippers. | 199 |
| `neon_night` | Pass | Neon Night Collection | 8 glowing pieces: Light-Up Cap, Pulse Collar, Glowline Jacket, Laser Wings, LED Skirt, Light-Up Kicks, Rave Glowsticks and Neon Haze aura. | 199 |
| `fairy_garden` | Pass | Fairy Garden Collection | 5 fairy pieces: Blossom Halo, Petal Top, Blossom Wings, Petal Skirt and Firefly Jar. | 199 |
| `star_couture` | Pass | Star Couture Collection | 5 space pieces: Orbit Crown, Nebula Armor, Comet Cape, Galaxy Skirt and Moon Scepter. | 199 |
| `color_studio` | Pass | Color Studio | Paint any piece any colour with the full colour picker, not just the 36 palette colours. | 149 |
| `showstopper_entrances` | Pass | Showstopper Entrances | 5 extra runway entrances: Fireworks, Starfall, Rainbow Road, Thunder Strut and Neon Pulse. | 149 |
| `supermodel_poses` | Pass | Supermodel Poses | 6 extra runway poses: Superstar, Heart Hands, Hair Flip, Victory, Shy Wave and Power Lean. | 99 |
| `big_closet` | Pass | Big Closet | Save 24 outfits instead of 4. | 99 |
| `sparkles_small` | Product | Pouch of Sparkles | 500 Sparkles to spend on wardrobe pieces, poses and entrances. | 49 |
| `sparkles_medium` | Product | Jar of Sparkles | 1,500 Sparkles to spend on wardrobe pieces, poses and entrances. | 129 |
| `sparkles_large` | Product | Chest of Sparkles | 4,000 Sparkles to spend on wardrobe pieces, poses and entrances. | 299 |

Pass icons: one 512x512 picture for each pass and pack is in
`assets/marketing/passes/`, named by its Id (`vip.png` and so on). Each
shows what the item gives: the collections are worn by a blocky figure,
rendered from the game's own pieces. Roblox crops them to a circle; the
picture stays inside the ring.

Paste the ids into the project chat, one per line, like `vip 1234567890`.
Claude puts them into `PassId` and `ProductId` in
`src/shared/Config/Catalog.luau` and sends a new place file. Until then paid
items show **Coming soon** and can't be bought; everything else works.

## 6. Publish the new file over the old one

Open the new place file, choose **File > Publish to Roblox As**, pick
Catwalk Clash, then its place, and **Overwrite**. Do the same for every
later update. Running servers keep the old version until they close; to move
everyone at once, use **Restart servers** in the game's menu on the Creator
Dashboard.

## 7. The content rating questionnaire

Creator Dashboard, the game, **Publish settings > Content rating** (the
Maturity & Compliance Questionnaire). Answer as below, check the preview and
**Submit**. It should come out **Mild**, open to every age.

| Question | Answer | Why |
| --- | --- | --- |
| Age-restricted content | No | |
| Violence | None | Nobody fights; the only contest is votes on outfits |
| Blood | None | |
| Fear | None | Around Halloween some themes are spooky dress-up (witch hats, bat wings) in a bright hall; nothing scary happens |
| Crude humour | None | |
| Romance | None | The Air Kiss pose is a blown kiss to the audience, like a Roblox emote, and Hearts and Roses is a friendship-day theme. Nothing happens between characters |
| Alcohol, drugs, tobacco, strong language, gambling, sensitive issues | None | |
| Social hangout | No | Every round is a structured contest |
| Free-form user creation | No | Outfits are built from fixed pieces and colours; outfit names come from word lists; nobody types or draws anything others see |
| Paid random items | No | Every pass and pack says exactly what it gives |
| Paid item trading | No | There's no trading |

Players can buy real Roblox catalog items through the Catalog tab; that's
Roblox's own purchase prompt and doesn't change the answers.

## 8. Soft launch, then release

Keep it private for a day or two and play the real thing with a few
friends (**Publish settings > Manage Audience > Manage access**,
**Playtest** tab). `docs/playtest.md` has the checklist and the targets.
Send what you find to the project chat; fixes come back as a new place file
(step 6).

Then upload the icon and thumbnails (`docs/marketing.md`) and release it:
**Publish settings > Manage Audience > Manage access**, **Public** tab.
No ads or sponsored placement for the first week. Watch the Creator
Dashboard's **Analytics**: the onboarding funnel (where new players stop),
next-day retention and session length. Fix the biggest drop first, then
promote it.

## Keeping it fresh

- **Themes** drip in by themselves: seasonal ones appear inside their date
  windows (Halloween, winter, Valentine's, spring, summer), and the weekly
  spotlight theme pays double. New themes go at the bottom of
  `Config/Themes.luau`.
- **Season 2** of the Style Pass: copy `Config/Season.luau` with a new Id,
  dates and rewards, add a `style_pass_s2` pass to `Config/Catalog.luau`,
  and make the pass (step 5). Season 1 ends on 1 February 2027. From then
  the game stops offering the Season 1 Style Pass and tells players the
  season is over (they keep every reward they reached), but the pass is
  still on sale on its Roblox page until you take it off sale there, so do
  that on 1 February 2027.
