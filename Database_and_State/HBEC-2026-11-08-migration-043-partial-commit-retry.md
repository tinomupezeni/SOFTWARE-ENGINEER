# Migration 043 cannot retry after an interrupted concurrent index build

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development source review; staging and production not exercised
**Severity:** High
**Status:** Investigating

## Summary
PR #117 adds sixteen nullable columns, then enters an Alembic autocommit block to build eight indexes concurrently. Alembic commits the column additions before that block. If any index build fails, the revision is not recorded, but the columns remain; rerunning the migration fails on duplicate columns before it can repair indexes.

## Symptoms
- An interrupted CREATE INDEX CONCURRENTLY leaves migration 043 unapplied while its columns already exist; the next alembic upgrade fails with duplicate_column. IF NOT EXISTS only protects index creation, not the preceding add_column operations.

## Environment Details
- **Server/Host:** Local checkout and fetched PR heads.
- **Services Affected:** Database and State.
- **Related Components:** PR #117; AGENTIC_HARNESS/alembic/versions/043_add_learner_partitions.py:52-67; https://alembic.sqlalchemy.org/en/latest/api/runtime.html
- **Time First Observed:** 2026-11-08 PR review.

## Investigation Steps

### 1. Initial Diagnosis
Read PR #117 and #118 diffs and adjacent runtime code.

### 2. Root Cause Analysis
Traced the changed operation through its data, request, or deployment boundary.

### 3. Key Findings
- An interrupted CREATE INDEX CONCURRENTLY leaves migration 043 unapplied while its columns already exist; the next alembic upgrade fails with duplicate_column. IF NOT EXISTS only protects index creation, not the preceding add_column operations.
- This is source-level evidence; no target-environment rehearsal was performed.

## Root Cause
Nontransactional concurrent DDL and non-idempotent column creation were combined in one Alembic revision without a recovery path.

## Prevention / Rule
**Guardrail:** Split the nullable columns and concurrent indexes into separately versioned operations, or make the retry path inspect and reconcile existing columns and invalid indexes before DDL.

This guardrail exercises the failure path that the PR's current sequential or happy-path tests omit.

## Solution

### Immediate Fix
No fix made in this review. Rework migration 043 and rehearse failure after the first concurrent index build against disposable PostgreSQL 15, then rerun upgrade to head.

### Long-term Fix
Keep the regression proof in CI and verify the exact deployed artifact before promotion.

## Prevention
- [ ] Add the guardrail above.
- [ ] Verify in staging with the intended migration and app revisions.
- [ ] Confirm the target environment after promotion.

## Related Issues
- PR #117 and PR #118 are stacked.

## References
- PR #117; AGENTIC_HARNESS/alembic/versions/043_add_learner_partitions.py:52-67; https://alembic.sqlalchemy.org/en/latest/api/runtime.html

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing
