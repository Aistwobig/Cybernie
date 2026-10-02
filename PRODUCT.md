# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Anyone who wants a cozy, casual virtual hangout: people who want to drop into a
shared space, walk around, chat and meet friends, the way they would in
Gather Town, but with a game-like feel. No narrower age group or community has
been confirmed.

## Product Purpose

Cybernie is a social space where players sign in, walk an avatar around a
pixel-art room and spend time together in real time: seeing each other move,
chatting, and keeping a friends list. Success is people choosing to hang out
there and coming back to the friends they made.

## Positioning

A "safe social space" whose safety rests on verified sign-in: every player is a
real Google account, and signed-out visitors cannot enter rooms, read chat or
see players.

## Operating Context

- Entry flow: splash screen, then Google sign-in (registering is the same
  Google flow; there are no passwords), then the Welcome screen with a
  character preview and JOIN ROOM.
- Bottom navigation between Home (Welcome), Friends and Profile.
- Rooms: chosen on Select Room; the only room today is **Bernie's Tavern**
  (capacity 20), played full screen in landscape.
- In a room: on-screen joystick or WASD/arrow keys, room text chat with speech
  bubbles over avatars, and a live player count.
- Friends: search players by name or username, send/accept/decline friend
  requests, see who is online or how long ago they were active.

## Capabilities and Constraints

- Built in Flutter with Flame for the game rooms; backend is Supabase (auth,
  Postgres with row-level security, Realtime, Storage).
- Today it ships as a web build on GitHub Pages, shown inside a phone frame
  (device_preview) on desktop browsers. Running as installed Android and iOS
  apps is intended but those platform targets are not set up in the repo yet.
- Must adapt per device: browser, Android and iPhone each following their own
  conventions, while sharing one product.
- It is a 6ADET course final project: the repository is public, secrets stay
  out of it, and `flutter analyze` should stay clean.
- Rooms are capped at 20 players. Multiplayer positions are not
  server-validated.
- Only one walking character sprite sheet exists (`menanim.png`), so every
  player currently looks the same in rooms.
- Undecided: voice/proximity chat, direct messages, more rooms, avatar
  customization, emotes, reporting UI (a `reports` table exists, no button yet).

## Brand Commitments

- Name **CYBERNIE**, tagline **"A SAFE SOCIAL SPACE"**.
- Fleur-de-lis logo (`assets/images/logo.png`).
- Existing art: blurred tavern splash background (`assets/images/splash_bg.png`),
  the Bernie's Tavern map (`assets/images/tavern.png`), and the pixel
  character sprite sheet (`assets/images/menanim.png`).
- Mockups of all nine screens live in `docs/` (see `docs/02-mockup.md`).

## Evidence on Hand

- Real, working features listed above; mockup images in `docs/`.
- No real users, testimonials, usage numbers or reviews exist. Do not
  invent player counts, quotes or claims about adoption. The "12 / 20 Players"
  in the mockup was placeholder text; the app now shows live counts.

## Product Principles

1. **Only real people inside.** Every player is a verified account; nothing in
   a room is visible to someone who hasn't signed in.
2. **Hanging out is the point.** Walking, chatting and seeing friends nearby
   come before menus and settings.
3. **Cozy over crowded.** Small rooms and a warm, welcoming feel, not a busy
   public server.
4. **One product, at home on every device.** The same Cybernie on the web,
   Android and iPhone, each feeling native to where it runs.
