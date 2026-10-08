# Proposal

**Cybernie**, a cozy multiplayer pixel-art tavern.
Final version, 2026-10-09.

## The problem, in one sentence

Hanging out with friends online usually means a plain chat window or a video
call grid, and neither feels like *being somewhere together*: there is no shared
place to walk around in, sit down, and bump into people.

## Who it is for

- **Friends and small online groups** (classmates, gaming groups, Discord-style
  communities) who want a shared place to hang out, not just a chat list.
- **Players who like cozy pixel-art games** and would rather walk up to someone
  and talk than start a call.
- People on **any device**: a computer browser, a phone browser, or the Android
  app, all in the same rooms.

## Core features

- **Sign in with Google**, pick one of six hand-drawn characters (Luna, Rogue,
  Mage, Lily, Thief, Slime), set a name, photo and bio.
- **Friends**: search players, send and accept requests, see who is online and
  when friends were last active, private chat with text and emotes.
- **Bernie's Tavern**: up to 20 players walk around the same pixel-art tavern
  in real time, with room chat, speech bubbles, typing indicators and emotes.
- **Sitting**: every stool and chair can be sat on, and every character has
  seated poses facing away, sideways and toward the camera.
- **Proximity voice and video**: voices fade with distance; cameras float above
  each player's head.
- **Bernie the bartender**: drinks with effects, blackjack, a daily lucky wheel,
  tasks, an inventory and a coin leaderboard.
- **Upstairs meeting room** with a projector for screen sharing.
- **Profile QR codes** that open a player's profile (in the app if installed).

## Out of scope, and why

- **An iOS app.** Building for iOS needs a Mac and an Apple developer account;
  iPhone players use the web version in Safari instead.
- **Push notifications.** They need a native notification service and a server
  to send them; private message banners only show while the app is open.
- **A relay (TURN) server for voice and video.** Calls connect players
  directly, which is free; a relay would cost money to run. Players on very
  strict networks may not connect.
- **Character customization beyond the six characters.** Each character has
  dozens of hand-made animation frames; a mix-and-match system would multiply
  that work.
- **Real money.** Coins are earned in the game only and cannot be bought.

## Data the app remembers, and where it is saved

| Data | Where |
| --- | --- |
| Profile: display name, username, photo, bio, chosen character, last seen | Supabase (Postgres) |
| Friends and friend requests | Supabase |
| Room chat, notice board notes, private messages | Supabase |
| Coins, blackjack hands, inventory, task rewards, lucky wheel spins | Supabase, changed only by database functions |
| Profile photos | Supabase Storage (`avatars` bucket) |
| Who is in the tavern, where they stand, who is in voice | Supabase Realtime presence (not stored) |
| Voice, video and shared screens | Sent directly between players, never stored |
| Volumes, chosen mic / camera / speaker, night mode, read messages | On the device (`shared_preferences`) |

## Risks

- **Voice and video not connecting** on strict networks (no relay server).
  Mitigation: text chat always works; a TURN server can be added later.
- **Cheating with coins.** Mitigation: players cannot write their coins at all;
  only database functions (blackjack, tasks, the wheel) change them.
- **Strangers messaging players.** Mitigation: private messages are only
  allowed between friends (enforced by RLS), and players can be reported.
- **Performance with many players and cameras** on older phones. Mitigation:
  small, low frame rate camera video; calls only to nearby players.
- **Large download size** of the Android app (about 150 MB) because of the art,
  music and the WebRTC library.

## Changes since the last version

- **2026-09-29:** Chose Supabase for accounts, data and real-time multiplayer
  instead of local storage only, because the tavern needs to be shared live.
- **2026-10-02:** Replaced the planned plain Material screens with a fantasy UI
  (framed cards, parchment colours, a night mode), to match the pixel art.
- **2026-10-05:** Added Bernie, drinks, blackjack and coins so there is
  something to do together besides talking.
- **2026-10-06 to 10-07:** Added proximity voice chat and cameras (WebRTC),
  drawn inside the game above each character.
- **2026-10-08:** Added the upstairs meeting room with screen sharing, profile
  QR codes, the landing page and an Android app (v1.0).
- **2026-10-09:** Android app v1.1: QR codes open the app, landscape tavern on
  phones, iOS kept out of scope.
