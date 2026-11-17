# Coding practical learner evidence trusts client-reported attempts

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #113 source review; production not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
The coding practical check endpoint accepts `attempts` from the request body and uses it to decide whether a passing program was correct on the first try. Any caller can send `attempts=1` after earlier failed checks, causing the learner timeline to record a demonstration instead of a struggle.

## Symptoms
- `CheckRequest.attempts` is caller-supplied (`ge=1`, `le=100`).
- A successful check emits `correct=body.attempts == 1` without server-side attempt state.
- The behavior is established by source; no production learner record was modified.

## Environment Details
- **Server/Host:** PR head `1c96d3057` (#113).
- **Services Affected:** Agentic Harness coding practicals and learner timeline.
- **Related Components:** `app/interactive_learning/coding/router.py`, analytics event consumer.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Read the coding request schema and event emission path.

### 2. Root Cause Analysis
The endpoint derives the learning signal from an untrusted client counter instead of persisted checks scoped to the learner, task, and language.

```bash
git show origin/review-pr-113:AGENTIC_HARNESS/app/interactive_learning/coding/router.py
```

### 3. Key Findings
- The tests demonstrate first and fourth attempts only by choosing request values.
- The check path does not verify previous attempts.
- The false first-try event can affect later adaptation based on the timeline.

## Root Cause
The server treats a display-side attempt count as authoritative learning evidence.

## Prevention / Rule
**Guardrail:** A coding API test must perform two checks for the same learner and task while sending `attempts=1` on both, then assert the second event is not recorded as a first-try success. This catches trust in client state.

## Solution

### Immediate Fix
Pending on PR #113; review recommendation is to derive attempt count from server-owned state before emitting evidence.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Store or derive attempts per authenticated learner and practical task, and make the evidence writer use that value. Keep the client count only for display if needed.

## Prevention
- [ ] Add a request-tampering regression test.
- [ ] Derive attempt count on the server.
- [ ] Verify timeline evidence after repeated checks.

## Related Issues
- PR #113.

## References
- `AGENTIC_HARNESS/app/interactive_learning/coding/router.py` in PR #113, lines 67–71 and 186–205.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` adds migration `042_coding_check_attempts` and atomic PostgreSQL attempt increments. The API ignores client `attempts` and derives `correct` from the persisted count. Focused coding route tests passed locally (8/8); production migration and user-path verification remain pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing
