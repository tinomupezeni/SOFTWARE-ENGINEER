# Pie-chart sector tone cycle lets adjacent sectors share a fill at the seam

**Date:** 2026-11-23
**Project:** HBEC
**Environment:** Development (caught during PR review, PR #170, before merge)
**Severity:** Low
**Status:** Resolved

## Summary
PR #170 adds a `pie_chart` question-diagram kind, with a stated guarantee that neighbouring sectors are visually distinct "even in greyscale" via a 4-tone fill cycle. `PieChart.tsx` assigned each sector's fill as `[0.14,0.34,0.22,0.46][i % 4]`. For any sector count whose index wraps the 4-tone cycle back to index 0 — e.g. 5 sectors, a valid count under the diagram's 2-8 sector bound — the last sector (index 4, tone index 0) sits adjacent to the first sector (index 0, tone index 0) at the 12 o'clock seam, giving two neighbouring sectors the identical tone and defeating the stated guarantee.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review. A 5-, 9-, or 13-sector pie chart (any count ≡ 1 mod 4 plus 1, i.e. where sector count mod 4 == 1) would render with its first and last sectors indistinguishable by fill, specifically at the one seam a viewer's eye naturally closes the circle on.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `STUDENT/Frontend` (and the shared question-diagrams contract consumed by tutor answers, notes, and the whiteboard).
- **Related Components:** `question-diagrams/PieChart.tsx`.
- **Time First Observed:** 2026-11-23, during review of PR #170.

## Investigation Steps

### 1. Initial Diagnosis
The PR's stated safety guarantees (sector bounds, minimum sector angle, whole-degree enforcement) were each checked against the actual validator and rendering code rather than taken from the PR description, including the "neighbours part even in greyscale" claim specifically.

### 2. Root Cause Analysis
A 4-element tone array indexed by `i % 4` repeats its first tone every 4th sector. Sector count 5 is both within the diagram's valid 2-8 bound and large enough to wrap the cycle exactly once, placing index 0 and index 4 next to each other on the circle with identical tones.

### 3. Key Findings
- All other stated guarantees (sector bounds, zero/negative-sector rejection, minimum 6° sector angle, whole-degree rounding, admin/harness validator byte-identity) were verified correct and unaffected by this issue.
- The histogram diagram added in the same PR does not share this code path and was unaffected.

## Root Cause
A fixed-length tone cycle indexed by plain modulo doesn't account for the array being arranged in a closed loop (a circle), where the element at the wrap-around point is adjacent to the first element, not just to its immediate neighbours in index order.

## Prevention / Rule
**Guardrail:** any color/tone cycle applied to a closed (circular) sequence must check adjacency at the wrap point specifically — either by choosing a cycle length that is coprime with every valid count in the diagram's allowed range, or, more simply, by special-casing the last element when `count % cycle_length == 1` to use a different tone than index 0. A test asserting no two circularly-adjacent sectors share a tone, parametrized across the full valid sector-count range, would catch this directly.

## Solution

### Immediate Fix
Bumped the wrapping sector's tone to index 1 instead of index 0 when the sector count causes the cycle to wrap back to the first tone, so the circularly-adjacent pair never matches.

```bash
git add -A && git commit -m "fix: pie chart wrap-around sector must not repeat the first tone"
git push origin HEAD:feat/diagram-statistics
```

### Long-term Fix
Add a parametrized test across the diagram's full valid sector-count range (2-8) asserting no two circularly-adjacent sectors share a fill tone.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add a parametrized adjacency test across the valid sector-count range (`diagrams.test.tsx` — could not be run in the review worktree, `node_modules`/vitest not installed there; needs running in the real dev environment).
- [ ] Documentation to update: none required beyond this log entry.
- [x] Code changes required (tone assignment fixed).

## Related Issues
- Reviewed alongside PR #171 (construction angle-label collision) and PR #172 (Zimbabwe map), both from the same diagram-kinds review batch; see `reports/HBEC-2026-11-23-pr-168-to-176-review-batch.md`.

## References
- PR: https://github.com/Rest-creator/HBEC/pull/170

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session)
**Time to Resolution:** Caught and fixed before merge, same review session
