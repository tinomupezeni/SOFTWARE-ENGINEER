# Job-Party Access Still Gated on Active Role Instead of New Capability Model

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Development (found in code review of PR #13, pre-merge)
**Severity:** High
**Status:** Investigating

## Summary
`_require_job_party` (duplicated in `jobs/domain/services.py` and `GetJobUseCase`) still gates offer-based job-party access on the caller's active role (`user_role == RoleEnum.WORKER`) rather than the new capability-based `Person.acts_as()` mechanism PR #13 introduced and applied to `RequireRole` and `BookJobUseCase`. This contradicts the PR's own stated goal that switching active mode should never remove the other side's access.

## Symptoms
- A dual-role account submits a job offer while in WORKER mode, then switches active mode to BUYER.
- They lose access to that job's chat/detail/messages even though they remain a live offer-party.

## Environment Details
- **Server/Host:** N/A (application logic)
- **Services Affected:** Job chat/detail/messages access
- **Related Components:** `backend/app/apps/messaging/domain/services.py:34`, `backend/app/apps/jobs/domain/services.py:71`, `GetJobUseCase`, `Person.acts_as()`
- **Time First Observed:** 2026-11-18, during code review of PR #13

## Investigation Steps

### 1. Initial Diagnosis
Code review noted PR #13 introduced `Person.acts_as()` as the new capability-based access rule and applied it to `RequireRole` and `BookJobUseCase`, but `_require_job_party` (duplicated in two files) was left on the old active-role check.

### 2. Root Cause Analysis
The PR migrated some but not all job-access gates to the new capability model, leaving a duplicated helper function on the superseded rule. The duplication itself means a fix applied to one copy could still miss the other.

### 3. Key Findings
- `_require_job_party` exists in at least two files (`messaging/domain/services.py` and `jobs/domain/services.py`) with the same stale logic.
- This is also the root cause behind the related unread-inbox leak ([[maritcho-2026-11-18-unread-inbox-leaks-across-active-role]]) and the search-filter bug ([[maritcho-2026-11-18-search-open-jobs-active-role-bug]]) — all three stem from inconsistent application of the new capability model across the codebase.

## Root Cause
Incomplete migration from active-role checks to the new `Person.acts_as()` capability model, compounded by duplicated helper logic across two files.

## Prevention / Rule
**Guardrail:** Before merging a PR that introduces a new access-control primitive (here, `Person.acts_as()`), require a repo-wide grep/lint check confirming no remaining occurrences of the old pattern (`user_role == RoleEnum.WORKER` / `RoleEnum.BUYER` used for authorization) exist outside of the new mechanism, and deduplicate `_require_job_party` into a single shared function first.

This closes the gap because the bug is a leftover of the old pattern coexisting with the new one; a repo-wide check at review time would have caught every surviving instance instead of catching them one at a time as separate bug reports.

## Solution

### Immediate Fix
Not yet applied — PR #13 is under review, changes requested.

### Long-term Fix
Deduplicate `_require_job_party` into one shared function and migrate it to use `Person.acts_as()`, consistent with `RequireRole` and `BookJobUseCase`.

## Prevention
- [ ] Code changes required (dedupe + migrate `_require_job_party`)
- [ ] Documentation to update (capability-model migration checklist)

## Related Issues
- [[maritcho-2026-11-18-unread-inbox-leaks-across-active-role]]
- [[maritcho-2026-11-18-search-open-jobs-active-role-bug]]
- [[maritcho-2026-11-18-rolegate-silent-role-switch]]

## References
- PR #13 (Maritcho, `experimental` -> `main`)

---

**Resolved By:** Pending
**Time to Resolution:** N/A
