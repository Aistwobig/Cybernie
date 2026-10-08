# Demo video

**File:** _(to add: the hosted link, e.g. YouTube unlisted or attached to a
GitHub Release, since the recording will be over GitHub's 100 MB limit)_
**Length:** about 4 to 5 minutes
**Recorded on:** a computer browser (Chrome) and an Android phone with the APK

## What it shows

Planned order, so a viewer can skip to what they need (timestamps to be
updated after recording):

- **0:00** What Cybernie is and who it is for (the landing page).
- **0:20** Sign in with Google, choose a character, set a name, photo and bio.
- **0:50** Friends: search, send a request, accept it on a second account,
  private chat with the message banner and unread badge.
- **1:30** Profile QR code: scan it with a phone and land on the profile in the
  Android app.
- **1:50** Bernie's Tavern: walking, room chat, emotes, sitting on chairs
  facing different ways.
- **2:30** Bernie: order a drink and see its effect, play a hand of blackjack,
  the leaderboard, tasks and the lucky wheel.
- **3:10** Proximity voice chat and cameras between the browser and the phone:
  voices fade as players walk apart, and the camera follows the character.
  (Only works on real devices.)
- **3:50** Upstairs: the meeting room, sharing a screen on the projector and
  opening it full screen.
- **4:20** Night mode, and what I'm proudest of: _(to fill in)_.

## Getting it into the repo

GitHub **blocks any file over 100 MB** and warns over 50 MB, so compress before
you commit:

```bash
ffmpeg -i raw.mp4 -vcodec libx264 -crf 28 -preset slow \
       -vf scale=-2:720 -acodec aac -b:a 96k demo.mp4
```

Raise `-crf` (28 to 32) or drop to `-2:480` if it is still too large. If it still
does not fit, attach it to a **GitHub Release** or upload it unlisted and link it
here. Never commit the raw capture: git keeps it forever even after you delete
it.

## Before you record

- Use test accounts only: no classmates' names, faces or messages without
  asking them first.
- Notifications off.
- Sensible sample data, not "asdf".
- One unbroken take per feature. Say what you are doing while you do it.
