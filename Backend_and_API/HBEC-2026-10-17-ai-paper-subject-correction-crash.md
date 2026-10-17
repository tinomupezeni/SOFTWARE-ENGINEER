# AI Paper Subject Correction Crashes Before Harness Sync

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Code review (PR #100)
**Severity:** High
**Status:** Investigating

## Summary
The new admin endpoint for correcting an AI paper's subject saves the
Student Backend change, then calls `notify_harness_of_subject()`. That helper
reads `subject.level`, but the Student Backend `Subject` model has no such
field; level is represented by the related `Grade`. Every correction for a
paper with a harness copy therefore raises `AttributeError` after the local
write and before the harness copy is updated.

## Symptoms
- Admin subject-correction requests return HTTP 500 instead of a successful
  response.
- The Student Backend paper is moved to the new subject while the Harness
  paper remains under the old subject.
- Subsequent marking or generation can use inconsistent subject metadata.

## Environment Details
- **Server/Host:** PR #100 code path
- **Services Affected:** Student Backend, Agentic Harness, Admin Frontend
- **Related Components:** `apps/internal/ai_papers_admin.py`, AI paper subject
  synchronization endpoint
- **Time First Observed:** 2026-10-17 review

## Investigation Steps

### 1. Initial Diagnosis
Traced the Admin UI subject correction request through the Student Backend
mutation and the Harness synchronization call.

### 2. Root Cause Analysis
The Student Backend calls:

```python
level=subject.level or ""
```

The Student Backend `Subject` model has `grade`, `code`, and related
curriculum fields, but no `level` attribute. The Harness endpoint expects a
separately supplied normalized `level`.

### 3. Key Findings
- The local Student Backend mutation is committed before synchronization.
- `AttributeError` is not covered by the `httpx` exception handlers.
- The failure creates cross-service divergence while the API reports failure.

## Root Cause
The new cross-service contract used a field name that does not exist on the
Student Backend subject model and did not derive the Harness level from the
subject's related grade.

## Prevention / Rule
**Guardrail:** Add a contract test that constructs a real Student Backend
`Subject` and verifies the subject-correction request derives and sends the
canonical grade-to-level value accepted by the Harness endpoint.

This catches model-field drift at test time and proves the producer payload
against the consumer contract instead of relying on similarly named fields.

## Solution

### Immediate Fix
No fix was applied during the read-only PR review.

### Long-term Fix
Derive the normalized level from `subject.grade` using the repository's
canonical mapping, then make synchronization retryable or reconcileable after
the local mutation succeeds.

## Prevention
- [ ] Add producer/consumer contract coverage for the subject-correction path
- [ ] Add a reconciliation or durable retry path for failed Harness updates
- [ ] Add an integration test covering a successful local mutation followed by
      Harness synchronization

## Related Issues
- PR #100 review: Maths, OCR, production fixes, message visibility and support
  ticketing

## References
- `STUDENT/hbec_backend/apps/internal/ai_papers_admin.py:155-194`
- `STUDENT/hbec_backend/apps/internal/ai_papers_admin.py:238-250`
- `STUDENT/hbec_backend/apps/curriculum/models.py:100-124`
- `AGENTIC_HARNESS/app/exam_practice/router.py:312-350`

---

**Resolved By:** Unresolved
**Time to Resolution:** N/A
