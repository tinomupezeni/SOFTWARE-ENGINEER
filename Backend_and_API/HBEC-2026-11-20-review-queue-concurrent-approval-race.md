# Review Queue Approve/Reject Check-Then-Act Race Condition Allows Double Publishing or Post-Approval Retraction

**Date:** 2026-11-20
**Project:** HBEC
**Environment:** Development / Staging / Production
**Severity:** Medium
**Status:** Resolved

## Summary
In `ADMIN/adminBackend/apps/ingestion/views.py`, the `ReviewQueueItemView.post` endpoint validated paper status with a non-atomic check (`if paper.status != ExamPaper.Status.REVIEW:`), followed by an un-locked update (`paper.status = ...; paper.save(...)`). Under concurrent requests (e.g. duplicate user click or two editors reviewing simultaneously), both requests observed `REVIEW` state and performed state transitions, resulting in duplicate publishing calls to `ExamPaperStatusView()._publish_paper()` or a race where a paper approved and published was immediately reverted to `DRAFT` by a concurrent reject action.

## Symptoms
- Potential double publishing to Redis stream and duplicated AI embeddings activation calls.
- Inconsistent state where a published paper could transition to draft without going back through review.
- Lack of concurrency protection on state transitions in the ingestion review queue.

## Environment Details
- **Server/Host:** hbca-vps / admin backend
- **Services Affected:** `ADMIN/adminBackend`
- **Related Components:** `apps/ingestion/views.py`, `apps/exam_papers/lifecycle.py`
- **Time First Observed:** 2026-11-20 (Code Review of PR #162)

## Investigation Steps

### 1. Initial Diagnosis
Inspected PR #162 diff in `ADMIN/adminBackend/apps/ingestion/views.py`. Noticed `ReviewQueueItemView.post` checked `paper.status != ExamPaper.Status.REVIEW` but saved changes without a database lock or conditional update.

### 2. Root Cause Analysis
Between reading `paper.status` and saving the new status, another thread/process could update `paper.status`. Django ORM's standard `save(update_fields=['status', 'updated_at'])` unconditionally overwrote the column without verifying that the status remained `REVIEW` at execution time.

## Root Cause
Check-then-act race condition in status transition logic without row-level locking (`select_for_update`) or atomic conditional update (`filter(status=REVIEW).update(...)`).

## Prevention / Rule
**Guardrail:** Every state machine transition in Django ORM must be executed either inside a `transaction.atomic()` block with `select_for_update()`, or via an atomic conditional update (`filter(status=EXPECTED_STATE).update(...)`) asserting that exactly one row was affected.

## Solution

### Immediate Fix
Implemented `_claim(paper, target)` on `ReviewQueueItemView`:
```python
@staticmethod
def _claim(paper, target):
    now = timezone.now()
    moved = ExamPaper.objects.filter(pk=paper.pk, status=ExamPaper.Status.REVIEW).update(
        status=target, updated_at=now
    )
    if moved:
        paper.status = target
        paper.updated_at = now
    return bool(moved)
```
If `_claim` returns `False`, the view immediately returns HTTP 409 Conflict. Added regression test `test_a_concurrent_reviewer_who_got_there_first_wins_and_the_second_gets_409` in `apps/exam_papers/tests/test_review_queue_publish_gate.py`.

### Long-term Fix
Ensure all lifecycle transition handlers throughout admin and student backends utilize atomic state transition assertions.

## Prevention
- [x] Code changes required (`apps/ingestion/views.py`)
- [x] Concurrency regression test added (`test_review_queue_publish_gate.py`)
- [ ] Audit remaining state transitions across all DRF views

## Related Issues
- PR #162 (`refactor/explicit-state-machines`)
- `DevOps_and_Infrastructure/HBEC-2026-11-20-schools-backend-has-no-readiness-probe.md`

---

**Resolved By:** Antigravity (Claude / Gemini)
**Time to Resolution:** 30 minutes
