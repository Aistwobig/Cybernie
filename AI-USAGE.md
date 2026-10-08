# AI usage

This project was built with AI assistance. This file is the record of it.

Tools used:
- **Claude Code** (Anthropic), in VS Code: code for features, fixes, sprite
  sheet processing, the landing page, the Android build and documentation
  drafts.
- **ChatGPT** (OpenAI): the animation frames (walking, idle, sitting) for the
  characters, generated from my own Aseprite drawings, and some help with the
  tavern maps and UI art, which I made in Aseprite.

## 1. How I used AI

### 2026-10-05 - Character animation frames

- **Tool:** ChatGPT
- **What I asked for:** Walking, idle and sitting movement frames for the
  characters I drew in Aseprite (Luna, Lily, the Mage, the Thief and others).
- **What it gave back:** Sprite sheets with the movements, but with
  inconsistent frame sizes and spacing.
- **What I kept, what I changed, and why:** I kept the movements and redrew or
  cleaned up frames that didn't match my character. The sheets then had to be
  lined up frame by frame for the game (several "fix sprite" commits).
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/2d78537

### 2026-10-07 - Cameras above characters' heads

- **Tool:** Claude Code
- **What I asked for:** An on-camera feature in voice chat, with each camera
  following its character around the tavern.
- **What it gave back:** WebRTC video in the existing voice calls, first shown
  as a page element over the game, then rebuilt so each camera is drawn inside
  the game above the name tag.
- **What I kept, what I changed, and why:** I rejected the first version
  because the picture lagged and drifted (see section 2) and kept the in-game
  version. I also asked for a camera picker in Settings.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/d67ad6f

### 2026-10-07 - Edge swipe and phone rotation

- **Tool:** Claude Code
- **What I asked for:** Swiping from the left edge was taking players out of
  the tavern, and entering the tavern forced the phone to rotate.
- **What it gave back:** The tavern now ignores back gestures (only the Leave
  button leaves), and the room is drawn sideways instead of rotating the phone.
- **What I kept, what I changed, and why:** Kept it. Later (v1.1) I asked for
  the Android app to rotate to landscape after all, because the keyboard and
  notifications appeared sideways.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/4342918

### 2026-10-08 - Upstairs meeting room and screen sharing

- **Tool:** Claude Code
- **What I asked for:** A new map reached by the stairs, with a projector where
  one player at a time can share their screen (with sound), a full screen
  option, and "*name* is sharing the screen" when someone else is.
- **What it gave back:** The upstairs floor with a fade on the stairs, the
  projector, WebRTC screen sharing, and sitting on every chair.
- **What I kept, what I changed, and why:** Kept the feature; the chairs needed
  several rounds of fixes (see section 2).
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/0a359e9

### 2026-10-08 - Private message notifications

- **Tool:** Claude Code
- **What I asked for:** A notification when someone messages me privately.
- **What it gave back:** A message banner on every screen, unread badges on the
  Friends tab and each friend, and tapping the banner opens the chat.
- **What I kept, what I changed, and why:** Kept it, and later asked for the
  banner to be restyled to match my landing page.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/6d13aca

### 2026-10-08 - Profile QR codes and player profiles

- **Tool:** Claude Code
- **What I asked for:** A "Generate QR code" button on the profile that opens
  your profile when scanned, and a new profile screen for other players (bio,
  last online, add friend, message).
- **What it gave back:** The QR dialog, the player profile screen and the
  `/player/<id>` route, remembered through sign-in.
- **What I kept, what I changed, and why:** Kept it. On 2026-10-09 I asked for
  the QR code to open the Android app if it's installed, or download it if not
  (commit 3fdb001).
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/f0ba87e

### 2026-10-08 - Landing page

- **Tool:** Claude Code
- **What I asked for:** An original landing page for Cybernie using my app's
  assets, after looking at another landing page for ideas.
- **What it gave back:** A static page with the tavern sign, a scroll tour, the
  character roster, a voice demo, a playable blackjack demo and the music.
- **What I kept, what I changed, and why:** I asked to drop the pixel font
  because it looked AI-made (now Plus Jakarta Sans), to highlight Bernie's
  blackjack, rename the sign to "Bernie's Tavern", add the friends section, and
  make the music start by itself.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/d982d4a

### 2026-10-08 - Android app

- **Tool:** Claude Code
- **What I asked for:** An installable Android app, then voice, camera and
  screen sharing inside it, working together with web players.
- **What it gave back:** The Android project, the APK build steps, and phone
  versions of the voice and screen engines using `flutter_webrtc`, plus the
  Android screen-capture service.
- **What I kept, what I changed, and why:** Kept it. iOS was left out because
  it can't be built without a Mac.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/751b0e6

## 2. Where the AI got it wrong

### Case 1 - The camera lagged behind the character

- **What it gave me:** The camera picture as a separate page element placed on
  top of the game, moved to follow each character.
- **What was wrong with it:** It was always a step behind and slightly off the
  head, because the page element and the game were drawn at different times.
- **What I did instead:** I told it the camera didn't follow the head and was
  delayed, and had it rebuilt as part of the character inside the game, the
  same way the name tag is drawn.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/d67ad6f (replacing
  https://github.com/Aistwobig/Cybernie/commit/88556d1)

### Case 2 - The meeting room chairs

- **What it gave me:** Seats on the upstairs chairs that used the meeting room
  art as it was, then seat positions that left the Rogue looking cropped on the
  chairs in front of the table.
- **What was wrong with it:** The characters' sitting poses didn't fit how those
  chairs were drawn, so nobody looked naturally seated, and one seat row was
  placed too low for the Rogue's sprite.
- **What I did instead:** I suggested taking the chairs from the first floor,
  which already worked, and putting them in the meeting room. Then I pointed
  out the Rogue specifically, and the seat position was moved up and tested.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/afff91e and
  https://github.com/Aistwobig/Cybernie/commit/d121c61

### Case 3 - Two Bernies at the landing page blackjack table

- **What it gave me:** A blackjack scene that used a table image which already
  had Bernie painted into it, with the animated Bernie placed on top.
- **What was wrong with it:** Two cats overlapped behind the table.
- **What I did instead:** I pointed out the overlapping sprite, and the table
  was switched to the version of the image without Bernie.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/7179b07

### Case 4 - The music restarting

- **What it gave me:** Background music using a 51 MB, 60-minute compilation
  file.
- **What was wrong with it:** The browser couldn't keep up with such a large
  file, so the music stopped and started again from the beginning every few
  seconds.
- **What I did instead:** Trimmed it to three songs (about 11 MB), which plays
  smoothly.
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/9dd50d4

## 3. Who wrote what

At least a fifth of this project is code I wrote myself. Named and explained
below in my own words.

### Written by me

- **File:** `lib/screens/login_screen.dart`, and the character sprite sheets
  in `assets/images/` (sitting and walking animations)
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/1e43ecb (login
  screen), https://github.com/Aistwobig/Cybernie/commit/3cbed48,
  https://github.com/Aistwobig/Cybernie/commit/e7efb4a and
  https://github.com/Aistwobig/Cybernie/commit/066a5bb (sprite fixes)
- **What it does and why it is built this way:** I did the login screen,
  where players sign in with Google to get into the game. I also fixed the
  sprites myself, because the AI can't fix the sprites when the characters
  are sitting or doing animations. It still can't fix them, so I fixed the
  sprite sheets by hand.

### The AI-written part I understand best

- **File:** `lib/game/character.dart` (`CameraPicture`)
- **Commit:** https://github.com/Aistwobig/Cybernie/commit/d67ad6f
- **What it does and why we kept it:** The camera above the characters' heads.
  I understand it the best because the AI explained to me how it did it, and
  it was exactly what I had in mind: the camera goes through WebRTC, and the
  picture is drawn above the character's head so it moves with them.
