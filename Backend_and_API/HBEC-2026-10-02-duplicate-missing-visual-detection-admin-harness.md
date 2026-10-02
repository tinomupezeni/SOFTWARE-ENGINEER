# Admin's New "Promised Visual" Detector Duplicates the Harness's Canonical One, With No Shared Contract

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
adds `review_flags()` to `ADMIN/adminBackend/apps/exam_papers/question_quality.py`
**Severity:** Low-Medium (drift risk between review-time and serve-time
"missing visual" warnings, not a crash)
**Status:** Investigating (flagged in PR review)

## Summary
PR #51 adds `PROMISED_VISUAL`/`STUDENT_DRAWS` regexes and a
"Refers to a figure or table that is not attached" warning inside
`question_quality.py::review_flags()` (new, admin backend). This duplicates
`AGENTIC_HARNESS/app/exam_practice/missing_visuals.py`'s `refers_to_a_visual()`
/ `missing_visual()`, which CLAUDE.md already documents as the canonical
detector for this exact problem ("Questions that promise a picture they do
not have"). The two regex sets differ in wording coverage — admin's covers
"melody"/"note"/"rest" and table-row phrasing the harness's does not, and
vice versa for "overleaf"/"on the right" etc. — and unlike the MCQ
inline-options feature in the same PR (tied together via
`contracts/mcq-inline-options/fixtures.json`), there is no shared contract or
test linking the two "missing visual" detectors.

Notably, the PR's own `planning/phases/interactive_components_build.md`
records that the intended fix was "Add the wider phrasings ... to
`missing_visuals.py`" — i.e. even the PR's own planning treats
`missing_visuals.py` as the one place this logic should live, then the admin
side was written as a separate implementation instead of routing through it.

## Symptoms
None in production yet. Would surface as: a question that the admin
reviewer flags as "promised visual, missing" differs from what the harness's
`missing_visual()` flags once the paper is live (and vice versa — e.g. the
table-row warning exists only on the admin side).

## Environment Details
- **Server/Host:** Admin Backend (Django, port 8002) + Harness (FastAPI, port 8080)
- **Services Affected:** admin review-hold warnings, student-facing
  "missing visual" honesty notice
- **Related Components:** `ADMIN/adminBackend/apps/exam_papers/question_quality.py`
  (`review_flags`, new), `AGENTIC_HARNESS/app/exam_practice/missing_visuals.py`
  (pre-existing, canonical)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Reuse angle of the PR review grepped `shared/`-style canonical detectors
for "missing visual" logic and found the admin side independently
reimplements it.

### 2. Root Cause Analysis
Diffed the two regex sets directly and confirmed they diverge in coverage
(see Summary). Confirmed no contract/fixture file ties them together, unlike
the MCQ inline-options pattern added in the same PR.

### 3. Key Findings
- The PR's own planning doc already identifies `missing_visuals.py` as the
  one true home for this logic, making this a known-but-unapplied lesson
  rather than an oversight no one considered.

## Root Cause
The admin review screen needed "does this question promise a visual it
doesn't have" before the harness module was reachable/importable from the
admin codebase (different services), so it was written fresh instead of
being factored into a shared location both services could use (or at least
contract-tested against each other).

## Prevention / Rule
**Guardrail:** either (a) extract the visual-reference wording list into a
shared, versioned data file both `missing_visuals.py` and
`question_quality.py` load, or (b) add a
`contracts/missing-visual-detection/fixtures.json` (same pattern as
`contracts/mcq-inline-options/`) with a test on each side asserting both
detectors agree on the fixture set, so future wording tuning on one side is
caught if not mirrored on the other.

## Solution

### Immediate Fix
None yet — flagged in PR #51 review.

### Long-term Fix
Add the shared contract/fixture as described above, and fold the admin
side's additional phrasings ("melody"/"note"/"rest", table-row detection)
into `missing_visuals.py` per the PR's own planning note.

## Prevention
- [ ] Add `contracts/missing-visual-detection/fixtures.json` with a test on
      both the admin and harness sides
- [ ] Fold admin-only phrasings into `missing_visuals.py`

## Related Issues
None.

## References
- `ADMIN/adminBackend/apps/exam_papers/question_quality.py:64`
- `AGENTIC_HARNESS/app/exam_practice/missing_visuals.py`
- `contracts/mcq-inline-options/fixtures.json` (the pattern this should follow)
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending fix
