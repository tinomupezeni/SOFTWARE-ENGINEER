# Coding practical level scope is controlled by the caller

**Date:** 2026-11-07
**Project:** HBEC
**Environment:** PR #113 source review; production not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
The coding practical catalogue filters tasks using a caller-supplied `level` query parameter, and the check endpoint runs any known task without checking the authenticated learner's level. A learner can request an A-Level task list or submit an A-Level task ID regardless of their assigned level, despite the PR's level-scoping claim.

## Symptoms
- `GET /coding/tasks?level=...` trusts the requested level for filtering.
- `POST /coding/tasks/{task_id}/check` uses `get_student_id` but has no level check before running or recording the task.
- The behavior is source-derived; no live learner account was used.

## Environment Details
- **Server/Host:** PR head `1c96d3057` (#113).
- **Services Affected:** Agentic Harness interactive-learning coding practicals.
- **Related Components:** Task catalogue, runner invocation, learner event emission.
- **Time First Observed:** 2026-11-07 code review.

## Investigation Steps

### 1. Initial Diagnosis
Read the catalogue and check routes with their tests.

### 2. Root Cause Analysis
The server has only a student ID in these handlers and never resolves the learner's assigned level. The test fixture supplies arbitrary levels and only checks the filter's behavior for those inputs.

```bash
git show origin/review-pr-113:AGENTIC_HARNESS/app/interactive_learning/coding/router.py
git show origin/review-pr-113:AGENTIC_HARNESS/tests/interactive_learning/test_coding_router.py
```

### 3. Key Findings
- Level scoping is a client display choice, not an authorization or evidence boundary.
- The check path permits any known task ID even when the catalogue would omit it for the learner's level.

## Root Cause
Task level policy is derived from untrusted request input and omitted from the write path.

## Prevention / Rule
**Guardrail:** Add an authenticated API test for a lower-level learner that requests an A-Level catalogue and submits an A-Level task ID, asserting both are refused or scoped to the server-owned level. This catches a display-only filter.

## Solution

### Immediate Fix
Pending on PR #113; review recommendation is to resolve the learner's level server-side before listing or accepting a task.

```bash
# No fix applied in this read-only review.
```

### Long-term Fix
Use the authenticated learner context as the level source and enforce the same policy in the list and check endpoints.

## Prevention
- [ ] Add negative cross-level API tests.
- [ ] Enforce server-owned level in both routes.
- [ ] Verify the learner event path cannot record an out-of-level task.

## Related Issues
- `Backend_and_API/HBEC-2026-11-07-coding-practical-attempts-client-controlled.md`
- PR #113.

## References
- `AGENTIC_HARNESS/app/interactive_learning/coding/router.py` in PR #113, lines 112–144.

---

**Local fix prepared:** PR #113 repair branch `fix/pr113-review` derives grade and academic level from signed learner identity for both listing and checking. Cross-level POST is rejected before runner invocation or attempt recording. Focused coding route tests passed locally (8/8); production verification remains pending.

**Resolved By:** Pending production verification
**Time to Resolution:** Ongoing
