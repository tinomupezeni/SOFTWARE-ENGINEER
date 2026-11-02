# Web — Android App Download Button on the Login Page

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (verified in a real browser; see Follow-ups for the deployment gap)

## Summary
Added a "Download Android App" button to the web login page, so a user can
grab the Flutter mobile app's APK directly from the browser instead of
needing `adb install`. This also required rebuilding the mobile app as a
proper **release** APK — the debug build the mobile phases had been using
all session is 222MB (unusable as a web download); the release build is
56MB.

## Context / Trigger
Direct user request: "need a download button to allow user to download the
mobile app, it should be downloadable from the login page."

## Scope
Included: the button on `LoginForm.tsx`, the release APK, serving it as a
static asset from the frontend. Excluded: a CI pipeline that rebuilds and
republishes the APK automatically, app versioning/update-check UI, iOS
(no equivalent artifact exists — Flutter iOS builds need a signed
IPA/TestFlight pipeline, out of scope for "a download button").

## Method
Checked whether the debug APK already built this session could simply be
reused (it's what every on-device phase verification used) — at 222MB it's
unsuitable for a web download, mainly due to bundled debug symbols/the
Dart VM and un-split ABIs. Checked the Android release signing config
first (`android/app/build.gradle.kts`): it already signs release builds
with the debug key (`// Signing with the debug keys for now, so flutter
run --release works`), so `flutter build apk --release` worked without
needing a new signing setup.

## Decisions & Findings
- **Single universal release APK**, not `--split-per-abi`. Per-ABI splits
  produce smaller individual files, but require the user to pick the right
  one for their phone — poor UX for a non-technical CRM user grabbing an
  app from a login page. One file, no choice to get wrong.
- **Pointed the release build at the same LAN backend IP used all session**
  (`192.168.60.242:8020`) — there's no deployed production backend yet
  (`.env.example` files only have placeholder domains), so this is the only
  backend that currently exists for the app to talk to.
- **The APK is git-ignored**, not committed — found that the repo's root
  `.gitignore` already has an unqualified `downloads/` rule (from the
  Python-packaging section of the default template), which incidentally
  also matches `frontend/public/downloads/` since gitignore patterns
  without a leading `/` match at any depth. Left this as-is rather than
  special-casing it back in: a 56MB binary doesn't belong in git history
  (every future clone would carry it forever, and it'll need rebuilding
  whenever the backend URL or app changes anyway).
- **Verified with a real headless-browser run**, not just a visual check:
  navigated to `/login`, confirmed zero console errors, took a screenshot,
  then separately triggered the actual download and confirmed the saved
  file's size matches the source APK byte-for-byte (56,207,692 bytes) and
  the suggested filename is correct.

## Changes Made
- `frontend/src/features/auth/components/LoginForm.tsx` — added a
  "Download Android App" link/button below the existing sign-in form,
  pointing at `/downloads/myra-crm.apk` with the `download` attribute.
- `frontend/public/downloads/myra-crm.apk` — the release APK (not
  committed — see Decisions).
- `mobile_flutter/build/app/outputs/flutter-apk/app-release.apk` — the
  release build artifact this was copied from (also a build output, not
  committed).

## Verification
- `npm test` (frontend) — 24/24 passing, no regressions from the
  `LoginForm` change.
- `npx tsc -b` — clean.
- Started the Vite dev server, drove it headlessly: `/login` renders with
  zero console errors, the button is visible and styled consistently with
  the rest of the form, and clicking it downloads a file whose size and
  name match the source APK exactly.

## Follow-ups / Deferred
- **No CI/deploy story yet** — the APK at `frontend/public/downloads/`
  only exists on this machine right now. Whenever the mobile app or its
  backend URL changes, someone needs to rebuild
  (`flutter build apk --release --dart-define=API_BASE_URL=<url>`) and
  re-copy it in, and the same needs to happen on whatever machine actually
  builds the production frontend. Worth a real pipeline (a GitHub Action
  that builds the APK and uploads it as a release asset or to object
  storage) once there's an actual deployment target to build it for.
- Once a production backend domain exists, the APK needs rebuilding
  against that URL — the current one is hardcoded to the dev LAN IP.
- No update-check / versioning UI — if the backend URL or app changes,
  anyone who already installed the old APK has no in-app signal to
  reinstall.

## References
- `reports/CRM-2026-11-02-flutter-phase4-products-crud.md`
- `mobile_flutter/android/app/build.gradle.kts`
- `frontend/src/features/auth/components/LoginForm.tsx`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
