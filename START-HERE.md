# Start here

**This repository is the home of your final project.** Not a copy of it, not a
backup: the real thing. Your code lives here, your documents live here, your
demo video lives here, and the live app is built from here. At the end you
submit **one link: this repository.**

Read this once, do the six steps, then delete this file.

---

## What you are looking at

It is already a working Flutter app. Run it and you get a screen that says "It
works". Nothing in it is precious; it exists so you start from something that
runs instead of an empty folder.

```
lib/main.dart          your app. Start changing this one.
pubspec.yaml           your app's name and its packages
web/                   the page your app is served from on the web
test/widget_test.dart  one example test
analysis_options.yaml  the linter rules behind flutter analyze

README.md              your project's front page. Fill in every placeholder.
docs/                  all your documents (see below)
.env.example           copy to .env for your keys. .env is never committed.
.gitignore             already ignores .env and other things that must not ship
.github/workflows/     builds your app and publishes the live link on every push
```

## The six steps

**1. Make it yours.** Click **Use this template > Create a new repository**.
Check the **Owner** dropdown says **your own username**, not the course
organisation, and set it to **Public**.

Name it whatever you like. There is no `classcode-yourname` rule this time: it
is your repository and it stays yours after the course. Pick a name you would be
happy to show someone.

**2. Run it.** In a Codespace or on your laptop:

```bash
flutter pub get
flutter run -d web-server --web-port 8080
```

You should see the "It works" screen inside a phone frame. That frame is
`device_preview`, the same one from Modules 4 and 5.

**It stays on in the deployed build too**, on purpose: your live link gets opened
on a desktop browser, and a phone layout stretched across a wide window looks
broken when it is not framed. The toolbar also lets whoever opens it switch
device and orientation. If you would rather ship the clean app with no frame,
`lib/main.dart` says exactly which line to change.

**Want to see where this ends up?** This template's own build is deployed at
https://hau-6adet.github.io/final-project-template/ by the workflow in step 3.
Yours will look like that at your own address once you turn Pages on.

**3. Turn on the live link.** Go to **Settings > Pages > Build and deployment >
Source: GitHub Actions**. That is the only click needed. The workflow is already
in this repository, so every push to `main` rebuilds your site at
`https://yourusername.github.io/your-repo-name/`.

Put that URL at the top of your README. **It is how your project gets opened and
graded.** If it does not load, your app was not seen.

If your app needs configuration at build time (a Supabase URL, for example),
your `.env` is git-ignored so the runner cannot see it. You hand those values
over as **repository secrets**, and page 12 in your workspace walks through it
end to end.

**This works even if your app uses Firebase or Supabase.** Your app calls them
from the browser, and the values it ships (the Firebase config, the Supabase
publishable key) are documented by both vendors as safe to expose. Your security
rules protect the data, not the hosting. Page 12 in your workspace has the
detail, plus the one setting each needs before sign-in works on a deployed site.

**You may deploy somewhere else if you have a reason.** The main one: static
hosting cannot run a server of your own, so if you write your own backend, or
need a proxy to hold a billable key, use a host that runs processes (Render,
Railway, Fly, a Supabase Edge Function) and say which in your README. Firebase
Hosting, Netlify, Vercel and Cloudflare Pages are all fine too.

If your app truly cannot run on the web (camera, sensors, a plugin with no web
support), say so in the README and hand in the APK plus your demo video
instead.

**4. Tell the course where it is.** In your **workspace repo** (the
`student-6ADET-...` one), open
`content/final-project-revision/project-README-template.md`, copy it into the
`project/` folder as `README.md`, and fill in your two links.

On GitHub that is: open `project/`, click **Add file > Create new file**, name
it `README.md`, paste, commit. That folder starts with only `PROPOSAL.md` in it,
so you are adding this one.

The pointer is private and it is how your public repo gets matched to you. There
is no `student.json` in this project and there must not be one: this repo is
public, so your name and student number stay out of it.

**5. Move your documents in.** Everything you have already written for the
planning activities belongs in `docs/`. See the next section.

**6. Start working.** Fill in the README, replace `lib/main.dart` with your own
first screen, and write your first weekly report in
`docs/04-weekly-reports.md` this week, not in week twelve.

## Your planning documents live here too

You submit your proposal, mockup and design system through Canvas, and that does
not change. This repository is where the **final** version of each one ends up,
so that whoever reads your project gets the plan and the code in one place.

**You do not have to keep these in sync while you work.** Nobody reads this
folder until you submit the finished project. Drop in the version you handed to
Canvas, and put the final version here when the project is done. If the plan
changes a lot along the way, update it then, not every week.

The one exception is `04-weekly-reports.md`, which is only useful if you write it
as you go.

Here is where each one lives:

| Canvas activity | Lives here as |
| --- | --- |
| Proposal (m6a1, revised in m7a1) | `docs/01-proposal.md` |
| Wireframes (m6a2) and the mockup (m7a2) | `docs/02-mockup.md` plus the images |
| Design system (m6a3, revised in m7a3) | `docs/03-design-system.md` plus the PDF |
| Weekly reports | `docs/04-weekly-reports.md` |
| Demo video | `docs/05-demo-video.md` |
| Security and privacy checklist | `docs/06-security-and-privacy.md` |

**Two of these are pictures, not documents.** Your mockup is images of your
screens in colour, and your design system needs a visual too. Export a PDF or image of your
palette, type scale, spacing and components from Figma, Canva, Excalidraw,
Google Slides or anything else, put it in `docs/assets/`, and link it from
`docs/03-design-system.md`. A markdown table on its own is not a design system,
it is notes about one.

## Two repositories, and what each is for

You now have two, and they do different jobs.

| | Your workspace repo (`student-6ADET-...`) | This project repo |
| --- | --- | --- |
| Who owns it | the course organisation | you |
| Visibility | private | public |
| What it holds | course content, your grades, notes, journal, attendance | your final project, its docs, its video |
| Its `project/` folder | a link to this repo, plus any working notes | not applicable |
| After the course | you lose access when the org is archived | yours forever |

Keep using the workspace for anything course-related. Keep this one for the
project itself.

## Before you push anything

Read `docs/06-security-and-privacy.md` once. The short version: keys go in
`.env` which is already git-ignored, and no real names, numbers, faces or
messages belong in a public repo, in your sample data or in your screenshots.

## The final check, before you send the link

- [ ] The live link in the README opens and every screen is reachable (or the
      README explains why there is an APK and a video instead).
- [ ] Screenshots in the README are real and current.
- [ ] `docs/` holds the final version of each document: proposal, mockup images,
      design system plus its visual, weekly reports, video.
- [ ] `docs/06-security-and-privacy.md` is complete and dated.
- [ ] You created `project/README.md` in your workspace and it links here.
- [ ] `flutter analyze` is clean.
- [ ] A stranger could clone it, follow your README, and run it.
- [ ] You deleted this file.
