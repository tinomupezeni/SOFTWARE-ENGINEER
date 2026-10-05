# Habit Anchors Backend Store (spec Task 1)

**Date:** 2026-10-05
**Project:** CLUBZERO
**Type:** Feature Implementation (spec Task 1 of 5)
**Status:** Completed

## Summary

Implemented the backend half of habit anchors (personal cue per member per habit, e.g. "after my morning shower"): new `habit_anchors` table, `PUT /clubs/{club_id}/habits/{habit_id}/anchor` upsert-or-delete endpoint, and per-requester `my_anchor` in the seats payload. Verified with 6 new tests (42/42 suite green), a clean container rebuild with the table auto-created, and live curl proof of set/403/seats behaviors.

## Context / Trigger

Owner-directed feature from `docs/planning/habit-anchors-load-guidance-spec.md` (spec written same day from `docs/Pschology.md` §§5–6: implementation intentions, habit stacking). Task 1 of the spec's 5-task build order; mobile UI (tasks 2–5) not started.

## Scope

Included: model, schema, endpoint, seats payload, tests, rebuild + live verification.
Excluded: everything mobile (tasks 2–5); coping-planning; any change to shared-habit/check-in/streak logic; production deploy (local compose only).

## Method

Followed the file's own conventions exactly: `_require_membership` helper and habit-in-club 404 check copied from `complete_habit`; strip-and-validate in the endpoint like `add_habit`'s name handling; tests appended to `tests/test_habits.py` reusing its `register_and_login`/`create_club`/`seat_state` helpers. One deliberate spec deviation: route is `PUT /clubs/{club_id}/habits/{habit_id}/anchor` rather than the spec's `PUT /habits/{habit_id}/anchor`, to match every sibling endpoint's `/{club_id}/habits/{habit_id}` shape and reuse the same membership guard.

## Decisions & Findings

- New table (not a column): anchors are per member per habit (M×N); neither `Habit.anchor` (shared — wrong) nor legacy `ClubMember.individual_habit` (per club — wrong granularity) fits. `UNIQUE(habit_id, user_id)` enforces one cue each.
- Empty-string PUT deletes (idempotent clear) rather than a separate DELETE — one endpoint covers the whole lifecycle.
- `my_anchor` is requester-scoped in seats: two members set different anchors on the same habit and each sees only their own (tested).
- No manual SQL was needed (`create_all` builds new tables); confirmed `habit_anchors` exists in the compose DB with the unique constraint.
- Pre-existing test tooling note: system python lacks pytest deps — suite runs via `venv/bin/python -m pytest`.

## Changes Made

- `club-zero-backend/app/models.py`: `HabitAnchor` model (+ unique constraint). Uncommitted in SharedHQ working tree.
- `club-zero-backend/app/schemas.py`: `AnchorUpdate` schema.
- `club-zero-backend/app/routers/habits.py`: `PUT anchor` endpoint (upsert/delete, 400 >120 chars, 403 non-member, 404 wrong-club).
- `club-zero-backend/app/routers/clubs.py`: `my_anchor` in seats habit objects (null when unset; single batched query).
- `club-zero-backend/tests/test_habits.py`: 6 anchor tests (set+seats, update+delete, overlong, 403, 404, per-member privacy).

## Verification

- `py_compile` + `ruff F821/F822/F823/E9` clean on all touched backend files.
- `venv/bin/python -m pytest tests/`: **42 passed** (was 36 incl. existing habits/nudges suites — no regressions).
- `docker compose up -d --build`: boots clean, no errors in api logs, table present in Postgres.
- Live curl: set → `{"anchor_text": "my morning shower"}`; non-member → 403; seats shows `my_anchor` for owner. Update/delete/isolation covered by pytest.

## Follow-ups / Deferred

- Spec tasks 2–5 (mobile anchor input, card subtitle, edit sheet, load header/note, nudge copy) — untouched.
- Probe rows in local dev DB from verification (`gridprobe` club, `anchorlive` club, smoke + anchor test users) — dev-only, private/invisible, safe to leave or wipe with the DB volume.
- Production deploy to `smepulse-vm` not done — needs no manual SQL (new table auto-creates) but confirm via boot-log check per the spec.

## References

- Spec: `SharedHQ/docs/planning/habit-anchors-load-guidance-spec.md` (Task 1)
- Research: `SharedHQ/docs/Pschology.md` §§5–6
- No bug-log entry (no bug; clean implementation). Companion context: today's 4 `CLUBZERO-2026-10-05-*` backend entries (the missing-gate pattern this work's test coverage now starts to close).

---

**Completed By:** Muse Spark (opencode)
**Duration:** ~45m
