# Gamification Dashboard Load Re-Queries the Student's Entire Activity History Three Times, Unbounded

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`)
**Severity:** Medium (performance regression on the most-visited screen,
scales with learner tenure — product's own north star is years, not sessions)
**Status:** Investigating (flagged in PR review)

## Summary
`GET /gamification/dashboard` calls, in sequence:
`backfill_streak_xp(db, student_id)` (line 318) → `build_stats(db,
student_id)` (line 193) → `dashboard(db, student_id)` (line 244). Each of
these independently calls `load_days(db, student_id)` (line 127) with **no
`since` bound** — three separate SELECTs over the student's entire
`DailyActivity` history in one request. Before this PR, `backfill_streak_xp`
bounded its own query to `since=today - timedelta(days=60)`; PR #51 removed
that bound (comment: "The full history, so a freeze earned long ago is
honoured exactly as the dashboard honours it"), making it unbounded like the
other two call sites.

## Symptoms
None observed yet (not yet merged). Would surface as rising dashboard
latency and DB load proportional to account age and dashboard traffic.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (FastAPI)
- **Services Affected:** `GET /gamification/dashboard`
- **Related Components:** `app/analytics/gamification/service.py`
  (`load_days`, `build_stats`, `dashboard`, `backfill_streak_xp`)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Efficiency angle of the PR review checked the gamification dashboard path
for redundant/unbounded queries given it is the single most-visited screen.

### 2. Root Cause Analysis
Read `service.py` directly: `backfill_streak_xp`, `build_stats`, and
`dashboard` each call `load_days` independently with no shared cache and no
`since` bound (the bound that used to exist on `backfill_streak_xp` was
removed in this PR).

### 3. Key Findings
- For any student with a long history, every dashboard open issues 3
  identical full-table-scan-shaped queries against `daily_activity` instead
  of 1.

## Root Cause
Each function was written to independently load what it needs from
`daily_activity`, rather than one shared load passed down from the request
handler; this PR's freeze-honoring fix additionally removed the one bound
that existed.

## Prevention / Rule
**Guardrail:** load `days = await load_days(db, student_id)` once in the
dashboard request handler and thread it into `backfill_streak_xp`,
`build_stats`, and `dashboard` as a parameter, rather than having each
re-query. If a bound is still desired for very long histories, apply it once
at that single load site, not per-function.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review.

### Long-term Fix
Refactor the three functions to accept `days` as a parameter, loaded once.

## Prevention
- [ ] Refactor `backfill_streak_xp`/`build_stats`/`dashboard` to share one
      `load_days` call per request
- [ ] Add a query-count assertion test for `GET /gamification/dashboard`

## Related Issues
None.

## References
- `AGENTIC_HARNESS/app/analytics/gamification/service.py`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending fix
