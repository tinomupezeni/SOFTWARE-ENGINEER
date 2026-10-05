# Consistency percentage was scored against a hardcoded 30-day denominator — unfairly low for any member who joined recently

**Date:** 2026-10-05
**Project:** Club Zero
**Environment:** Development (found while implementing an unrelated, user-requested grid-growth feature)
**Severity:** Medium (no crash or data loss, but a visible, actively discouraging number shown to exactly the users — new members — the app most needs to retain)
**Status:** Resolved

## Summary
`GET /clubs/{id}/stats`'s `consistency_score` was computed as
`(days_with_activity / 30) * 100` unconditionally — dividing by a flat 30
regardless of how long the requesting user had actually been a member of
the club. A member who joined 5 days ago and did everything right every
single day would still see a 17% consistency score (5/30), because the
other 25 days — before they even joined — were silently counted as
"missed" in the denominator. `GET /clubs/me/habits-today` (the newer
unified cross-club endpoint) didn't return a `consistency_score` field at
all, so the native widget and any other consumer computed their own,
client-side, with the same hardcoded `/30` flaw.

## Symptoms
- A new member's consistency percentage was mathematically guaranteed to
  be low for their first ~25 days in a club, no matter how consistent
  they actually were — the exact opposite of what a motivational metric
  should do for someone just starting out.
- Not something a user would necessarily report as "a bug" — it reads as
  a discouraging number, not an error, so it was only found incidentally
  while implementing a related, user-requested feature (the momentum grid
  growing past 30 days), not from a direct complaint about the percentage
  itself.

## Environment Details
- **Server/Host:** N/A — backend calculation bug, not infrastructure.
- **Services Affected:** `club-zero-backend/app/routers/clubs.py` —
  `get_club_stats` (`GET /clubs/{id}/stats`), and by omission,
  `get_my_habits_today` (`GET /clubs/me/habits-today`), which had no
  server-computed score at all until this pass.
- **Time First Observed:** 2026-10-05, while implementing the user's
  separate request to let the momentum grid grow past a fixed 30-day
  window — fixing the window length surfaced that the percentage math
  had the identical hardcoded-30 assumption baked in.

## Investigation Steps

### 1. Initial Diagnosis
While generalizing the grid's window size from a fixed 30 to a
`_grid_window_size()` helper (30 → 50-day cap based on how long the user
has had history), re-read `consistency_score`'s calculation in the same
function and found it was a separate, still-hardcoded `/ 30`.

### 2. Root Cause Analysis
```python
# before
consistency_score = int((sum(1 for h in history if h > 0) / 30) * 100) if history else 0
```
`history` itself was already correctly sized to the grid's window, but
the percentage's denominator was a literal `30`, independent of both the
actual window size and — more importantly — independent of whether the
user had even been a member for that many days yet.

### 3. Key Findings
- The bug predates this session's grid-growth feature entirely — it would
  have under-scored any new member of any club at any point, even before
  today's work to let the grid grow past 30 days. It just happened to be
  caught by a pass that was already touching the exact same calculation
  for an unrelated reason.
- `GET /clubs/me/habits-today` had no equivalent field at all, so fixing
  only the per-club endpoint would have left the newer, now-primary (Home
  screen) surface either missing the number or computing its own
  incorrect version client-side.

## Root Cause
The percentage's denominator was written as a literal `30` instead of
being derived from how many of the window's days were actually the
user's to have acted on — i.e., it assumed every user had a full 30 days
of possible history, which is false for anyone who joined more recently
than that.

## Prevention / Rule
**Guardrail:** Any "percentage of days active" calculation must derive
its denominator from `min(window_size, days_since_the_user_could_first_act)`,
never a literal day count — this is now centralized as `applicable_days`
in both `get_club_stats` and `get_my_habits_today`, computed from the same
`since` reference date (the later of club creation and the user's own
`joined_at`) that also drives the grid's hollow/future-cell cutoff, so the
two can't drift apart again.

## Solution

### Immediate Fix
Both endpoints now compute `applicable_days = min(window, (today -
since_date).days + 1)` and divide by that instead of a literal `30`.
`GET /clubs/me/habits-today` additionally gained the `consistency_score`
field it was missing entirely. `since_date` itself was already needed for
the (separately requested) grid-growth feature, so no new data source was
introduced — the fix reuses what that feature's implementation already
computes.

### Long-term Fix
None needed beyond the fix itself — `applicable_days` is now the single
shared source for both the visual grid's cutoff and the percentage, so
the two can't independently drift out of sync again the way the
percentage alone did here.

## Verification
Directly simulated the scenario via the local dev database: backdated a
club's `created_at` and one member's `joined_at` by 40 days, seeded 24
completions across the last 35 days for that member, left a second
member's `joined_at` at today. Confirmed via the live API: the
established member's score correctly computed as 58% (24 active days /
41 applicable days), and the brand-new member's score was correctly
based on just their 1 applicable day (today), not artificially diluted
by the other 40 days of the club's history they were never part of.

## Prevention
- [x] Fix applied (both endpoints, folded into the grid-growth feature commit)
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none, a calculation bug, not an outage
- [ ] Documentation to update — none
- [x] Code changes required (done)

## Related Issues
- None filed yet.

## References
- Report: `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-10-05-habit-morale-signal-and-grid-fairness.md`
- `club-zero-backend/app/routers/clubs.py` (`get_club_stats`,
  `get_my_habits_today`, `_grid_window_size`)

---

**Resolved By:** Claude (Sonnet 5), found while implementing a related user-requested feature, for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session as discovery, 2026-10-05.
