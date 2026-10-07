<div align="center">

# Cybernie

**A cozy multiplayer pixel-art tavern: walk in, sit down, and hang out with friends.**

![License](https://img.shields.io/badge/License-MIT-C9A227)
![Flutter](https://img.shields.io/badge/Flutter-3.47-2F9E44?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white)
![Flame](https://img.shields.io/badge/Flame-1.38-E8590C)
![Supabase](https://img.shields.io/badge/Supabase-2.x-3ECF8E?logo=supabase&logoColor=white)
![WebRTC](https://img.shields.io/badge/WebRTC-voice_%7C_video_%7C_screen-555555?logo=webrtc&logoColor=white)
![GitHub Pages](https://img.shields.io/badge/GitHub_Pages-live-222222?logo=github&logoColor=white)
![Status](https://img.shields.io/badge/Status-Beta-E8590C)

</div>

---

> A cozy multiplayer pixel-art tavern for the web/app: pick a character, walk
> into Bernie's Tavern, and hang out with friends through chat, proximity
> voice and video, drinks, mini-games and a meeting room with screen sharing.

| | |
| --- | --- |
| **Landing page** | [aistwobig.github.io/Cybernie/landing](https://aistwobig.github.io/Cybernie/landing/) |
| **Live app** | [aistwobig.github.io/Cybernie](https://aistwobig.github.io/Cybernie/) |
| **Demo video** | Coming soon |
| **Course** | Applications Development and Emerging Technologies (6ADET), Holy Angel University |
| **Author** | Mclaren Ais C. Miranda |

This repository lives in the author's own GitHub account and is public on
purpose. There is no `student.json` here and there should not be one: see
`docs/06-security-and-privacy.md` for what a public repo means for secrets and
personal data.

## Contents

- [Screenshots](#screenshots)
- [What it does](#what-it-does)
- [Built with](#built-with)
- [Running it yourself](#running-it-yourself)
- [Privacy and secrets](#privacy-and-secrets)
- [Project documentation](#project-documentation)
- [Status and what is next](#status-and-what-is-next)
- [Credits](#credits)
- [AI use](#ai-use)
- [Licence](#licence)

---

## Screenshots

Coming soon.

## What it does

**Accounts and friends**
- Sign in with Google. Pick one of six characters (Luna, Rogue, Mage, Lily,
  Thief, Slime), set a display name, photo and short bio.
- Find other players, send and accept friend requests, and see who is online
  and when friends were last active.
- Private chat with friends (text and emotes), with edit and delete. New
  messages pop up as a banner anywhere in the app and show unread badges on
  the Friends tab and on each friend.

**Bernie's Tavern (the multiplayer room)**
- Up to 20 players walk around the same tavern in real time (WASD / arrow
  keys, or an on-screen joystick on phones), with footsteps, a crackling
  fireplace and day / night lighting.
- Room chat, speech bubbles, "is typing" indicators and emotes over your head.
- Sit on any stool or chair. Every character has seated poses facing away,
  sideways and toward the camera, so they sit naturally at every table.
- **Proximity voice chat**: voices get quieter with distance and drop out when
  you walk away. Mute, pick your microphone, speaker and voice volume in
  Settings.
- **Camera**: turn your camera on in voice chat and your video floats above
  your character's head, following them around.
- **Bernie the bartender**: order drinks with coins. Each drink has an effect
  (walking faster, a tipsy sway, hearts that draw friends closer, and more).
- **Mini-games and rewards**: blackjack at the bar, a twice-daily lucky wheel,
  daily coins, tasks with rewards, an inventory and a coin leaderboard.
- **Notice board** with news from the tavern.
- **Upstairs meeting room**: take the stairs to a room with a long table and
  a projector. Share your screen (with sound) on the projector for everyone
  upstairs, and open it full screen. One person shares at a time.

## Built with

| | |
| --- | --- |
| Framework | Flutter 3.47 (Dart), built for the web |
| Game engine | Flame (the tavern, characters, collisions and seating) |
| State | `setState` and `ValueNotifier`s, with small service classes |
| Backend | Supabase: Google sign-in, Postgres with row-level security, Realtime (presence, broadcasts, live database changes), Storage for profile photos |
| Voice, camera, screen sharing | WebRTC, directly between players (browser WebRTC on the web, `flutter_webrtc` in the Android app; Supabase Realtime carries the call setup) |
| Other packages | `audioplayers` (music and sound effects), `shared_preferences` (settings remembered on the device), `image_picker` (profile photos), `google_fonts` and `flutter_svg` (UI), `device_preview` (phone frame), `web` (browser APIs for WebRTC) |

## Running it yourself

```bash
flutter pub get
cp .env.example .env      # then fill in your Supabase values, see below
flutter run -d web-server --web-port 8080 --dart-define-from-file=.env
```

Then open http://localhost:8080. Built and tested with Flutter 3.47.5
(stable).

### Environment variables

This project reads its configuration from a `.env` file that is **not** in the
repository. Copy `.env.example`, fill in your own values, and never commit the
result.

| Variable | What it is | Where to get one |
| --- | --- | --- |
| `SUPABASE_URL` | Your Supabase project's URL | Supabase dashboard > Project Settings > API |
| `SUPABASE_PUBLISHABLE_KEY` | The project's publishable (anon) key, safe to ship in the app | Supabase dashboard > Project Settings > API |

The deploy workflow (`.github/workflows/deploy-web.yml`) reads the same two
names from repository secrets.

### Setting up the database

Run each file in `supabase/migrations/` once, **in order**, in the Supabase
SQL Editor (New query > paste > Run):

1. `20260929000000_init.sql`: profiles, room chat
2. `20260930000000_realtime_rooms.sql`: live rooms
3. `20261001000000_friends_last_seen.sql`: friends and "last seen"
4. `20261003000000_notice_board.sql`: the notice board
5. `20261005000000_direct_messages.sql`: private messages
6. `20261006000000_profile_bio.sql`: profile bio
7. `20261007000000_coins_blackjack.sql`: coins and blackjack
8. `20261008000000_coins_rebalance.sql`: coin rewards
9. `20261009000000_drink_prices.sql`: drink prices
10. `20261010000000_inventory_tasks.sql`: inventory and tasks
11. `20261011000000_lottery.sql`: the lucky wheel

Google sign-in also needs the Google provider turned on in Supabase
(Authentication > Providers) and your site's address added to the allowed
redirect URLs.

## Privacy and secrets

- **What is stored:** your Google sign-in creates a profile (display name,
  username, optional photo and bio, chosen character), plus your friends, room
  and private messages, coins, inventory and game progress. All of it is in
  Supabase. Row-level security policies decide who can read or change each
  row: for example, private messages are readable only by the two people in
  the conversation, and coins can only be changed by the game's database
  functions, never directly by a player.
- **Voice, video and screen sharing are not stored anywhere.** They go
  directly between players' browsers. Google's public STUN servers help
  browsers find each other, which means they see players' IP addresses.
- **On the device:** volume levels, the chosen microphone, camera and speaker,
  and which private messages you've read are saved in the browser
  (`shared_preferences`).
- **Secrets:** the only values the app needs are the Supabase URL and
  publishable key, kept in `.env` locally (git-ignored) and in repository
  secrets for the deploy. Both are designed to be public; the RLS policies
  protect the data. No secret or service-role keys are used anywhere in the
  app.
- All sample data, screenshots and the demo video use test accounts with no
  real personal information.

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope |
| [Mockup and wireframes](docs/02-mockup.md) | what it looks like, and the screen flow |
| [Design system](docs/03-design-system.md) | colors, type, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | what happened each week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Security and privacy](docs/06-security-and-privacy.md) | the checklist, filled in |
| [AI usage](AI-USAGE.md) | how AI was used to build this |

## Status and what is next

**Works:** everything listed under "What it does", on the web, in desktop and
phone browsers.

**Known issues and limits**
- Voice chat, the camera and screen sharing work in the browser and in the
  Android app, and web and app players can call each other. Screen sharing
  from a phone needs the Android app (phone browsers don't allow it), and an
  Android sharer sends the picture only, without sound. Shared sound from a
  browser depends on the browser: a shared tab works best.
- Voice and video connect players directly, so players on very strict
  networks (some school or office Wi-Fi) may not connect. A relay (TURN)
  server would fix this.
- Private message banners only show while the app is open; there are no push
  notifications yet. Unread counts are remembered per device.
- The upstairs meeting room has no NPCs or decorations to interact with yet.

**Next**
- An iOS app, and push notifications.
- A cosmetics shop to spend coins on (name colours, nameplate frames,
  titles).
- A bard jukebox: tip the bard to choose the tavern's song.

## Credits

- **Packages:** see `pubspec.yaml`.
- **Fonts:** Press Start 2P (SIL Open Font License,
  `assets/fonts/PressStart2P-OFL.txt`); Lora, Inter and Lilita One from Google
  Fonts (SIL Open Font License).
- **Sound effects:** generated for this app (footsteps, clicks, coins, cards,
  voice chat chimes, the slime's squish), so no third-party licence applies.
- **Character sprites:** drawn by the author in Aseprite; the animation
  frames (walking, idle and sitting movements) were generated with ChatGPT
  from those drawings, then cleaned up and lined up for the game.
- **Tavern maps and UI art:** _(fill in where these came from and their
  licence)_
- **Background music:** "【Isekai Fantasy Music】Garments in the Mountain
  Breeze【Free BGM 60min】" from YouTube, shared as free background music.
  All credit goes to its creator. The game uses part of it, trimmed to three
  songs.

## AI use

This project was built with help from AI coding assistants (Claude Code),
used for features such as voice and video chat, screen sharing, sprite sheet
processing and collision tuning, always reviewed and tested by the author. The
full record, including where the AI got things wrong, is in
[AI-USAGE.md](AI-USAGE.md).

## Licence

MIT, see [LICENSE](LICENSE).
