# Saved files can reappear after account deletion

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development source review; staging and production not exercised
**Severity:** High
**Status:** Investigating

## Summary
PR #118 deletes saved files once when account_deleted reaches the harness, but the direct save route can still accept a previously issued learner JWT afterward. Session revocation is cached for 30 seconds and fails open; a save after the erasure commit recreates a learner_files row with no later deletion event.

## Symptoms
- A deleted account can retain a newly saved personal file if an in-flight or stale-token save commits after the one erasure. The frontend claims files are kept only while the account exists.

## Environment Details
- **Server/Host:** Local checkout and fetched PR heads.
- **Services Affected:** Backend and API.
- **Related Components:** PR #118; AGENTIC_HARNESS/app/analytics/inbox.py:225-258; AGENTIC_HARNESS/app/api/routes/learner_files.py:94-119; AGENTIC_HARNESS/app/shared/session_epoch.py:32-72
- **Time First Observed:** 2026-11-08 PR review.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #117 and #118 diffs and adjacent runtime code.

### 2. Root Cause Analysis
Traced the changed operation through its data, request, or deployment boundary.

### 3. Key Findings
- A deleted account can retain a newly saved personal file if an in-flight or stale-token save commits after the one erasure. The frontend claims files are kept only while the account exists.
- This is source-level evidence; no target-environment rehearsal was performed.

## Root Cause
Account deletion and file creation are coordinated only by a one-time asynchronous erasure; no durable tombstone or write fence prevents later inserts.

## Prevention / Rule
**Guardrail:** Persist a deletion tombstone in the harness and reject or erase all later saves for that student; test both event-before-save and save-before-event orderings.

This guardrail exercises the failure path that the PR's current sequential or happy-path tests omit.

## Solution

### Immediate Fix
Migration 045 adds a durable learner_file_erasures tombstone. Saves and erasure share a per-learner PostgreSQL transaction lock; the save path rejects a tombstoned account, and the erasure commits the tombstone and file deletion together. Database regressions cover saves after erasure.

### Long-term Fix
Keep the regression proof in CI and verify the exact deployed artifact before promotion.

## Prevention
- [x] Add the guardrail above.
- [ ] Verify in staging with the intended migration and app revisions.
- [ ] Confirm the target environment after promotion.

## Related Issues
- PR #117 and PR #118 are stacked.

## References
- PR #118; AGENTIC_HARNESS/app/analytics/inbox.py:225-258; AGENTIC_HARNESS/app/api/routes/learner_files.py:94-119; AGENTIC_HARNESS/app/shared/session_epoch.py:32-72

---

**Resolved By:** Local code fix in 9d5e6a220; target deployment pending
**Time to Resolution:** Local implementation and validation on 2026-11-08; staging and production pending
