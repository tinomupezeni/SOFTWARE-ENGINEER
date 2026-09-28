# Club Zero: push notifications, per-habit tracking, multi-club support, and session persistence

**Date:** 2026-09-28
**Project:** Club Zero
**Type:** Feature build (four related initiatives in one continuous session)
**Status:** Completed — verified end-to-end on a physical Android device against the live dockerized backend

## Summary
Starting from a working but minimal Club Zero (auth, single-club-only
dashboard, a single daily check-in with no real-time push), this session
built out four connected features requested incrementally by the user:
FCM push notifications with a friend-nudge mechanic, a redesign of habit
tracking from one all-or-nothing daily check-in into independently
checkable/uncheckable per-habit records with a bulk "complete all"
shortcut, multi-club support with a switcher, and real client-side JWT
refresh-token usage so users stay logged in across app restarts. A
one-time onboarding sequence was added ahead of the auth screens. Seven
concrete bugs were found and fixed along the way — several of them
pre-existing defects that had nothing to do with this session's own
changes but were blocking verification of them (see References).

## Context / Trigger
Direct, iterative feature requests from the user across a single long
session, each building on the last: "work on a library for notifications"
→ "run the app on my phone" → UI fixes surfaced during live testing → "add
habits to track, multiple clubs" → "logs diary... token refresh...
onboarding screens." Each feature was scoped with the user via
`AskUserQuestion` where there was a real architectural fork (push service
choice: Firebase vs. OneSignal vs. local-only; habit tracking: real
backend persistence vs. local-only UI state) rather than assumed.

## Scope
**Included:** FCM push (device registration, check-in and nudge
notifications), nudge feature end-to-end, `Habit`/`HabitCompletion` data
model and endpoints, dashboard rewrite for per-habit state, multi-club
switcher UI, JWT refresh-token client-side usage, one-time onboarding.

**Explicitly excluded** (see `DEVLOG.md` §5 for the full list, kept
current going forward): iOS support (no Mac available in this
environment), automated test coverage for any of the new endpoints
(only manual `curl`/Python smoke scripts were used to verify), habit
delete/rename, per-member private habits (vision doc distinguishes shared
vs. individual habits; only shared was built), offline support, and a
real settings/account screen.

## Method
Backend changes were verified against the live dockerized stack (not just
in-memory test fixtures) with ad hoc Python/curl scripts exercising the
actual HTTP and WebSocket endpoints end-to-end, including multi-user
scenarios (two registered accounts, one club, cross-user visibility of
check-ins/habit completions). Mobile changes were verified by rebuilding
and relaunching on a physical Android phone connected over wireless ADB
after every meaningful change, reading `flutter run`'s live log for
exceptions rather than assuming a clean build meant a working feature —
this caught two runtime-only bugs (a Dart type-inference crash and a
stale-hydration gap) that a compile-only check would have missed.
Architectural forks (push vendor, habit-tracking persistence model) were
put to the user via `AskUserQuestion` rather than assumed, since both
carry real downstream cost (account setup, or a bigger data-model lift).

## Decisions & Findings

**Push vendor: Firebase Cloud Messaging.** User chose FCM over OneSignal
or a local-notifications-only stopgap. Requires the user to hold a
Firebase project (`club-zero-b7ebc`) and provide two credential files
(`google-services.json`, a service-account key) — documented in
`DEVLOG.md` §3, both gitignored, neither committed.

**Habit tracking: real backend-tracked, not local-only.** User chose full
persistence and live sync over a lighter client-side-only toggle. This
meant a genuine new data model (`Habit`, `HabitCompletion`) rather than
reusing the existing single-`CheckIn`-per-day model, and a cross-cutting
"day complete" concept: completing every habit for a day (one-by-one or
via the bulk button) auto-creates the original `CheckIn` record, so the
existing ambient-awareness avatar-lighting and push-notification behavior
keeps working unchanged underneath the new granularity
(`app/realtime.py::maybe_auto_checkin`).

**Foreground notifications are intentionally not shown.** Per the
project's own apple-design skill (`notifications.md`): "Handle
notifications gracefully when your app is in the foreground" — don't
duplicate what the live UI already shows. Since the dashboard already
reflects check-ins/habit completions over the existing WebSocket, a
foreground push banner would be redundant. `NotificationService.onMessage`
deliberately does nothing but log.

