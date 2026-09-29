# Supabase setup

Cybernie uses Supabase for sign-in (Google only), the database and profile
photos. Do these steps once. They take about 15 minutes.

## 1. Create the project

1. Go to https://supabase.com/dashboard and click **New project**.
2. When it is ready, open **Project Settings > API Keys** and copy the
   **Project URL** and the **Publishable key**. Do not copy the secret key: it
   must never go into the app.
3. In the repo root, copy `.env.example` to `.env` and paste the two values in:

   ```
   SUPABASE_URL=https://abcdefgh.supabase.co
   SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   ```

## 2. Create the tables

Open **SQL Editor > New query**, paste the whole of
[`migrations/20260929000000_init.sql`](migrations/20260929000000_init.sql) and
click **Run**. This creates:

| Table | What it holds | Who can do what |
| --- | --- | --- |
| `profiles` | username, display name, photo, character, level | everyone signed in can read; you can edit your own (not level/XP) |
| `friendships` | friend requests and friends | only the two people involved can see it; only the receiver can accept |
| `rooms` | Bernie's Tavern and future rooms | read-only for players |
| `messages` | tavern chat | signed-in players read; you post as yourself, max 200 characters |
| `reports` | reports from the Report button | players can file but never read them |
| `avatars` (storage) | profile photos | public to view; you can only write to your own folder |

A profile row is created automatically the first time someone signs in with
Google.

## 3. Create the Google OAuth client

1. Go to https://console.cloud.google.com, create a project (or pick one).
2. **APIs & Services > OAuth consent screen**: choose **External**, fill in the
   app name (Cybernie) and your email, and save. While it is in **Testing**,
   only the test users you add can sign in, so add your own Google account and
   anyone who will test it.
3. **APIs & Services > Credentials > Create credentials > OAuth client ID**:
   - Application type: **Web application**
   - Authorized JavaScript origins:
     - `http://localhost:8080`
     - `https://<your-github-username>.github.io`
   - Authorized redirect URIs: the **Callback URL** shown in Supabase under
     **Authentication > Sign In / Providers > Google**. It looks like
     `https://abcdefgh.supabase.co/auth/v1/callback`.
4. Copy the **Client ID** and **Client secret**.

## 4. Turn on Google in Supabase

1. **Authentication > Sign In / Providers > Google**: enable it and paste the
   Client ID and Client secret.
2. **Authentication > URL Configuration**:
   - **Site URL**: your live link, `https://<user>.github.io/<repo>/`
   - **Redirect URLs**, add both:
     - `http://localhost:8080/`
     - `https://<user>.github.io/<repo>/`

   If a URL is missing here, Google sign-in sends you back to the Site URL
   instead of the page you started from.

## 5. Run it

Always use port 8080, because that is the address allowed above:

```bash
flutter run -d chrome --web-port 8080 --dart-define-from-file=.env
```

In VS Code, the **Cybernie (Chrome)** launch configuration does this for you (F5).

## 6. Deploy it

In GitHub, go to **Settings > Secrets and variables > Actions** and add two
repository secrets with the same names and values as your `.env`:
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. The deploy workflow already
passes them into the build.

## Where the code lives

| File | Job |
| --- | --- |
| `lib/config/supabase_config.dart` | reads the URL and key passed in at build time |
| `lib/services/auth_service.dart` | Google sign-in, sign-out, current user |
| `lib/services/profile_service.dart` | read/update your profile, upload your photo |
| `lib/models/profile.dart` | the `profiles` row as a Dart class |
