# search_open_jobs Skill Filter Uses Active Role Instead of Capability Check

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Development (found in code review of PR #13, pre-merge)
**Severity:** High
**Status:** Resolved

## Summary
`is_worker = current_user.role == RoleEnum.WORKER` in `search_open_jobs` is new code added by PR #13, but it uses active-mode semantics instead of the capability-based `.acts_as()` check applied to every other role gate the PR touched. This defeats the new skill-matching/eligibility feature for exactly the account type (dual-role) the PR was built to support.

## Symptoms
- A dual-role account with registered WORKER skills searches jobs while in BUYER active mode.
- `is_worker` evaluates false, so the new skill-eligibility filter is skipped entirely.
- The account sees all open jobs unfiltered by trade — no test covers this combination.

## Environment Details
- **Server/Host:** N/A (application logic)
- **Services Affected:** Job search/matching
- **Related Components:** `backend/app/apps/jobs/interface_adapters/router.py:176`, `evaluate_job_eligibility`
- **Time First Observed:** 2026-11-18, during code review of PR #13

## Investigation Steps

### 1. Initial Diagnosis
Code review found this line was new in the diff and inconsistent with the `.acts_as()` pattern used elsewhere in the same PR.

### 2. Root Cause Analysis
Same class of bug as [[maritcho-2026-11-18-job-party-active-role-vs-capability]]: a new piece of logic written against the old active-role model instead of the new capability model, in code introduced by the same PR that defines the capability model.

### 3. Key Findings
- No test exercises a dual-role account in BUYER mode with WORKER skills calling job search.
- The bug silently degrades (returns unfiltered results) rather than erroring, making it hard to notice without an explicit test.

## Root Cause
New code (`is_worker` check) was written using the legacy active-role pattern instead of the capability-based `.acts_as()` pattern this same PR introduced.

## Prevention / Rule
**Guardrail:** Add a test case covering a dual-role account acting as BUYER with registered WORKER skills calling `search_open_jobs`, asserting the skill filter still applies; add this scenario to the standard dual-role test matrix referenced by [[maritcho-2026-11-18-job-party-active-role-vs-capability]]'s repo-wide grep check.

This closes the gap because the bug was invisible precisely because no test combined "dual-role" with "opposite active mode" for this endpoint; a required test matrix entry for that combination catches it going forward.

## Solution

### Immediate Fix
Replaced `current_user.role == RoleEnum.WORKER` with `current_user.acts_as(RoleEnum.WORKER)` in `search_open_jobs`.

### Long-term Fix
Done — see Immediate Fix. A dual-role-in-BUYER-mode-with-WORKER-skills test case for this endpoint is still not added; left as a follow-up (test matrix gap, not a merge blocker on its own now that the production bug is fixed).

## Prevention
- [ ] Code changes required
- [ ] Documentation to update (test matrix for dual-role accounts)

## Related Issues
- [[maritcho-2026-11-18-job-party-active-role-vs-capability]]

## References
- PR #13 (Maritcho, `experimental` -> `main`)

---

**Resolved By:** Pending
**Time to Resolution:** N/A
