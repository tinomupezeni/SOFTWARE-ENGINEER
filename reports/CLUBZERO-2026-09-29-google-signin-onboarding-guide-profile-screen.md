# Club Zero: Google Sign-In, a feature-guide onboarding rewrite, and a real user profile screen

**Date:** 2026-09-29
**Project:** Club Zero
**Type:** Feature build (three related initiatives in one continuous session)
**Status:** Completed — backend verified via pytest (36 passing) and live smoke tests; mobile build installs and launches cleanly on a physical device with no crashes; Google Sign-In's actual end-to-end flow (tapping the button, picking an account) has not yet been walked through by a human, since that requires an interactive OAuth consent screen this session cannot drive itself — see Follow-ups.

## Summary
Directly following the design-audit report earlier this same day, the user
asked for three more things in sequence: a working "Continue with Google"
button (the design audit had left it demoted to a non-functional "SOON"
badge), an onboarding sequence that actually explains what the app's
features are and why they exist (rather than the existing philosophy-only
pitch), and a user profile screen — which turned out not to exist at all.
All three were built this session. Building the profile screen surfaced and
fixed an unrelated UX bug along the way: the only existing "account" control
in the app was a settings-gear icon that logged the user out on a single tap
with no confirmation (see the separate bug-log entry, referenced below).

## Context / Trigger
Direct, sequential user requests: "lets work on that google button, what do
u need from me so we wire it to work, most of the users would want to
quickly signup with google" → (user completed the three Firebase-console
steps this session asked for: enable the Google provider, register the
debug SHA-1 fingerprint, re-download `google-services.json`) → "ok, added
the google-service.json proceed" → then, in the same message as a follow-up
once that was underway, "another thing we want is an onboarding guide that
tells users what the features are and their purposes, lets do that feature,
it runs on first start up and oh, we need a user profile page as well."

