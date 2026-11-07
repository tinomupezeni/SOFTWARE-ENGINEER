# TESC blue-green production deployment audit

**Date:** 2026-11-07
**Project:** TESC
**Type:** Audit
**Status:** Completed

## Summary
Audited the TESC repository's blue-green deployment model and the live
`tesc-prod` host over SSH. Public traffic is healthy on blue, but the inactive
green environment is not a coherent release and the documented backend health
observer is not wired to a real backend endpoint. No cutover or production
mutation was performed.

## Context / Trigger
The user requested a codebase review and a direct check of the blue-green
deployment on `tesc-prod`.

## Scope
Included repository deployment scripts, Compose definitions, nginx routing,
deployment documentation, live Docker state, image identity, migration plans,
dependency readiness, frontend assets, worker logs, and host capacity.
Excluded application feature behavior and authenticated business workflows
because no credentials or user journey were requested.

## Method
Compared the checked-in deployment contract with the live host over SSH;
inspected active-color and SHA markers, running container image references and
digests, rendered nginx parity, Django migration plans, PostgreSQL/Redis
readiness, host-header smoke responses, frontend asset status, and recent
container logs. Ran the repository's focused blue-green tests.

## Decisions & Findings
- Blue is active and routes public hosts to the blue frontend/backend pair.
- Green is running, but its backend/worker/client/admin artifacts are tagged
  `c6bac5c`, `c6bac5c`, `e096a00`, and `2d5e497`; it is unsafe to promote.
- Both colored backends report no planned migrations. PostgreSQL accepts
  connections and Redis returns `PONG`.
- All four public/staging frontend Host-header journeys returned 200 and their
  referenced JS/CSS assets returned 200.
- The documented backend health URLs return 404; generic health paths return
  frontend HTML, so backend readiness is not proven.
- The pre-blue-green singleton stack remains running; this is already logged in
  `TESC-2026-11-05-redis-exposed-no-auth-and-stale-pre-bluegreen-stack.md` and
  was not duplicated here.

## Changes Made
No TESC production or source files were changed. Added issue logs:
- `TESC-2026-11-07-green-artifact-identity-drift.md`
- `TESC-2026-11-07-health-check-contract-drift.md`

## Verification
- `python3 scripts/check_compose_colors.py` on `tesc-prod`: passed.
- `backend/.venv/bin/pytest -q tests/test_bluegreen_deployment.py`: 7 passed.
- Live nginx configuration test: passed.
- Live migration plans: no pending operations in blue or green.
- Live PostgreSQL/Redis checks: passed.
- Live frontend asset probes: all referenced JS/CSS assets returned 200.
- Artifact parity and backend health observer: failed, therefore deployment
  certification is withheld.

## Follow-ups / Deferred
- Rebuild/redeploy all green services from one explicit source commit, then
  verify image tags/digests before any cutover.
- Implement a canonical backend health/readiness endpoint and fail-closed
  smoke checks.
- Retire the stale pre-blue-green stack through the existing issue's planned
  remediation.

## References
- `docker-compose.bluegreen.yml`
- `scripts/bluegreen-deploy.sh`
- `scripts/bluegreen-cutover.sh`
- `tests/test_bluegreen_deployment.py`
- `TESC-2026-11-07-green-artifact-identity-drift.md`
- `TESC-2026-11-07-health-check-contract-drift.md`

---

**Completed By:** Copilot
**Duration:** 2026-11-07
