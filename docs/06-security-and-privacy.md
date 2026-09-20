# Security and privacy

This repository is public. Fill this in honestly and date it; it is checked as
part of grading.

**Last checked:** YYYY-MM-DD

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| e.g. the user's task list | on the device (shared_preferences) | only that user |

## Secrets

- Values my app needs at run time: _(list the names, not the values)_
- Where they live locally: `.env`, which is git-ignored
- Where the deploy workflow gets them: repository secrets (Settings > Secrets
  and variables > Actions; the walkthrough is on page 12 of
  `content/extending-your-app/` in your workspace)
- Anything my deployed web build carries that a visitor could read, and why that
  is acceptable: _(a Supabase anon key protected by RLS, a Firebase config
  protected by rules, or nothing)_

## What protects the data on the service side

- Firestore rules / Supabase RLS policies: _(paste or summarize them; "test mode"
  is not an answer)_
- If nothing leaves the device, say that instead.

## Checklist

- [ ] `.env` (or `env.json`) is in `.gitignore`, and `.env.example` is committed
- [ ] `git log -p | grep -i "api_key\|secret\|password\|token"` finds nothing real
- [ ] No service account file, keystore or `service_role` key anywhere in the repo
- [ ] Security rules or RLS policies written and tested, not left open
- [ ] No real personal data in sample data, screenshots or the video
- [ ] No course or university credentials anywhere
- [ ] Anyone whose data appears in a test was asked first

If you found and revoked a key while doing this, say so here. Catching it is the
right outcome, not an embarrassment.
