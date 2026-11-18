# Naive utcnow() Timestamps Remain in Sign-off, Dispute, and ID-Photo Flows

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Development (found in code review of PR #13, pre-merge)
**Severity:** Medium
**Status:** Resolved

## Summary
PR #13 introduced `shared_kernel/clock.py` specifically to fix an offset-less-timestamp bug, but four call sites were missed: `signed_off_at`, `dispute.responded_at`, worker ID-photo submission timestamps, and a job review's `created_at` still used naive `datetime.utcnow()`. These were masked only by the web frontend's blanket `normalizeIsoDate` regex coercing offset-less ISO strings to UTC.

**Update (2026-11-18):** All four fixed — replaced with `shared_kernel.clock.utcnow()` in `jobs/domain/services.py` (signed_off_at, dispute.responded_at), `workers/domain/services.py` (ID-photo timestamp), and `jobs/interface_adapters/router.py:391` (review created_at, found while running the full test suite after the other fixes — same bug class, not in the original review). Status updated to Resolved.

## Symptoms
- Naive timestamps serialize through Pydantic schemas to clients with no UTC offset.
- Web frontend displays them correctly only due to a defensive regex normalization applied to all date fields.
- Any other consumer without that normalization (notably the Flutter mobile client, which already uses raw `DateTime.parse` elsewhere with no such normalization) would render these fields two hours early in UTC+2 — the exact bug this PR fixed for messaging timestamps.

## Environment Details
- **Server/Host:** N/A (application logic)
- **Services Affected:** Job sign-off, disputes, worker ID verification
- **Related Components:** `backend/app/apps/jobs/domain/services.py:724` (`signed_off_at`), `:813` (`dispute.responded_at`), `backend/app/apps/workers/domain/services.py:342` (ID-photo timestamp), `shared_kernel/clock.py`
- **Time First Observed:** 2026-11-18, during code review of PR #13

## Investigation Steps

### 1. Initial Diagnosis
Code review noted PR #13 fixed the same bug class for messaging timestamps via a new `clock.py` helper but did not apply it everywhere `datetime.utcnow()` was previously used.

### 2. Root Cause Analysis
The fix was applied call-site-by-call-site rather than via a repo-wide replacement or a lint rule banning `datetime.utcnow()` outright, so sites outside the messaging feature were missed.

### 3. Key Findings
- The bug is currently invisible on web only because of an unrelated, blanket defensive normalization — not because the underlying data is correct.
- The Flutter mobile client is the concrete consumer that would be affected first, since it lacks equivalent normalization.

## Root Cause
Incomplete rollout of the new `shared_kernel/clock.py` UTC-aware timestamp helper — fixed in the messaging feature but not in sign-off, dispute, and ID-photo flows that have the identical bug.

## Prevention / Rule
**Guardrail:** Add a lint/CI rule (grep-based check or custom AST lint) that fails the build on any new or existing `datetime.utcnow()` call outside of `shared_kernel/clock.py` itself, forcing all call sites through the UTC-aware helper.

This closes the gap because the bug class was already identified and fixed once in this PR; a repo-wide ban on the unsafe call enforced in CI prevents it from surviving in any location, now or in the future.

## Solution

### Immediate Fix
Not yet applied — PR #13 is under review, changes requested.

### Long-term Fix
Replace the three remaining `datetime.utcnow()` calls with the `shared_kernel/clock.py` helper, and add the CI lint rule described above.

## Prevention
- [ ] Configuration changes needed (CI lint rule)
- [ ] Code changes required (3 call sites)

## Related Issues
- None

## References
- PR #13 (Maritcho, `experimental` -> `main`)

---

**Resolved By:** Pending
**Time to Resolution:** N/A