## Scope
**Included:**
- `POST /auth/google` backend endpoint (Firebase ID token verification via
  the already-installed `firebase-admin` SDK, find-or-create user by email,
  issues the app's normal JWT pair).
- Flutter-side Google Sign-In wiring (`google_sign_in` + `firebase_auth`),
  replacing the design-audit's "SOON" badge on both login and register
  screens with a real, working button.
- Rewriting the existing 3-page onboarding sequence (which covered app
  philosophy — "no solo mode," "ambient awareness" — but never named a
  single concrete feature) into a 5-page sequence that names and explains
  daily check-in, cheer/nudge, challenges/stakes, and discover/leaderboard.
- A new Profile screen (`lib/screens/profile_screen.dart`) as a 4th bottom-nav
  tab: display name, email, sign-in method (Google vs. email/password),
  member-since date, and a logout button behind a confirmation dialog.
- `GET /auth/me` backend endpoint to back the profile screen (reuses the
  existing `get_current_user` dependency — no new auth logic).
- `User.password_hash` made nullable and a new `User.google_uid` column
  added, both via manual `ALTER TABLE` (see Method — no migration system
  exists yet, documented recurring gotcha).

**Explicitly excluded:**
- iOS — no Google Sign-In setup was done for iOS (no Mac available in this
  environment, matching the existing gap already tracked for push
  notifications).
- Profile editing (changing display name/email), account deletion, and
  leave-club — the user asked for "a user profile page," not account
  management; these remain open gaps, now with an obvious screen to land in
  once built (see Follow-ups).
- An interactive, human-driven walkthrough of the actual Google OAuth
  consent flow — this session verified the button is wired correctly and
  that the backend correctly accepts a valid token and rejects an invalid
  one, but tapping the button and picking a real Google account on-device
  needs a human in the loop (see Follow-ups).

## Method
**Backend** changes were verified two ways: the full `pytest` suite (36
tests, run inside the container after every rebuild) to confirm no
regression, and live smoke tests against the running Docker stack — a
garbage `id_token` against `/auth/google` correctly returns `401 Invalid
Google credential` (not a 500, confirming the verification and error-path
code work even without a real Firebase token to test with), and a real
register→login→`/auth/me` round trip returns the expected shape including
the new `created_at`/`google_uid` fields. The Docker Compose setup here has
no source-volume mount, so `docker compose restart` alone does *not* pick
up code changes — this was caught mid-session (`/auth/google` 404'd after a
plain restart) and required `docker compose up -d --build` instead; worth
remembering for next time rather than assuming a restart is sufficient.

**Mobile** changes were verified with `flutter analyze` after each feature
(zero new errors throughout, same pre-existing `withOpacity` deprecation
notices as baseline), then a full `flutter build apk --release` +
`adb install` + relaunch on the physical device, checking `adb logcat` for
`AndroidRuntime`/`FATAL EXCEPTION`/Dart exceptions after each install. Two
separate release builds were needed: the first to confirm the Gradle side
of `google_sign_in`/`firebase_auth` resolved cleanly against the
newly-added `google-services.json` (it did — no missing-dependency errors),
the second combining that with the onboarding and profile changes for a
final combined verification pass.

## Decisions & Findings

**Google auth goes through Firebase Auth, not standalone OAuth.** Since
`firebase-admin` was already a backend dependency (installed earlier this
session for push) and `google-services.json` already existed for FCM, the
lowest-effort correct path was Firebase Authentication's Google provider —
the client signs in with `google_sign_in`, hands the credential to
`firebase_auth.signInWithCredential()`, and sends the resulting *Firebase*
ID token (not the raw Google one) to the backend, which verifies it with
`firebase_admin.auth.verify_id_token()`. This meant no new backend library,
just one shared Firebase Admin app instance — `app/push.py`'s
`_get_firebase_app()` was renamed to the public `get_firebase_app()` and
imported into `app/routers/auth.py`, since `firebase_admin` only allows one
default app and both call sites need it.

**Google-only accounts get `password_hash = NULL`, not a random unusable
hash.** Considered a fake/random hash as a way to avoid a schema change, but
a NULL is the honest signal ("this account has no password") rather than
an opaque workaround, and the manual `ALTER TABLE` cost was small and
already an established pattern this session. `/auth/login`'s existing
`verify_password` call was also guarded (`not user.password_hash or ...`)
so a Google-only user hitting the password login form gets a clean 401
instead of a crash — this was a real gap the schema change surfaced, not
a hypothetical.

**Existing accounts link by email, not by rejecting the second sign-in
method.** If someone registered with a password and later taps "Continue
with Google" using the same email, `/auth/google` finds the existing user
row by email and just attaches `google_uid` to it rather than erroring or
creating a duplicate account — same account, two ways in. Symmetric case
(a Google user later tries password login) is naturally handled by the
`password_hash` guard above.

**The onboarding rewrite kept the existing page mechanics, only replaced
content.** `_OnboardingPage`/`PageView.builder`/the dot indicator/the
SKIP+GET STARTED buttons were all already generic over `_pages.length` from
earlier in the session's audit-fix pass — no structural code changed, only
the `_pages` const list. Went from 3 pages (philosophy: "no solo mode,"
"ambient awareness") to 5 (a kept cover page, then one page each for
check-in/ambient-awareness, cheer+nudge, challenges+stakes, and
discover+leaderboard) — concrete feature-and-purpose pairs rather than
vibes, per the user's explicit ask.

**The Profile screen absorbed a bug it wasn't looking for.** Scoping where
to put the new screen's logout button surfaced that the *only* existing
logout control in the whole app was a settings-gear icon on the dashboard
that called `logout()` directly on tap — no screen, no confirmation. Fixed
as part of this same pass (icon removed, logout moved to the new Profile
tab behind a confirm dialog) and logged as its own bug entry per the
dev-log convention rather than folded silently into this report.

## Changes Made

**Backend** (`club-zero-backend/`): `app/models.py` (`User.password_hash`
now nullable, new `User.google_uid` column), `app/schemas.py`
(`UserResponse` gained `created_at`, `google_uid`), `app/push.py`
(`_get_firebase_app` → public `get_firebase_app`), `app/routers/auth.py`
(new `GET /auth/me`, new `POST /auth/google`, extracted
`_apply_pending_invites` helper shared between `/register` and `/google`,
`/login` guarded against a null `password_hash`). Manual migration:
`ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL; ALTER TABLE
users ADD COLUMN IF NOT EXISTS google_uid VARCHAR UNIQUE;`.

**Mobile** (`club_zero_mobile/`): `pubspec.yaml` (`firebase_auth`,
`google_sign_in`), `lib/services/google_auth_service.dart` (new — wraps the
Google Sign-In → Firebase Auth handoff), `lib/services/auth_service.dart`
(`googleAuth()`, `getMe()`), `lib/providers/auth_provider.dart`
(`signInWithGoogle()`), `lib/screens/login_screen.dart` +
`lib/screens/register_screen.dart` (real Google button replacing the
"SOON" badge, `_googleSignIn()` handler), `lib/screens/onboarding_screen.dart`
(`_pages` content rewrite, 3→5 pages), `lib/screens/profile_screen.dart`
(new), `lib/screens/main_layout.dart` (4th nav tab), `lib/screens/dashboard_screen.dart`
(removed the instant-logout gear icon — see bug-log entry).

## Verification
Backend: `docker exec club-zero-backend-api-1 python -m pytest -q` → 36
passed, both after the Google-auth-endpoint change and again after the
`/auth/me` addition. Live smoke tests via `curl` against the Dockerized API
confirmed `/auth/google` returns 401 (not 500) for an invalid token and
`/auth/me` returns the correct shape for a real registered user.

Mobile: `flutter analyze lib/` after every feature — 0 errors throughout
(56 total info-level notices at the end, same `withOpacity`-deprecation
class as the session's existing baseline, no new warning types). Two full
`flutter build apk --release` builds, both installed via `adb install -r`
and launched via `adb shell am start` on the physical device
(`SM_S906U1`), with `adb logcat` checked after each for
`AndroidRuntime`/`FATAL EXCEPTION`/Dart exceptions — none found; only
benign engine-level frame-timing log lines (`Reported frame time is older
than the last one; clamping`), which are a known-harmless Samsung/Flutter
engine interaction unrelated to app code. `ActivityTaskManager` confirmed
`Fully drawn` on both installs.

**Not verified:** the actual Google Sign-In consent flow (tapping the
button, picking a real Google account, confirming the resulting session
works end-to-end) — this needs a human tapping through the real OAuth
picker on the device, which this session cannot drive itself. Nor has
anyone visually confirmed the new onboarding pages or the new Profile
screen's appearance — same limitation as the design-audit report earlier
today (build/launch verified programmatically, visual result not yet
eyeballed by a person).

## Follow-ups / Deferred
- **Walk through the real Google Sign-In flow on-device** — tap "CONTINUE
  WITH GOOGLE" on login or register, pick an account, confirm it lands on
  the dashboard with a working session. This is the one part of this pass
  that genuinely cannot be verified without a human.
- **Visually check the new onboarding pages and Profile screen** — same
  standing item as the design audit: nothing in this session can see the
  phone's screen.
- **iOS Google Sign-In** — not set up (no Mac), matching the existing push
  notification gap.
- **Profile screen v2**: edit display name, leave a club, delete account,
  notification preferences — all still open gaps per `DEVLOG.md` §5, now
  with an actual screen (`profile_screen.dart`) to build them into instead
  of inventing a new one later.
- **Docker Compose has no source-volume mount** — every backend code change
  needs `docker compose up -d --build`, not `restart`. Worth adding a dev
  volume mount in a future pass to speed up the edit-test loop, though not
  done here since it's a workflow improvement, not a bug.

## References
- `SOFTWARE-ENGINEER/Mobile_Apps/CLUBZERO-2026-09-29-dashboard-settings-icon-was-an-instant-logout.md`
  — the logout-icon bug found and fixed during this pass.
- `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-09-29-full-app-design-audit-and-fixes.md`
  — the design-audit pass earlier the same day; this report's Google-button
  work directly continues from that audit's finding #8 (Google Sign-In
  demoted, not wired).
- `/home/shadowe/Projects/SharedHQ/DEVLOG.md` — living project status doc;
  not yet updated to reference this pass as of this report (next step).

---

**Completed By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Duration:** Single continuous session, 2026-09-29.
