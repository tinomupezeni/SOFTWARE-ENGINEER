# New worker-directory endpoints missing the RequireRole guard every sibling endpoint has

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Medium
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
The new `GET /workers` (`list_nearby_workers`) and `GET /workers/{worker_id}`
(`get_worker_public_profile`) endpoints in
`backend/app/apps/workers/interface_adapters/router.py` (lines 185/189 and 216/219) depend on the
generic `get_current_user` (any authenticated role), while every other endpoint in the same file —
`register_skill`, `list_my_skills`, `register_service_area`, `get_my_standing`, `get_my_vetting`,
`submit_id_photo`, `add_reference`, `vouch_for_worker`, etc. — depends on `RequireRole([RoleEnum.WORKER])`.
Neither `ListNearbyWorkersUseCase.execute` nor `GetWorkerPublicProfileUseCase.execute` takes a
`current_user_id`/`role` parameter to perform internal gating either, so this is not an
intentionally-ambient-auth design like other `get_current_user` endpoints in the jobs app (which do
pass `current_user.id`/`current_user.role` into their use cases for internal ownership checks) — it is
simply unguarded. Any authenticated WORKER account can currently browse the full worker directory and
every other worker's "public" profile, a feature whose own docstring and frontend wiring
(`frontend/src/app/employer/workers/*`) indicate it was meant for employers/buyers only.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Any WORKER-role account can call `GET /workers` and `GET /workers/{worker_id}` and receive full
  results, with no error, despite the feature being presented only under employer-scoped frontend
  routes.

## Environment Details
- **Server/Host:** N/A (backend FastAPI service)
- **Services Affected:** Worker directory / public profile endpoints
- **Related Components:** `backend/app/apps/workers/interface_adapters/router.py`,
  `ListNearbyWorkersUseCase`, `GetWorkerPublicProfileUseCase`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding flagged that the two new directory endpoints use `get_current_user` instead of
`RequireRole`, unlike every other endpoint in the file, and asked whether this was a deliberate
"public profile" design or an oversight.

### 2. Root Cause Analysis
- Read every endpoint in `workers/interface_adapters/router.py` and its auth dependency: every
  mutating/sensitive endpoint uses `RequireRole([RoleEnum.WORKER])`; the two new directory endpoints
  use bare `get_current_user`.
- Compared against the established `get_current_user`-without-role-guard pattern elsewhere
  (`jobs/interface_adapters/router.py`), where that pattern is only used when the use case itself
  receives `current_user.id`/`current_user.role` and performs internal ownership/role authorization.
  `ListNearbyWorkersUseCase.execute`/`GetWorkerPublicProfileUseCase.execute` take no such parameter —
  confirmed by reading `backend/app/apps/workers/domain/services.py` — so there is zero internal
  gating here.
- `ListNearbyWorkersUseCase`'s own docstring reads "List workers for the employer directory, ranked by
  closeness..." and the frontend only exposes this feature under
  `frontend/src/app/employer/workers/page.tsx` / `[workerId]/page.tsx` — no worker-side directory
  route exists.
- The only test added for these endpoints
  (`backend/tests/test_worker_registration.py::test_buyer_can_browse_nearby_workers_and_view_public_profile`)
  exercises buyer access exclusively; no test exercises or locks in WORKER-role access.

### 3. Key Findings
- No docstring, comment, or OpenAPI tag anywhere states WORKER accounts should be able to browse the
  directory.
- The feature's own naming ("employer directory") and frontend wiring both point to buyer-only intent.

## Root Cause
The new router file copied the `get_current_user` dependency pattern used elsewhere in the same
codebase for internally-gated endpoints, without also copying the internal gating (passing
`current_user.role` into the use case) or adding the `RequireRole([RoleEnum.BUYER])` guard that the
feature's own docstring and frontend scoping imply was intended.

## Prevention / Rule
**Guardrail:** A CI/lint check (or code-review checklist item) that flags any new endpoint in
`*/interface_adapters/router.py` using `Depends(get_current_user)` without either (a) a `RequireRole`
guard, or (b) `current_user.id`/`current_user.role` being passed into the use case it calls — both of
these new endpoints have neither.

This directly targets the Root Cause: the gap is mechanically detectable (a `get_current_user`
dependency whose return value is never forwarded to the use case for internal authorization, and no
`RequireRole` alongside it), so a rule checking for exactly that pattern would have caught this before
merge.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed authorization gap found during review of PR #12;
it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Add `Depends(RequireRole([RoleEnum.BUYER]))` to both `list_nearby_workers` and
  `get_worker_public_profile`, consistent with the feature's documented "employer directory" intent —
  or, if worker-side browsing is actually desired going forward, make that explicit via a docstring,
  a test asserting WORKER access is allowed, and a product decision recorded in an ADR.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — add an ADR if worker-side access is ever intentionally allowed
- [x] Code changes required — add `RequireRole([RoleEnum.BUYER])` to both endpoints (not yet
      implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced these
  endpoints.

## References
- `backend/app/apps/workers/interface_adapters/router.py:185,189,216,219`
- `backend/app/apps/workers/domain/services.py` (`ListNearbyWorkersUseCase`, `GetWorkerPublicProfileUseCase`)
- `frontend/src/app/employer/workers/page.tsx`, `frontend/src/app/employer/workers/[workerId]/page.tsx`
- `backend/tests/test_worker_registration.py::test_buyer_can_browse_nearby_workers_and_view_public_profile`
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
