# Triangle angle-label position collides with its own angle-bisector construction

**Date:** 2026-11-23
**Project:** HBEC
**Environment:** Development (caught during PR review, PR #171, before merge)
**Severity:** Low
**Status:** Resolved

## Summary
PR #171 adds ruler-and-compasses constructions (`perpendicular_bisector`, `angle_bisector`) to the `triangle` question-diagram, and had already fixed one label-collision case: a side label moving off a `perpendicular_bisector` line that ran straight through it. A second, analogous collision was missed — a vertex's angle label and that same vertex's `angle_bisector` construction both used the identical `unit(u+v)` direction vector from the vertex, so labeling a vertex's angle while also constructing its angle bisector placed the label directly on the bisector line/arc.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review, not in production. A triangle diagram with both an angle label and an `angle_bisector` construction at the same vertex would render the label overlapping the bisector arc/line, making the label hard to read against the construction geometry.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `STUDENT/Frontend` (shared question-diagrams contract).
- **Related Components:** `question-diagrams/Triangle.tsx`, `question-diagrams/construction.ts`.
- **Time First Observed:** 2026-11-23, during review of PR #171.

## Investigation Steps

### 1. Initial Diagnosis
The PR's existing side-label-vs-perpendicular_bisector fix was read in full to understand the collision-avoidance pattern already in place, then checked for whether the same pattern existed for the angle-label case.

### 2. Root Cause Analysis
Both the default angle-label placement and the angle-bisector construction derive their direction from the same `unit(u+v)` vector at the vertex (the two adjacent side directions summed and normalized) — geometrically correct for drawing the bisector itself, but also exactly where the label defaulted to when no bisector was present. The PR's existing fix nudged the *side* label away from a `perpendicular_bisector` line when one bisects that side; no equivalent nudge existed for the *angle* label when an `angle_bisector` targets that vertex.

### 3. Key Findings
- Degenerate-triangle risk (near-zero side length producing NaN/garbage construction coordinates) is not reachable: `solveTriangle`/`solve_triangle` reject minimum angle <8°, side-ratio >8x, non-positive sides, and triangle-inequality violations before any construction or layout math runs — verified by reading both the TS and Python solver implementations directly.
- No other construction/label pairing in the PR shared this issue.

## Root Cause
A label-placement default and a construction's drawn geometry were derived from the same direction vector without checking whether the two features (label, bisector) ever target the same vertex simultaneously — an instance of the general "new feature forgets to extend an existing collision-avoidance mechanism to its own analogous case" pattern, mirroring the side-label fix already present in the same PR.

## Prevention / Rule
**Guardrail:** when a label-placement default and a drawn construction can both occupy the same vertex/side, label placement must check for every construction kind that could collide at that location, not just the one case already fixed by precedent in the same PR. A visual regression or geometric-overlap test (label bounding box vs. construction path bounding box) for every construction-kind × label-kind combination would catch this systematically rather than per-incident.

## Solution

### Immediate Fix
Mirrored the existing side-label fix: nudged the angle-label direction toward one adjacent side when an `angle_bisector` construction targets that same vertex, so the label no longer sits on the bisector line/arc.

```bash
git add -A && git commit -m "fix: angle label must avoid its own angle_bisector construction"
git push origin HEAD:feat/diagram-constructions
```

### Long-term Fix
Add a geometric-overlap test across every construction-kind × label-kind combination the triangle diagram supports, rather than relying on visual inspection to catch each case individually.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add a geometric-overlap test for label vs. construction bounding boxes across all combinations.
- [ ] Documentation to update: none required beyond this log entry.
- [x] Code changes required (label direction fixed).

## Related Issues
- Reviewed alongside PR #170 (pie-chart tone collision) and PR #172 (Zimbabwe map), same diagram-kinds review batch; see `reports/HBEC-2026-11-23-pr-168-to-176-review-batch.md`.

## References
- PR: https://github.com/Rest-creator/HBEC/pull/171

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session)
**Time to Resolution:** Caught and fixed before merge, same review session
