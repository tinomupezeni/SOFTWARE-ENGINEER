# Dynamic club stats (Momentum screen backed by GET /clubs/{id}/stats)

**Date:** 2026-09-28
**Project:** Club Zero
**Type:** Feature (backend endpoint + mobile wiring + tests)
**Status:** Completed

## Summary
The mobile Stats ("Momentum") tab was fully static — hardcoded 14-day
streak, fixed week pills, and fictional members (You/Nicole/Winston).
Added `GET /clubs/{club_id}/stats` computing streak, week cadence, and
per-member reliability from real `CheckIn` rows, covered it with 7
contract tests, and rewired the screen to load/error/retry/pull-to-refresh
around it with identical visuals. Verified live against the rebuilt
compose stack.

## Context / Trigger
User request: "make the stats page connect to backend, so it becomes
dynamic not just static."

## Scope
Included:
- Backend `GET /clubs/{club_id}/stats` (streak, Mon–Sun week, member
  reliability over a 30-day window, current-user-first ordering)
- `tests/test_stats.py` (7 tests)
- `ClubService.fetchStats` + `StatsScreen` stateful rewrite (loading,
  error+retry, pull-to-refresh, dynamic member rows)
- Live smoke test against rebuilt `api` container

Explicitly excluded (and why):
- Habit-completion-rate stats — the screen's three cards are all
  check-in-derived; no UI calls for habit stats yet. Endpoint returns
  `check_ins_last_30d`/`days_counted` per member so a future card can
  build on it without a new endpoint.
- Backdated-check-in validation (`local_date` before join date still
  accepted) — noticed, not changed; see Follow-ups.
- iOS, hardcoded LAN `baseUrl`s (pre-existing, DEVLOG §3) — untouched.

## Method
Read the static screen first to derive the exact data contract the UI
needed (streak int, 7 labeled day flags, per-member name/percent), built
the endpoint to that contract, tested edge-first (empty club, gaps,
partial-member days, intraday-today), then rewired the screen keeping
every visual identical.

## Decisions & Findings
- **"Complete" = every current member checked in.** Circle-level signal,
  consistent with the screen's "Zero days missed by the circle" copy and
  the existing auto-checkin philosophy (day complete ⇔ all habits done;
  streak day complete ⇔ all members in).
- **Streak stays alive intraday.** If today isn't complete yet, counting
  starts from yesterday — otherwise the screen reads 0 every morning
  before anyone checks in. Pinned by
  `test_stats_streak_survives_incomplete_today`.
- **Reliability denominator = days since join (in a 30d window), clamped
  to [0, 1].** A new club shows 1/1 = 100% after today's check-in rather
  than 1/30 = 3%. The clamp was added after my own test produced 3.0:
  backdated check-ins (allowed by the API) can otherwise push the ratio
  above 1. Never shipped unclamped — caught by the new test before merge.
- **Mobile keeps `fetchSeats`-style service conventions** (`globalToken`,
  same `baseUrl`), throws on non-200 so the screen can show retry UI.
- `flutter analyze` on touched files: 7 info-level lints only, all
  pre-existing patterns (`withOpacity`, unused-import style) preserved
  deliberately — no errors, no warnings.

## Changes Made
- `club-zero-backend/app/routers/clubs.py` — `GET /{club_id}/stats` +
  `WEEKDAY_LABELS` / window constants (~70 lines, no prod code touched
  otherwise; one self-inflicted merged-line typo repaired immediately)
- `club-zero-backend/tests/test_stats.py` — new, 7 tests
- `club_zero_mobile/lib/services/club_service.dart` — `fetchStats`
- `club_zero_mobile/lib/screens/stats_screen.dart` — StatelessWidget →
  StatefulWidget, same visuals, dynamic data
- `SharedHQ/DEVLOG.md` — §4/§7 note the dynamic stats screen

## Verification
- `pytest tests/`: **36 passed** (29 before + 7 new), repeat runs stable.
- `flutter analyze` on both touched files: no errors/warnings.
- Live: `docker compose up -d --build api`, then curl register ×2 →
  create → join → both check in → `GET /stats` returned streak 1,
  today completed, both members 100%, requester first. (Two `smoke@test`
  users + one club left in the dev DB; harmless.)
- Not verified: on-device rendering (no ADB session this task); the
  widget tree is unchanged apart from data sources, and analyze is clean.

## Follow-ups / Deferred
- Consider rejecting (or ignoring for stats) check-ins with `local_date`
  before the member's join date — currently countable, only the ratio
  clamp guards the UI.
- Habit-level stats card (per-habit completion rates) if the product
  wants it — endpoint fields already support member-level extensions.
- On-device check of the Stats tab + pull-to-refresh next physical-test
  session; add a stats step to DEVLOG §7's manual script (done — step 11).
- Still open from prior work: CI for `pytest`, hardcoded LAN baseUrls.

## References
- Prior report: `reports/CLUBZERO-2026-09-28-pytest-coverage-habits-nudges.md`
- `SharedHQ/DEVLOG.md` §4 (what's built), §7 (manual script)
- Key files: `app/routers/clubs.py::get_club_stats`,
  `tests/test_stats.py`, `lib/screens/stats_screen.dart`,
  `lib/services/club_service.dart::fetchStats`

---

**Completed By:** Muse Spark (opencode)
**Duration:** One session
