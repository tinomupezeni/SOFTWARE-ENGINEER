# ProjectFlow staging observability deployment

**Date:** 2026-10-15
**Project:** ProjectFlow
**Type:** Deployment / Configuration Hardening
**Status:** Completed

## Summary
Merged the preserved observability implementation into the newer `staging` source line and deployed it to `restk-vps`, replacing the prior ProjectFlow containers while preserving the existing PostgreSQL volume. The deployment also applied a transitional production configuration for the confirmed public hostname.

## Context / Trigger
The running VPS contained newer application features than local `main`, while observability changes existed only in a local stash. The release needed to use `staging` without losing observability or rolling production back.

## Scope
Included source branch alignment, observability merge, container build/upload, database migrations, VPS registration, runtime configuration, and post-deployment checks. A full test-suite pass and permanent database credential rotation were not completed in this initiative.

## Method
Inspected the live Compose project, image IDs, migrations, volumes, and host routing before making changes. Preserved the remote environment, provisioned missing runtime secrets without displaying them, built locally, uploaded images through the existing resumable upload helper, recreated the ProjectFlow stack, and verified runtime behavior.

## Decisions & Findings
- `origin/staging` was selected as the release baseline.
- Observability source was restored from the local stash without restoring the local SQLite database or generated artifacts.
- The existing PostgreSQL volume was retained.
- `DEBUG=False` and `ALLOWED_HOSTS=projectflow.thuthuka.tech` were applied for this rollout.
- The existing database password was retained temporarily to remain compatible with the existing database volume.
- The deployment script had to use the frontend's available `Dockerfile`, not the missing `Dockerfile.prod`.

## Changes Made
- Added observability app, migrations, endpoints, tests, management commands, telemetry agent, and deployment assets.
- Added observability URL and app registration.
- Updated deployment registration and host-aware health checks.
- Applied production Compose settings and provisioned missing `SECRET_KEY` and `CREDENTIAL_ENCRYPTION_KEYS` values on the VPS.
- Deployed local release commits `31352a8`, `6268ecb`, and `ca7843e`.

## Verification
- Django system check passed locally.
- Observability tests passed: 3 tests.
- Full test suite was started but did not complete within the available run window.
- VPS containers are running: backend, scheduler, frontend, and PostgreSQL.
- All observability migrations are applied.
- Three VPS records were registered.
- Backend returns HTTP 200 for `projectflow.thuthuka.tech`.
- Frontend returns HTTP 200 for `https://projectflow.thuthuka.tech/`.
- Runtime reports `DEBUG=False`, the requested allowed host, and observability enabled.

## Follow-ups / Deferred
- Rotate the transitional PostgreSQL `postgres` credential and move it fully into managed secret configuration.
- Configure HTTPS security settings flagged by `manage.py check --deploy`: HSTS, SSL redirect, secure session cookies, and secure CSRF cookies.
- Replace Django/Vite development servers with production WSGI/ASGI and static frontend serving.
- Complete and investigate the full test suite.
- Address the 34 npm audit findings reported during the frontend image build.
- Add immutable commit-tagged image metadata and a preflight/rollback gate.

## References
- `ProjectFlow-2026-10-15-production-config-hardening.md`
- `ProjectFlow-2026-10-15-deployment-drift-and-host-mismatch.md`
- `ProjectFlow-2026-10-15-source-rollback-risk.md`
- `ProjectFlow-2026-10-15-frontend-dockerfile-deployment-mismatch.md`

---

**Completed By:** Copilot
**Duration:** Same deployment session
