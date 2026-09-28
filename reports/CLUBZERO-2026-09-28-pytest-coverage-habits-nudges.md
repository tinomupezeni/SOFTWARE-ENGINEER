# pytest coverage for habits, nudges, device registration, and auto-checkin

**Date:** 2026-09-28
**Project:** Club Zero
**Type:** Test coverage (closes the single biggest gap named in `DEVLOG.md` §5)
**Status:** Completed

## Summary
Added 20 contract tests across `tests/test_habits.py` (11) and
`tests/test_nudges.py` (9), plus a hermetic realtime seam in
`tests/conftest.py`. Suite went from 9 tests (2 red without a hand-rolled
local Redis) to 29 green from a bare `pytest`, stable across repeat runs.
Habit/nudge/device/auto-checkin paths — previously exercised only with
manual curl scripts — now have an automated safety net.

## Context / Trigger
`SharedHQ/DEVLOG.md` §5 names missing coverage for
"habits, nudges, device registration, and the auto-checkin logic" as "the
single biggest gap if this project is going to keep growing", and §8 lists
`tests/test_habits.py` + `tests/test_nudges.py` as priority #1. The user
asked to start there.

## Scope
Included:
- Habit add / complete / uncomplete incl. all auth and validation edges
  (empty name, duplicate same-day, unknown habit, non-member)
- Nudge send incl. self-nudge, same-day duplicate, non-member target,
  non-member sender, unauthenticated
- Device-token registration incl. re-pointing one token across two users
- Auto-checkin (`maybe_auto_checkin`): single-habit instant path,
  multi-habit last-completion path, partial-completion negative path,
  bulk `POST /check-in` habit-fill path
- Realtime contract assertions: which WS event fires per action
  (`habit_added`, `habit_completed`, `habit_uncompleted`,
  `check_in_completed`), via a publish recorder

Explicitly excluded (and why):
- Actual WebSocket delivery and FCM push delivery — contract-level only,
  matching the existing suite's SQLite precedent (validate contracts, not
  infra). Live-delivery checks belong in the manual test script
  (`DEVLOG.md` §7) or a marked integration test with throwaway infra.
- Habit delete/rename — the endpoints don't exist yet (deferred feature,
  see Follow-ups).
- iOS, offline, settings — unrelated gaps, untouched.

## Method
Per WORKING-PROCESS: researched first (read all routers, models, schemas,
existing tests, push/redis behavior), established the pre-change baseline
(7 passed / 2 failed, plus a collection blocker), mirrored the existing
test style (register → login → club → act, substring `detail` asserts),
then wrote the new files and fixed the baseline failures with a minimal
conftest addition rather than expanding scope.

## Decisions & Findings
- **Record publishes, don't run Redis.** An autouse `published_events`
  fixture in `conftest.py` replaces `app.realtime._publish` with a
  recorder. This un-breaks the 2 pre-existing check-in tests and removes
  the prior session's local-Redis-container workaround entirely. Full
  write-up in the companion bug entry (see References) rather than here.
- **The event assertions immediately paid off:** a single-habit club's
  first completion fires `check_in_completed` on the same request (correct
  — completing the only habit *is* completing everything). Two of my own
  assertions were wrong about this before the code was; the tests now pin
  the real behavior.
- **Uncompleting does not retract the auto-checkin.** Clearing the last
  habit removes the completion but leaves the `CheckIn` row, so the seat
  still shows checked-in. Pinned as-is in tests; whether that's desired is
  a product question (see Follow-ups) — deliberately not changed.
- **venv was missing `firebase-admin`** (declared in
  `requirements.txt`, absent from the venv) so the suite couldn't even
  collect. Installed `firebase-admin==6.5.0` per requirements; pip flagged
  dependency conflicts (protobuf/opentelemetry-api versions) — inert here
  because telemetry setup is commented out in `app/main.py`, but worth
  knowing before re-enabling it.
- Pre-existing warnings (`datetime.utcnow`, `redis.close()`, pydantic
  class-based `config`) left alone as out of scope; noted in Follow-ups.

## Changes Made
- `club-zero-backend/tests/test_habits.py` — new, 11 tests
- `club-zero-backend/tests/test_nudges.py` — new, 9 tests (incl. 3
  device-registration tests)
- `club-zero-backend/tests/conftest.py` — added autouse
  `published_events` fixture (+16 lines, with a why-comment)
- `club-zero-backend/venv` — installed `firebase-admin==6.5.0` (+ deps)
  to match `requirements.txt` (env repair, not committed code)
- No production code changed.

## Verification
- Baseline before: collection error (missing `firebase_admin`); after
  installing it: `2 failed, 7 passed` (both Redis `ConnectionError`).
- After: `29 passed` — twice consecutively, plus `--collect-only`
  confirms 29 tests collected. No flakes observed.
- New tests fail for the right reasons when the seam is removed
  (verified implicitly: the 2 pre-existing failures were exactly this).

## Follow-ups / Deferred
- CI job running `pytest` from a clean install with no services (open
  since the prior `test-suite-could-not-even-collect` entry; now guards
  this seam too).
- Product question: should uncompleting the final habit retract the
  auto-checkin? Currently it doesn't.
- Habit delete/rename endpoints + tests (DEVLOG §8 #3).
- Warning hygiene: `utcnow` deprecations, `redis.close()` → `aclose()`,
  pydantic `ConfigDict` migration.
- Revisit the pip dependency conflicts if OpenTelemetry is re-enabled.

## References
- Bug entry: `Backend_and_API/CLUBZERO-2026-09-28-pytest-redis-test-seam.md`
- Prior entry: `Backend_and_API/CLUBZERO-2026-09-28-test-suite-could-not-even-collect.md`
- Prior report: `reports/CLUBZERO-2026-09-28-notifications-habit-tracking-multiclub-token-refresh.md`
- `SharedHQ/DEVLOG.md` §5 (gaps), §8 (next steps)
- Key files: `app/routers/habits.py`, `app/routers/clubs.py`
  (`nudge_member`), `app/routers/notifications.py`,
  `app/realtime.py::maybe_auto_checkin`

---

**Completed By:** Muse Spark (opencode)
**Duration:** One session
