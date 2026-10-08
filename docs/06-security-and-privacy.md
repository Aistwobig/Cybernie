# Security and privacy

This repository is public. Filled in from the database migrations in
`supabase/migrations/` and a scan of the git history.

**Last checked:** 2026-10-09

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Profile: display name, username, character, bio, last seen | Supabase `profiles` | signed-in players; only the owner can change it (not their coins) |
| Profile photo | Supabase Storage, `avatars/<user id>/` (public bucket, 1 MB, JPEG/PNG) | anyone with the link; only the owner can upload, replace or delete |
| Friendships and requests | Supabase `friendships` | only the two players in it |
| Room chat | Supabase `messages` | signed-in players |
| Notice board notes | Supabase `notice_notes` | signed-in players; only the author can remove theirs |
| Private messages | Supabase `direct_messages` | only the sender and the recipient |
| Reports of players | Supabase `reports` | nobody through the app (players can only file them) |
| Coins, blackjack hands, inventory, task rewards, lucky wheel spins | Supabase (`profiles.coins`, `blackjack_hands`, `player_items`, `task_claims`, `lottery_spins`) | only the player, through database functions |
| Who is in a room, positions, voice / camera / screen state | Supabase Realtime presence (not stored) | players in the same room |
| Voice, video and shared screens | not stored: sent directly between players' devices (WebRTC) | the players in the call |
| Volumes, chosen devices, night mode, read messages | on the device (`shared_preferences`) | only that device |

## Secrets

- **Values my app needs at run time:** `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`.
- **Where they live locally:** `.env`, which is git-ignored (`.env.example`
  with placeholder values is committed).
- **Where the deploy workflow gets them:** repository secrets (Settings >
  Secrets and variables > Actions), read by `.github/workflows/deploy-web.yml`.
- **What the deployed web build and the Android APK carry that anyone could
  read:** the Supabase URL and publishable (anon) key. That is acceptable:
  Supabase designs this key to be public, and the row-level security policies
  below decide what it can reach. No secret or service-role key is used
  anywhere.

## What protects the data on the service side

Every table has row-level security turned on, and table access is granted
column by column: anything not granted is denied.

- **Profiles:** signed-in players can read; a player can update only their own
  row, and only `username`, `display_name`, `avatar_url`, `character_index`
  and `bio`. Coins are deliberately not in that list.
- **Friendships:** visible only to the two players in them; a request can only
  be sent as yourself; only the addressee can accept; either side can decline
  or unfriend.
- **Room chat and notice board:** signed-in players read; posting only as
  yourself; notes removable only by their author.
- **Private messages:** readable only by the sender and recipient; can only be
  sent as yourself, **to a friend**; only your own messages can be edited or
  deleted.
- **Reports:** can only be filed as yourself; nobody can read them from the
  app.
- **Coins and game data** (`blackjack_hands`, `player_items`, `task_claims`,
  `lottery_spins`): all direct access is revoked. They change only through
  `security definer` database functions (dealing, hitting and standing in
  blackjack, buying drinks, claiming tasks, spinning the wheel), which check
  the rules and the caller's id themselves.
- **Avatar storage:** a player can only write inside their own
  `avatars/<user id>/` folder.
- **Realtime room channels:** only signed-in players can send and receive.

## Checklist

- [x] `.env` is in `.gitignore`, and `.env.example` is committed
- [x] `git log -p | grep -i "api_key\|secret\|password\|token"` finds nothing
      real (checked 2026-10-09; the only hits are words in build tool logs)
- [x] No service account file, keystore or `service_role` key anywhere in the
      repo (the APK is signed with the local debug key, which isn't committed)
- [x] Security rules or RLS policies written, not left open (see above)
- [ ] No real personal data in sample data, screenshots or the video
      _(check when the screenshots and video are added)_
- [x] No course or university credentials anywhere
- [ ] Anyone whose data appears in a test was asked first _(confirm before
      recording the demo)_

## Notes

- **2026-10-09:** Java crash logs (`hs_err_pid*.log`, `replay_pid*.log`) had
  been committed by accident with the first APK build. They held no keys, only
  the computer's Windows username and hardware details. They were removed and
  are now git-ignored. They remain in older commits.
- Voice and video calls use Google's public STUN servers to find a route
  between players, so those servers see players' IP addresses.
