# Concurrent saves bypass file cap and fail duplicate requests

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development source review; staging and production not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
PR #118 checks for an existing file and counts the learner's rows before inserting. Separate requests can both observe no duplicate and fewer than 500 rows. Identical uploads race into the unique constraint and one returns an uncaught database error; different uploads at the cap can both commit and exceed 500.

## Symptoms
- Two tabs saving the same file may produce a 500 instead of already_saved. Two distinct saves when 499 files exist may create 501 files.

## Environment Details
- **Server/Host:** Local checkout and fetched PR heads.
- **Services Affected:** Database and State.
- **Related Components:** PR #118; AGENTIC_HARNESS/app/shared/learner_files.py:110-147; AGENTIC_HARNESS/alembic/versions/045_add_learner_files.py
- **Time First Observed:** 2026-11-08 PR review.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #117 and #118 diffs and adjacent runtime code.

### 2. Root Cause Analysis
Traced the changed operation through its data, request, or deployment boundary.

### 3. Key Findings
- Two tabs saving the same file may produce a 500 instead of already_saved. Two distinct saves when 499 files exist may create 501 files.
- This is source-level evidence; no target-environment rehearsal was performed.

## Root Cause
The duplicate and quota checks are read-then-write operations with no per-learner serialization or conflict handling.

## Prevention / Rule
**Guardrail:** Use a per-learner transactional lock or equivalent atomic quota reservation, plus an ON CONFLICT duplicate path; test concurrent same-file and near-cap saves with separate connections.

This guardrail exercises the failure path that the PR's current sequential or happy-path tests omit.

## Solution

### Immediate Fix
No fix made in this review. Make save atomic under concurrency and return the existing row for a duplicate.

### Long-term Fix
Keep the regression proof in CI and verify the exact deployed artifact before promotion.

## Prevention
- [ ] Add the guardrail above.
- [ ] Verify in staging with the intended migration and app revisions.
- [ ] Confirm the target environment after promotion.

## Related Issues
- PR #117 and PR #118 are stacked.

## References
- PR #118; AGENTIC_HARNESS/app/shared/learner_files.py:110-147; AGENTIC_HARNESS/alembic/versions/045_add_learner_files.py

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing
