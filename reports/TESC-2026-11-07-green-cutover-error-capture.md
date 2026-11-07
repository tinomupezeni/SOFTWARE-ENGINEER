# Promote durable error capture to production traffic

**Date:** 2026-11-07
**Project:** TESC
**Type:** Deployment / Blue-Green Promotion
**Status:** Completed

## Summary
Promoted the verified green blue-green color to receive production traffic. Green runs artifact `0a1a76d`, which contains durable backend error capture, and the previous blue color remains running as the rollback target.

## Context / Trigger
The durable error-capture release was deployed and migration-applied to green. The user requested production traffic cutover after the artifact and smoke checks passed.

## Scope
Included nginx upstream cutover for the main frontend, institution frontend, and backend API routes. The old blue services were intentionally left running for rollback.

## Method
Verified the green marker, exact container image tags, observability migration, container readiness, pre-cutover routes, and recent green logs. Ran the repository cutover script with explicit confirmation, then repeated route, nginx-target, service, and log checks.

## Decisions & Findings
- Active color changed from blue to green.
- Green artifact: `0a1a76d`.
- Blue rollback artifact: `94bf94e`.
- `observability.0001_initial` is applied on green.
- Public traffic now routes to green through nginx.
- Blue remains healthy and available as the rollback target.

## Changes Made
- Executed `CONFIRM_CUTOVER=yes scripts/bluegreen-cutover.sh` on `tesc-prod`.
- Updated production `active_color` to `green`.
- Reloaded nginx after a successful configuration test.

## Verification
- Green backend, worker, main frontend, and institution frontend were running with `0a1a76d`.
- Nginx configuration test passed before reload.
- Main and institution host routes returned HTTP 200 after cutover.
- Nginx upstreams reference `backend-green`, `frontend-client-v2-green`, and `frontend-admin-v2-green`.
- Recent green backend and worker log windows contained no error/exception/traceback/failed matches.
- Blue services remained running for rollback.

## Follow-ups / Deferred
- Keep blue available until the agreed stability window completes.
- Stop blue only after post-cutover monitoring confirms stability.
- Continue with the Mutare source-spreadsheet reconciliation separately; it is not part of this deployment.

## References
- TESC commit `0a1a76d`
- `scripts/bluegreen-cutover.sh`
- `docker-compose.bluegreen.yml`
- `SOFTWARE-ENGINEER/reports/TESC-2026-11-07-durable-error-capture.md`

---

**Completed By:** Copilot
**Duration:** Same deployment session
