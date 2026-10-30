# Publishing the game

How to put Halloween Tycoon: Your Dream Festival on Roblox, from the place
file to a public game. Do it on the Roblox account that uploaded the sounds:
Roblox only plays audio in games its owner may use, so a game published by
another account or a group is silent until each sound is shared with it (see
step 6 of Getting started in the README).

Roblox changes these screens often. If a button has moved, the
[publishing guide](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
has the current one.

## Before you start

- **Can you publish public games?** Open
  [your eligibility page](https://create.roblox.com/settings/eligibility/public-publish).
  Since December 2025 the account needs ID verification, or a real-money or
  gift card purchase made on or after 1 January 2025.
- **Players under 16** (the 9 to 12 year olds the game is for) take more.
  You can do it after launch, as every new game opens to players aged 16 and
  up first:
  - a checked age on your account (a face age check if you're under 18,
    government ID if you're 18 or older),
  - 2-Step Verification turned on,
  - either the 1,000 Robux publishing fee (you get it back once the game
    keeps 25 highly engaged players for 60 days) or two months in a row of
    Roblox Plus or Premium,
  - and the game must then pass Roblox's check: 250 different highly engaged,
    age-checked players within 60 days, plus a safety review. Progress shows
    on the **Audience Reach** page of the Creator Dashboard.
- **The store art:** the icon and thumbnails were made with an AI image tool.
  Check its terms allow commercial use (see `docs/rights-register.md`).
- **The name:** search Roblox for "Halloween Tycoon" and make sure no big game
  already uses the same name.

## 1. Open the place file

Download `halloween-tycoon.rbxl` and double-click it, or in Studio choose
**File > Open from File**. It holds the whole game; Rojo isn't needed. Press
**Play** for a quick look if you like. In Studio every paid item counts as
owned so it can be tried on; the live game never does that.

## 2. Publish it (still private)

**File > Publish to Roblox**, then **Create new experience** if Studio asks.
Fill in:

- **Name:** `Halloween Tycoon: Your Dream Festival`
- **Description:**

  > Build the spookiest festival on Roblox! Claim a plot, step on glowing pads
  > to build a treat stall, a pumpkin patch, a witch's kitchen, a hedge maze, a
  > giant pumpkin and a ghost train, then pick one of three upgrade paths for
  > each. Catch wisps in Ghost Catcher, chase lanterns in the Moonlight Parade
  > every 10 minutes, name and decorate your festival, and earn wings, capes,
  > pets and weapons as you grow. Brave enough? Step into the Bonk Arena and
  > bonk your friends (it's optional, and you never lose coins). Spooky, never
  > gory.

- **Genre:** Simulation, subgenre Tycoon (or the closest match).
- **Creator:** your own account.
- **Icon:** `assets/marketing/icon.png`. **Thumbnail:** `assets/marketing/thumbnail.png`.
- **Devices:** computer, phone and tablet. Leave console off until it's been
  tried with a controller.

Save. The game now exists on Roblox, but only you can play it.

## 3. Experience settings

Open **File > Experience Settings** (called Game Settings in older Studio).

- **Places:** click **⋯** next to the place, **Configure Place**, and set the
  server size (max players) to **6**. There are six plots; a seventh player
  would have nowhere to build.
- **Basic Info:** add `assets/marketing/thumbnail-vs.png` as a second
  thumbnail. `docs/store-page.md` has the details and the spare icon.
- **Security:** **Enable Studio Access to API Services** only matters for
  testing saves inside Studio. The live game saves either way.
- Leave everything else as it is.

## 4. The content rating questionnaire

On the [Creator Dashboard](https://create.roblox.com/dashboard/creations),
open the game, then **Publish settings > Content rating** (the Maturity &
Compliance Questionnaire). Click **Start**, answer as below, check the
preview and **Submit**. It should come out **Mild**, which is open to every
age.

| Question | Answer | Why |
| --- | --- | --- |
| Age-restricted content | No | |
| Violence | Yes: unrealistic, repeated | The opt-in arena: cartoon bonks, and a knocked-out player is thrown out of the ring dizzy. Nobody dies, no blood |
| Blood | None | |
| Fear | Yes: mild, repeated | A dark foggy night with ghosts, skeletons, gravestones, a low choir, and a reaper statue that turns its head and whispers. No jump scares, no gore |
| Crude humour | None | |
| Romance, alcohol, drugs, tobacco, strong language, gambling, sensitive real-world issues | None | |
| Social hangout | No | It's a tycoon |
| Free-form user creation | No | Festival names come from word lists; nobody types or draws on anything |
| Paid random items | No | Every pass says exactly what it gives |
| Paid item trading | No | There's no trading |

## 5. Make the game passes

Creator Dashboard, the game, **Monetization > Passes > Create pass**, once
for each row below:

1. Upload the icon from `assets/marketing/passes/` (512x512, and Roblox
   crops it to a circle).
2. Type the name and description from the table, and **Create pass**.
3. Open the pass, turn on **Item for Sale** on its **Sales** page and enter
   the price. (The price may also be under **Monetization > Shop**.)
4. Back in the list, click **⋯** on the pass and **Copy Asset ID**.

The prices are the suggested starting points from `Config/Catalog.luau`;
change them if you like. Legendary descriptions must keep the arena
sentence, so buyers know what they're paying for.

| Id | Name | Description | Robux |
| --- | --- | --- | --- |
| `moonstone_mallet` | Moonstone Mallet | The Big Wooden Mallet carved from glowing moonstone. It swings and hits exactly like the wooden one. | 99 |
| `bat_wings` | Neon Bat Wings | Glowing purple bat wings worn on your back. | 129 |
| `ghostfire_crown` | Ghostfire Crown | A golden crown with green ghostfire burning on its points. | 99 |
| `toxic_aura` | Toxic Ghostfire Aura | Green ghostfire that flickers all around you. | 99 |
| `rainbow_trail` | Spooky Rainbow Trail | A bright ribbon of colour that follows your feet. | 79 |
| `pizza_bat` | Pipistrello Pizzetta | Pipistrello Pizzetta, a pet that is half pizza slice and half bat. | 149 |
| `gelato_ghost` | Fantasmino Gelatino | Fantasmino Gelatino, a pet ghost made of mint gelato in a waffle cone. | 149 |
| `candle_buddy` | Candelino Wobblino | Candelino Wobblino, a pet candle with googly eyes and tiny feet. | 149 |
| `zombie_zucchini` | Zucchino Zombino | Zucchino Zombino, a pet zombie zucchini with its arms out. | 149 |
| `thunder_hammer` | Storm-Stone Hammer | The Storm-Stone Hammer. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income. | 499 |
| `ghost_blade` | Ghostlight Blade | The Ghostlight Blade. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income. | 499 |
| `reaper_scythe` | Reaper's Scythe | The Reaper's Scythe. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income. | 499 |
| `drowned_trident` | Drowned Trident | The Drowned Trident. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income. | 499 |
| `foxfire_fan` | Foxfire Fan | The Foxfire Fan. In the PvP arena it is a little stronger than the best earned weapon and has its own special move. It never changes coins or income. | 499 |

Then paste the ids into the project chat, one per line, like
`moonstone_mallet 1234567890`. Claude puts them in `PassId` in
`src/shared/Config/Catalog.luau` and sends a new place file. Until then the
game runs fine: paid items show **Coming soon** in the wardrobe and can't be
bought.

## 6. Publish the new file over the old one

Open the new place file, choose **File > Publish to Roblox As**, pick
Halloween Tycoon, then its place, and **Overwrite**. Do the same for every
later update. Servers that are already running keep the old version until
they close; to move everyone over at once, use **Restart servers** (or
**Shut down all servers**) in the game's menu on the Creator Dashboard.

## 7. Soft launch: test it with a few people first

Keep the game private for a day or two and play the real thing:

- Play it from the Roblox app. Sounds should play; if they're silent, the
  game isn't on the account that owns them.
- Build a few things, leave, wait a minute and rejoin. Coins, buildings,
  paths and items should all still be there.
- Invite three to five friends (Creator Dashboard, **Publish settings >
  Manage Audience > Manage access**, **Playtest** tab) and play together:
  claim plots, catch parade lanterns, try the arena, try a phone.
- Buy one cheap pass with a friend's account or your own (it costs real
  Robux) and check the item turns up and stays after rejoining.
- `docs/playtest.md` has the full list and the targets. Send what you find
  to the project chat; fixes come back as a new place file (step 6).

## 8. Release it

**File > Publish**, **Continue**, then **Publish** (or switch it on in
**Publish settings > Manage Audience > Manage access**, **Public** tab).
With the questionnaire done, it shows as Mild.

At first only age-checked players aged 16 and up can find it. Once you've
done the extra steps under "Before you start", Roblox opens it to younger
players after 250 highly engaged players have played it.

Then keep it a soft launch: no ads or sponsored placement yet. For the first
week, watch the Creator Dashboard's **Analytics**: the onboarding funnel
(where new players stop), how many come back the next day, and how long they
play. Fix the biggest drop first, then promote it.
