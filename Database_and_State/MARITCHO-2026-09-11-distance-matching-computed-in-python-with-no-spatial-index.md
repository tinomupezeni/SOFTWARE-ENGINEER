# Distance-Band Matching Computes Haversine in Python Per-Candidate — No Spatial Index, Doesn't Scale Past a Small Suburb/Worker Count

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Low
**Status:** Resolved (acknowledged as a deliberate trade-off; tracked for
future revisit, not fixed now — see Solution)

## Summary
`app/geo.py`'s `classify_distance`/`haversine_km` compute distance in pure
Python for every candidate worker/crew on every matching request, after
fetching all trade-matching candidates and their service areas into memory
(`app/matching.py::find_top_candidates`,
`app/crew_matching.py::find_top_crew_candidates`). There is no spatial
index (e.g., PostGIS's `GIST` index on a `geography` column) — the
database can't pre-filter by distance at all; every eligible-by-trade
worker's coordinates are pulled into the app process and compared in a
loop. This is fine at the current pilot scale (a handful of suburbs, a
small worker base) but doesn't scale the way a real index-backed spatial
query would as coverage widens (per the business case's own Stage
Two/Three plans to widen suburb coverage and add a second city).

## Symptoms
- `app/models.py`'s `Suburb` table stores plain `latitude`/`longitude`
  `Numeric` columns — no PostGIS extension, no `geography`/`geometry`
  column type, no spatial index.
- `app/matching.py`/`app/crew_matching.py` fetch *all* candidates matching
  trade + skill first, then loop over every one of them computing
  haversine distance in Python, rather than pushing the distance filter
  into the SQL query itself.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/geo.py`, `app/matching.py`,
  `app/crew_matching.py`
- **Time First Observed:** 2026-09-11, scalability review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the matching engines' query shape while assessing overall
scalability.

### 2. Root Cause Analysis
This was a deliberate, reasonable choice at the time (see the earlier
"suburb reference table + haversine" design decision, chosen explicitly
over PostGIS to keep the self-hosted, resource-constrained infra simple
for a Stage One pilot with ~6 suburbs). The trade-off is real but was
intentional, not an oversight — flagged here as a scalability limitation
to revisit, not a bug.

### 3. Key Findings
- With ~6 suburbs and a small worker base, in-Python distance computation
  over a handful of candidates is negligible cost. It becomes a real
  bottleneck once candidate counts (workers × service areas) grow into the
  thousands, since every matching request re-fetches and re-computes
  distance for the full trade-eligible set rather than using an index to
  narrow it first.

## Root Cause
A deliberate simplicity-over-scale trade-off made when distance-banding
was first built (see the same day's earlier crew-hire/matching work),
correct for the stated pilot scope, worth flagging now since the user is
explicitly asking about scalability limits.

## Prevention / Rule
**Guardrail:** A trackable backlog item with an explicit numeric/scale trigger condition (`BACK-008`), plus an inline comment at the exact decision point, rather than an implicit "we'll remember this is fine for now."

That's what actually converts a silently-expiring judgment call into something that resurfaces on its own terms once the stated condition is met, instead of being rediscovered from scratch — or missed entirely — once real load arrives.

## Solution

### Immediate Fix
This finding's own recommended fix was explicitly conditional ("if/when
suburb coverage or worker count grows enough") — this is the one finding
of the ten that concluded, on its own investigation, that the current
behavior is a deliberate and still-correct trade-off, not a defect to
patch. Consistent with that, and with not building unrequested
infrastructure (the same judgment applied to the Redis/background-worker
finding), no PostGIS migration was added.

What *was* done, same day, so the decision doesn't get silently
re-discovered later:
- `app/geo.py` gets a short header comment stating the trade-off
  explicitly, why it's fine today, and what would trigger revisiting it.
- `docs/backlog.md` gets a real, trackable item — **BACK-008**, status
  `DEFERRED` — with an explicit trigger condition (Stage Two/Three
  coverage growth), mirroring how the Redis/background-worker deferral
  (`BACK-007`) was tracked.
- Verified `ruff check .` / `mypy .` still clean (43 files) and the full
  suite still green (92 passed, 92.86% coverage) after the comment-only
  change — no behavioral change was made, none was warranted.

### Long-term Fix
Unchanged from the original finding: once Stage Two (wider Bulawayo
coverage) or Stage Three (a second city) actually lands, add the PostGIS
extension, a `geography(Point)` column (or a bounding-box pre-filter on
the existing lat/long columns), and a `GIST` index, then push the
distance filter into the query instead of computing it for every
candidate in Python. `BACK-008` is the place to pick this up.

## Prevention
- [x] Recorded the trigger condition as a real backlog item (`BACK-008`)
  instead of an easy-to-forget note, so "revisit once Stage Two/Three
  lands" survives past this session
- [x] Left an explanatory comment directly in `app/geo.py` so a future
  reader encounters the reasoning at the point they'd otherwise wonder
  about it, not only in this dev-log entry

## Related Issues
- Same review pass as the missing-FK-indexes finding — both are about the
  database not being asked to do filtering work it's well-suited for

## References
- Business case Stage Two/Three — wider suburb coverage, a second city

---

**Resolved By:** Claude Code (architecture-review-to-fixes session) —
acknowledged and tracked, not code-fixed, since this was correctly
identified as a deliberate design trade-off, not a defect
**Time to Resolution:** Same day, follow-up session
