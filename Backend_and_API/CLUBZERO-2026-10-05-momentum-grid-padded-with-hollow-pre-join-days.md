# The momentum grid padded out to a fixed 30 days even for brand-new members, showing a confusing mix of three visual tiers

**Date:** 2026-10-05
**Project:** Club Zero
**Environment:** Development (found by direct report, confirmed against a real user account's live data)
**Severity:** Medium (no data corruption — the underlying numbers were correct — but a confusing, demoralizing-looking visual for exactly the newest, most retention-critical users)
**Status:** Resolved

## Summary
Earlier the same day, `_grid_window_size()` was written to always return at
least 30 (growing past that only once a user had more than 30 days of
real history), with the days before a user's join date rendered as a
third "hollow/bordered" visual tier distinct from "done" (solid) and
"missed" (dim, GitHub-contribution-graph style). The user reported this
directly: "why are some boxes and some github hub shades and all is
starting at the last 3 10 grid... the grids are not correlated to the
calendar but supposed to be based on when the user started." Pulled their
real account (`mupezeni2001@gmail.com`, joined both their clubs 10 days
before this report) and confirmed the underlying data was in fact
correctly computed against their actual join date — the problem was the
30-day padding and its hollow tier, not a calculation error.

## Symptoms
- A user 10 days into the app saw a 30-cell grid where 19 of those cells
  (nearly two-thirds of it) were a bordered/hollow "not applicable" tier,
  with their actual 11 days of real history compressed into the last
  third — described by the user as looking like "the last 3 10 grid."
- Three distinct visual states in one grid (hollow-bordered = before
  joining, dim-filled = real day with nothing done, solid-mint = real day
  with activity) read as inconsistent/confusing rather than informative.
- Not a data-correctness bug — every number was right — but a bad first
  impression for exactly the newest users, the ones the app most needs to
  retain.

## Environment Details
- **Server/Host:** N/A — backend calculation/design issue.
- **Services Affected:** `club-zero-backend/app/routers/clubs.py` —
  `_grid_window_size()`, shared by `get_club_stats` and
  `get_my_habits_today`.
- **Time First Observed:** 2026-10-05, same day as the feature that
  introduced it — reported directly by the user minutes after the
  original grid-growth work (see the companion report) shipped.

## Investigation Steps

### 1. Initial Diagnosis
Rather than guess at what "not correlated to the calendar" meant, pulled
the actual account's data directly: club memberships, join dates, habit
list, and every completion row, from the live database.

### 2. Root Cause Analysis
Minted a short-lived JWT server-side for the reporting account (read-only
diagnostic use, same `create_access_token` the app itself calls) and hit
`GET /clubs/me/habits-today` as that real user, then hand-traced every
cell of the returned 30-length `history` array against their actual
completion dates (Sep 28, 29, Oct 3, Oct 5) and join date (Sep 25, 10
days before the report). Every value matched exactly — the computation
was correct. The only thing wrong was `_grid_window_size()` itself,
which deliberately padded to a minimum of 30 regardless of how recently
the user had joined:
```python
# before
if days_since < 30:
    return 30
```

### 3. Key Findings
- This confirms the earlier design (fixed 30-day frame + a hollow "future"
  tier for pre-join padding, chosen and confirmed with the user before
  implementation) was itself the wrong call once actually seen in a real
  account, even though it was the intentional, agreed design minutes
  earlier — worth remembering that a design confirmed verbally can still
  turn out wrong once the person sees their own real data rendered, and
  that's a legitimate, fast follow-up fix, not a failure to listen the
  first time.
- The fix is purely a formula change in one function — no migration, no
  new fields, nothing else needed to change, since every consumer (mobile
  grid rendering, the native widget, the percentage calculation) already
  derived its behavior from `window`/`since` dynamically rather than a
  hardcoded 30.

## Root Cause
`_grid_window_size()` treated 30 as a floor, not just a cap — intended to
give even day-one users a "full-looking" grid, but the actual effect was
a confusing three-tier visual that buried a new user's real (short)
history inside a mostly-hollow frame.

## Prevention / Rule
**Guardrail:** when a time-window UI component has a "minimum size for
visual consistency" requirement, verify it against the *youngest possible*
real account before shipping, not just older/established test accounts —
the failure mode here (confusing, not wrong) only shows up for someone a
few days in, which is exactly the account type least likely to be used
for ad hoc verification.

## Solution

### Immediate Fix
```python
# after
days_since = (today - since_date).days
return min(50, max(1, days_since + 1))
```
The window is now sized to exactly how many days the user has had
anything to track — 1 on their first day, growing by one each day,
capped at 50. No padding, so no hollow tier is ever shown; every cell
rendered is a real day. Purely a backend change — no mobile code needed
updating, since the Flutter side already reads `since` and `history.length`
dynamically rather than assuming a fixed 30 (built that way during the
same day's earlier grid-growth work, which is what made this a one-line
fix rather than a cross-stack one).

### Long-term Fix
None needed — the formula is now the complete, correct rule.

## Verification
Re-ran the exact same live, read-only check against the real reporting
account after the fix: `since` unchanged (2026-09-25, correctly their own
join date, not recalculated), but `history` is now exactly 11 cells long
(their real day count) with zero hollow padding, and the same 11 real
values as before, still matching their actual completions exactly. Full
`pytest` suite: 42 passed, unchanged.

## Prevention
- [x] Fix applied
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none, a visual/UX issue, not an outage
- [ ] Documentation to update — none
- [x] Code changes required (done, one function)

## Related Issues
- None filed yet.

## References
- Report: `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-10-05-habit-morale-signal-and-grid-fairness.md`
  — the same-day work that introduced `_grid_window_size()`, which this
  entry corrects.
- `club-zero-backend/app/routers/clubs.py` (`_grid_window_size`)

---

**Resolved By:** Claude (Sonnet 5), reported directly by the user against their own real account, for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session, same day as the original design, 2026-10-05.
