# Withdrawn: AI Paper Subject Correction Finding

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Code review (PR #100)
**Severity:** Informational
**Status:** Withdrawn

## Summary
This finding from the initial PR review was withdrawn after rechecking the PR
ref. The Student Backend `Subject` model does define a `level` field, so the
reported `AttributeError` does not occur on this path.

## Symptoms
- No production or code defect was confirmed.

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

`Subject.level` is declared in
`STUDENT/hbec_backend/apps/curriculum/models.py:213-217`.

### 3. Key Findings
- The earlier finding was not reproducible from the actual PR source.

## Root Cause
The review finding was based on a false premise about the Student Backend
model.

## Prevention / Rule
**Guardrail:** Verify every review finding against the exact PR ref's model
definition before requesting changes.

This prevents a valid review from being blocked by a mismatch between the
reviewer's assumed model and the actual producer contract.

## Solution

### Immediate Fix
The review finding was withdrawn. No code fix is required.

### Long-term Fix
No follow-up is required for this finding.

## Prevention
- [x] Recheck the exact Student Backend model on the PR ref

## Related Issues
- PR #100 review: Maths, OCR, production fixes, message visibility and support
  ticketing

## References
- `STUDENT/hbec_backend/apps/internal/ai_papers_admin.py:155-194`
- `STUDENT/hbec_backend/apps/internal/ai_papers_admin.py:238-250`
- `STUDENT/hbec_backend/apps/curriculum/models.py:100-124`
- `AGENTIC_HARNESS/app/exam_practice/router.py:312-350`

---

**Resolved By:** Copilot
**Time to Resolution:** Same review session
