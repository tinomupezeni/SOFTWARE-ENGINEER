# Regraded learner reads later-grade live mastery as current

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development source review; staging and production not exercised
**Severity:** High
**Status:** Investigating

## Summary
PR #117 filters topic_mastery_history to earlier grades, but get_mastery always returns the one live topic_mastery row without comparing its grade to the learner's bound grade. A learner moved from Form 4 back to Form 3 sees Form 4 mastery as current until a tracker write settles the row.

## Symptoms
- GET/read-only tutor context immediately after regrading returns the later grade's mastery_level, practice_count, and mistakes; the test only reads after a Form 3 practice write.

## Environment Details
- **Server/Host:** Local checkout and fetched PR heads.
- **Services Affected:** Backend and API.
- **Related Components:** PR #117; AGENTIC_HARNESS/app/analytics/topic_mastery.py:102-140,142-171; AGENTIC_HARNESS/tests/analytics/test_mastery_grade_history.py
- **Time First Observed:** 2026-11-08 PR review.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #117 and #118 diffs and adjacent runtime code.

### 2. Root Cause Analysis
Traced the changed operation through its data, request, or deployment boundary.

### 3. Key Findings
- GET/read-only tutor context immediately after regrading returns the later grade's mastery_level, practice_count, and mistakes; the test only reads after a Form 3 practice write.
- This is source-level evidence; no target-environment rehearsal was performed.

## Root Cause
The later-grade guard applies only to history rows, while the live row is read unconditionally.

## Prevention / Rule
**Guardrail:** Add a regression that regrades Form 4 to Form 3 and calls get_mastery before any write; require the live row's grade to be checked on every read.

This guardrail exercises the failure path that the PR's current sequential or happy-path tests omit.

## Solution

### Immediate Fix
get_mastery reads the current grade snapshot when the live row belongs to a later grade. Writers restore the destination grade’s prior state, or start an empty earlier grade when none exists; returning to a later grade restores its own state. Real PostgreSQL round-trip regression tests passed.

### Long-term Fix
Keep the regression proof in CI and verify the exact deployed artifact before promotion.

## Prevention
- [x] Add the guardrail above.
- [ ] Verify in staging with the intended migration and app revisions.
- [ ] Confirm the target environment after promotion.

## Related Issues
- PR #117 and PR #118 are stacked.

## References
- PR #117; AGENTIC_HARNESS/app/analytics/topic_mastery.py:102-140,142-171; AGENTIC_HARNESS/tests/analytics/test_mastery_grade_history.py

---

**Resolved By:** Local code fix in 9d5e6a220; target deployment pending
**Time to Resolution:** Local implementation and validation on 2026-11-08; staging and production pending
