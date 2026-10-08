# Weekly reports

One entry per week, newest at the top. The **Done** lists match the commit
history for each week, and the hours are estimated from commit times.

---

## Week 3 (2026-10-04 to 2026-10-10)

**Done this week**
- Friend requests (sent and received), private messages, a player card in the
  tavern and editable bios.
- Two new characters, Lily and Luna, then Thief (from the dancer), with idle,
  walk and sitting animations; every character can now sit on every chair,
  facing away, sideways or toward the camera.
- Bernie the bartender: drinks with effects, blackjack with coins, a
  leaderboard, tasks, an inventory and a twice-daily lucky wheel.
- Sound: background music, footsteps, the fireplace and other effects.
- Proximity voice chat, a microphone / camera / speaker picker, and cameras
  drawn above each player's head.
- Fixed the edge swipe that threw players out of the tavern.
- The upstairs meeting room with screen sharing on the projector.
- Private message notifications, profile QR codes and a player profile page.
- The landing page, a favicon and a full README.
- The Android app: v1.0 (with voice, camera and screen sharing) and v1.1
  (QR codes open the app, landscape tavern, sounds no longer stop the music).

**In progress**
- The demo video and screenshots.

**Blocked or stuck on**
- Sitting animations took several attempts per character (e.g. Lily and the
  Rogue), because each chair direction needed its own sheet lined up with the
  furniture.
- The camera picture lagged behind characters until it was drawn inside the
  game instead of over it.
- The background music kept restarting: the 60-minute music file was too big
  for the browser, so I trimmed it to three songs.
- The first Android build failed twice (a missing Android NDK, then a Kotlin
  cache problem because the project and Flutter are on different drives).
- On phones the keyboard and notifications came up sideways in the tavern.
  Fixed in v1.1 by turning the app to landscape there.

**Decisions made, and why**
- Voice, video and screen sharing go directly between players (WebRTC), with
  Supabase only carrying the call setup: free, and nothing is recorded.
- Coins can only be changed by database functions, so players can't cheat by
  editing their own row.
- Built an Android app instead of iOS, because iOS needs a Mac.

**Hours spent, roughly:** about 31 hours of coding sessions (estimated from
commit times), plus time drawing in Aseprite.

**Next week I will:**
- Record the demo video and add screenshots.
- Write the final reflection and finish the documentation.

---

## Week 2 (2026-09-27 to 2026-10-03)

**Done this week**
- Login screen with Google sign-in, and the character preview.
- Profile screen with photo upload.
- Supabase: accounts, profiles, rooms and row-level security.
- Real-time multiplayer: the tavern room is built and players see each other
  move.
- Real friends list, add friends, online status and last seen.
- The fantasy UI for Home, Friends, Profile and Select Room; emotes, "who's
  here", player cards, reports and the notice board.
- The Mage and the Slime characters, with animation fixes (frame bleed, idle
  and run sheets).
- Night mode.

**In progress**
- More characters and sitting.

**Blocked or stuck on**
- Sprite sheets with frames bleeding into each other and inconsistent idle
  animations.
- Tab navigation sliding the wrong way (fixed).
- A new colour style that broke the UI tests, so I reverted it and kept the
  old one for that day.

**Decisions made, and why**
- Moved from local-only data to Supabase, because a shared tavern needs a
  server and live updates.
- Replaced the plain Material look with a fantasy UI to match the pixel art.

**Hours spent, roughly:** about 17 hours of coding sessions (estimated from
commit times), plus time drawing in Aseprite.

**Next week I will:**
- Private messages, sitting, and things to do in the tavern.

---

## Week 1 (2026-09-20 to 2026-09-26)

**Done this week**
- Created the repository and the Flutter project.
- Finalized the design system plan: palette, type scale, 4 px spacing and the
  planned reusable components (see the week 1 documentation and reflection
  journal in this folder).
- Added the logo and first assets.
- Splash screen, and started the login screen.

**In progress**
- Login and navigation between the main screens.

**Blocked or stuck on**
- How to organize reusable components without overcomplicating the folder
  structure.
- Turning the visual design into actual theme values.
- Getting used to committing and pulling with GitHub (a few test commits and
  a merge).

**Decisions made, and why**
- One central theme file, so every screen stays consistent.
- Widgets take data and callbacks instead of holding screen logic.

**Hours spent, roughly:** about 4 hours of coding sessions (estimated from
commit times), plus planning the design system.

**Next week I will:**
- Finish login, add the profile screen and connect a backend.
