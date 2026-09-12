# A Stale Celery Retry Reset an Already-Successful Admin Paper Back to Draft

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
While watching a real 5-paper admin batch complete live, a queued Celery
retry fired after a different invocation of the same logical task had
already succeeded, collided with its own prior success on save, and reset
a perfectly good, already-reviewed paper back to `Draft` — even though its
real questions were still sitting untouched in the database.

## Symptoms
- A paper that had just shown `Review` status with 9 real questions
  flipped back to `Draft` a short time later, with no user action.
- Harness logs showed a fresh `UniqueViolationError` on the same paper
  identity that had already saved successfully moments earlier.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Admin Backend (`generate_ai_paper_via_harness` Celery task)
- **Time First Observed:** 2026-09-09, while live-monitoring a real admin batch

## Investigation Steps

### 1. Initial Diagnosis
Confirmed via `ExamPaperQuestion` row counts that no data was lost or
duplicated — only the `status` field flapped back to `Draft`.

### 2. Root Cause Analysis
Several retries had queued back to back (60s apart) during the earlier
GPU-timeout outages fixed earlier in this same session. Once those
underlying issues were fixed, one attempt succeeded — but earlier queued
retries for the *same* logical task hadn't all fired yet. When one of them
finally ran, it re-attempted generation for a paper that was already
`Review`, its own harness-side save collided with the row the earlier
attempt had already created, and the task's `except` block unconditionally
reset `status` to `Draft` on any harness failure — with no check for
"is this paper already done."

### 3. Key Findings
- A task designed to retry on transient failure needs to also be safe to
  re-run after a *different* invocation of itself has already succeeded —
  retry safety and idempotency are two different properties, and this task
  only had the first one.

## Root Cause
`generate_ai_paper_via_harness` had no idempotency guard — it would
unconditionally re-attempt generation and, on any failure, unconditionally
reset status, regardless of whether the paper had already succeeded via a
different invocation.

## Prevention / Rule
**Guardrail:** Every retryable Celery task whose failure path mutates shared state must check "is the target already in a terminal/complete state" before mutating it — codified as a required item in this project's task-writing checklist for any new retryable task, not fixed ad hoc per incident.

Retry-safety and idempotency are two different properties; this task had the first without the second, and nothing in the task-authoring process required both.

## Solution

### Immediate Fix
Manually restored the two affected papers' status to `Review` once
confirmed their real question data was intact.

### Long-term Fix
Added a guard at the top of the task: if the paper's status is already
`Review`, `Approved`, or `Published`, skip regeneration entirely and return
`skipped_already_complete` rather than re-running. 4 new tests: skip on
each of those three statuses, and confirm a genuinely fresh/failed (`Draft`)
paper still generates normally.

## Prevention
- [x] Idempotency guard with test coverage
- [ ] Consider Celery task de-duplication (e.g. a lock keyed on `paper_id`)
      as a second layer, so overlapping *concurrent* invocations (not just
      stale sequential retries) can't race each other either

## Related Issues
- Downstream consequence of the litellm timeout and staging OOM issues
  fixed earlier in the same session — those caused the retry backlog that
  exposed this gap

## References
- `ADMIN/adminBackend/apps/exam_papers/tasks.py`
- `ADMIN/adminBackend/apps/exam_papers/tests/test_generate_ai_paper_task.py`
- Commit `a6ebebb2`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
