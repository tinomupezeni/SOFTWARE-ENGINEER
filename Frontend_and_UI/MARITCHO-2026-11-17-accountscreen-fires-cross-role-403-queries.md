# AccountScreen fires role-mismatched queries despite a comment claiming they're gated

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Low
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
In `frontend/src/features/accounts/AccountScreen.tsx`, a comment at line 90 reads "Worker-only queries
(gated by role to avoid 403s for employers)," and several hooks on the following lines are correctly
passed `isWorker` (e.g. `useStanding(isWorker)`). But `useAssignedJobs()` (line 96) and `useMyOffers()`
(line 97) are called with no argument, and under a separate "Employer-only queries" comment (line 99),
`useMyJobs()` (line 100) is also called with no argument. In `frontend/src/features/jobs/hooks.ts`, all
three hooks default their `isEnabled` parameter to `true` when omitted — so every employer account
unconditionally fires the WORKER-only `useAssignedJobs`/`useMyOffers` requests, and every worker
account unconditionally fires the BUYER-only `useMyJobs` request, on every Account screen load,
contradicting the comments' own stated intent.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Every Account screen load issues 2-3 guaranteed cross-role requests that the backend rejects with
  403, for every user, every time — wasted round trips against this project's "small data bundles /
  inexpensive Android devices" design constraint.

## Environment Details
- **Server/Host:** N/A (Next.js frontend)
- **Services Affected:** Account screen (`/worker/account`, `/employer/account`)
- **Related Components:** `AccountScreen.tsx`, `jobs/hooks.ts` (`useMyJobs`, `useAssignedJobs`,
  `useMyOffers`)
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding noted the inconsistency between the comment's stated intent and the actual
(ungated) hook calls, and that sibling hooks on adjacent lines were correctly gated.

### 2. Root Cause Analysis
- `AccountScreen.tsx`: `// Worker-only queries (gated by role to avoid 403s for employers)` precedes
  `useStanding(isWorker)` ... `useServiceAreas(isWorker)`, then `useAssignedJobs()` and
  `useMyOffers()` with zero arguments. `// Employer-only queries` precedes `useMyJobs()`, also with
  zero arguments.
- `jobs/hooks.ts`: `useMyJobs(isEnabled: boolean = true)` (line 49), `useAssignedJobs(isEnabled: boolean = true)`
  (line 153), `useMyOffers(isEnabled: boolean = true)` (line 162) — omitting the argument is equivalent
  to passing `true`, so these queries always fire regardless of role.
- Backend confirms the 403 consequence: `GET /jobs/mine` requires `RequireRole([RoleEnum.BUYER])`,
  `GET /jobs/assigned` and `GET /jobs/my-offers` require `RequireRole([RoleEnum.WORKER])`
  (`backend/app/apps/jobs/interface_adapters/router.py`), and `RequireRole.__call__` raises
  `HTTPException(403, ...)` when the role doesn't match.

### 3. Key Findings
- A BUYER loading AccountScreen unconditionally calls `/jobs/assigned` and `/jobs/my-offers`
  (WORKER-only → 403 each).
- A WORKER loading AccountScreen unconditionally calls `/jobs/mine` (BUYER-only → 403).

## Root Cause
Three hook calls were added to the same block as several correctly-gated sibling hooks, but the
`isWorker`/role argument was omitted for these three specifically — most likely a copy-paste of the
hook call without carrying over the gating argument used by its neighbors.

## Prevention / Rule
**Guardrail:** Change `useMyJobs`, `useAssignedJobs`, and `useMyOffers` in `jobs/hooks.ts` to require
the `isEnabled` argument (no default value) rather than defaulting to `true` — making the call site a
TypeScript compile error if the gate is omitted, instead of a silently-always-on query.

This closes the Root Cause directly: a required parameter forces every call site (present and future)
to make an explicit choice about gating, so a copy-paste that drops the argument fails to compile
instead of silently firing an unconditional, cross-role-403-prone request.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed (if low-severity) bug found during review of
PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Pass `!isWorker` to `useMyJobs()` and `isWorker` to `useAssignedJobs()`/`useMyOffers()` in
  `AccountScreen.tsx`, matching the pattern already used by `useStanding`/`useWorkerVetting`/etc.
- Remove the default value from `isEnabled` in all three hooks per the guardrail above.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — none
- [x] Code changes required — gate the three hook calls by role in `AccountScreen.tsx` (not yet
      implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced these hook
  calls.

## References
- `frontend/src/features/accounts/AccountScreen.tsx:90-100`
- `frontend/src/features/jobs/hooks.ts:49,153,162`
- `backend/app/apps/jobs/interface_adapters/router.py` (`RequireRole` on `/jobs/mine`,
  `/jobs/assigned`, `/jobs/my-offers`)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