**Notification permission requested contextually.** Per the same skill's
onboarding guidance, the permission prompt fires from `MainLayout`'s
`initState` (the user's first real dashboard view, where "see when your
club checks in" is a concrete promise) rather than at app launch or
login.

**Session persistence: refresh-on-launch, not per-request interception.**
Rather than wrapping every HTTP call with 401-triggered refresh-and-retry
logic, `AuthProvider._tryAutoLogin` always exchanges the stored refresh
token for a fresh access+refresh pair once, on app start. Given the
backend's 7-day access / 30-day refresh token lifetimes, this is
sufficient for the realistic usage pattern (opening the app at least
occasionally) without the added complexity of a request interceptor.

## Changes Made

**Backend** (`club-zero-backend/`): `app/models.py` (`Habit`,
`HabitCompletion`, `Nudge`, `DeviceToken`), `app/push.py` (new, FCM
sending via `firebase-admin`), `app/realtime.py` (new, extracted
WebSocket-publish + push-notify helpers shared across check-in and habit
endpoints, plus `maybe_auto_checkin`), `app/routers/habits.py` (new: add
habit, complete/uncomplete), `app/routers/notifications.py` (new: device
token registration), `app/routers/clubs.py` (habit creation on club
creation, `checked_in`/habit-completion data added to `GET /seats`, nudge
endpoint), `app/routers/checkins.py` (bulk habit-completion on manual
check-in, refactored to use `app/realtime.py`), `requirements.txt`
(`firebase-admin`, `uvicorn[standard]`), `docker-compose.yml` (Firebase
credential mount).

**Mobile** (`club_zero_mobile/`): `lib/services/notification_service.dart`
(new), `lib/screens/clubs_screen.dart` (new), `lib/screens/onboarding_screen.dart`
(new), `lib/providers/dashboard_provider.dart` (rewritten for per-habit
state + new WS event types + initial checked-in hydration),
`lib/providers/auth_provider.dart` (rewritten for refresh-token flow,
removed dead `setAuthData`/public `tryAutoLogin`), `lib/screens/dashboard_screen.dart`
(per-habit toggle UI, add-protocol dialog, contrast fixes),
`lib/widgets/daily_habit_card.dart` / `dashboard_seats_row.dart` (contrast
fixes, nudge tap gesture), `lib/main.dart` (onboarding gate), `pubspec.yaml`
(`firebase_core`, `firebase_messaging`), Android Gradle files (Google
Services plugin), `AndroidManifest.xml` (cleartext traffic for the dev
HTTP backend, `POST_NOTIFICATIONS` permission).

## Verification
Every backend endpoint added or changed was exercised against the live
docker stack (not just a test DB) with real multi-user scenarios:
registration → login → club creation → habit add/complete/uncomplete →
auto-checkin trigger → bulk check-in path → nudge (including duplicate
and self-nudge rejection) → device registration → `GET /seats` shape
including the new `checked_in` and `completed_by` fields. The mobile app
was rebuilt and relaunched on a physical device after every change; each
of the two runtime-only bugs (Dart type inference, stale WS-only
hydration) was caught by reading the live `flutter run` log for
exceptions rather than trusting a clean build. Full command transcripts
aren't preserved here — see the individual bug-log entries in
`Backend_and_API/`, `Mobile_Apps/`, and `Database_and_State/` for the
specific verification steps on each.

## Follow-ups / Deferred
See `DEVLOG.md` §5 and §8 for the full, currently-accurate list (kept
there rather than duplicated here so it doesn't go stale in two places).
Top of that list: no automated test coverage exists yet for anything
built this session — habits, nudges, and notification endpoints have only
ever been exercised by hand.

## References
- `/home/shadowe/Projects/SharedHQ/DEVLOG.md` — living status doc, updated
  alongside this report; has the full environment/run instructions and
  manual test script.
- Bug-log entries filed this session (`CLUBZERO-2026-09-28-*`):
  `Backend_and_API/CLUBZERO-2026-09-28-club-seats-endpoint-missing-membership-check.md`,
  `Backend_and_API/CLUBZERO-2026-09-28-test-suite-could-not-even-collect.md`,
  `Database_and_State/CLUBZERO-2026-09-28-str-vs-uuid-query-mismatch.md`,
  `Integrations_and_Auth/CLUBZERO-2026-09-28-refresh-token-endpoint-cannot-ever-succeed.md`,
  `Integrations_and_Auth/CLUBZERO-2026-09-28-auth-secret-key-fallback-drift.md`,
  `Mobile_Apps/CLUBZERO-2026-09-28-mobile-checkin-endpoint-mismatch.md`.
  The WebSocket-library-missing bug (`uvicorn` had no `websockets`/`wsproto`
  installed, so every real-time feature silently 404'd) and the two
  mobile-only runtime bugs found during this session's later feature work
  (Dart map-literal type inference crash; check-in body field name
  mismatch: `check_in_date` vs `local_date`) are documented in `DEVLOG.md`
  §6 rather than as separate dev-log entries, being directly tied to and
  discovered during this session's feature work rather than independent
  findings from a codebase read.

---

**Completed By:** Claude (Sonnet 5), for tinotendamupezeni@thuthuka.tech.
**Duration:** Single continuous session, 2026-09-28.
