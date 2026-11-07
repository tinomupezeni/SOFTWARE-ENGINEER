# HBEC staging promotion for bc9eabe

**Date:** 2026-11-07
**Project:** HBEC
**Type:** Deployment / Release Verification
**Status:** Completed

## Summary
Built and deployed the exact `master` commit `bc9eabef1` to the inactive
blue-green color on the VPS. The green color is now a verified staging
candidate on `sha-bc9eabe`; public traffic remains on blue and no production
cutover was performed.

## Context / Trigger
The previous deployment work had configured the Anthropic key and prepared the
merged `master` release, and the next requested step was to deploy that exact
artifact to staging. The legacy `/home/winstontino/HBEC` staging checkout is no
longer present; the current deployment model uses the inactive color and
`staging-*` domains as staging.

## Scope
Included:
- Exact source identity and VPS deployment configuration preflight.
- Building/reusing the release images and starting only the inactive green
  color.
- Artifact, migration, readiness, service-link, retrieval-data, secret-parity,
  frontend, and public staging smoke verification.
- Production isolation checks.

Excluded:
- Blue/green cutover or any production traffic change.
- Authenticated user journeys that require a test account.
- Repair of optional self-hosted model endpoints that are not required by the
  release gates.

## Method
Pinned the VPS deployment script to the pushed commit, allowed it to run its
compose isolation and migration checks, then verified the exact image revision
labels, database heads, signed links, curated retrieval data, runtime secret
parity, public staging endpoints, frontend asset shells, and production
container start times.

## Decisions & Findings
- The current staging target is inactive green, not the removed legacy staging
  directory.
- The first deployment attempt stopped before container recreation because
  `CODE_RUNNER_SECRET` was absent from the manually maintained VPS environment.
  The persistent secret was generated with the committed guard script; the
  distinct issue is logged in
  `DevOps_and_Infrastructure/HBEC-2026-11-07-code-runner-secret-missing.md`.
- Green is on `bc9eabe`; `active_color` remains `blue`.
- Optional self-hosted model health checks emit warnings because their
  endpoints are unavailable. Required service links, readiness, and staging
  smoke checks remain successful.

## Changes Made
- Deployed green images tagged `sha-bc9eabe` for all 10 required services.
- Recorded `.sha_green=bc9eabe`.
- Added the missing persistent VPS `CODE_RUNNER_SECRET`.
- No repository application files or production containers were changed.

## Verification
- All green containers passed `--wait`; required health checks reported
  healthy.
- Revision verification passed for all 10 services.
- All signed service-to-service links passed.
- `heritage_knowledge` contained 51 points.
- Runtime secret drift check passed for 12 groups.
- Student and admin Django migration plans reported zero unapplied migrations.
- Harness Alembic reported `042 (head)`.
- `https://staging-student.hbca.tech/health/live/` returned 200.
- `https://staging-admin.hbca.tech/health/live/` returned 200.
- `https://staging-api.hbca.tech/health` returned 200.
- Student and admin API schemas returned 200.
- Frontend shells contained asset references and no localhost references.
- `active_color=blue`, production start times were unchanged, and the
  production `.last_good_sha` was unchanged.

## Follow-ups / Deferred
- Do not run `manual-cutover.sh` until an authenticated product smoke journey
  is explicitly approved and completed.
- Investigate whether the optional self-hosted model endpoints should be
  configured or removed from the production health probe.

## References
- `scripts/deploy/manual-deploy-color.sh`
- `scripts/deploy/verify-service-links.sh`
- `scripts/deploy/verify-retrieval-data.sh`
- `docs/BLUE_GREEN_CUTOVER_RUNBOOK.md`
- `docs/MANUAL_DEPLOY_PROMOTION.md`
- `DevOps_and_Infrastructure/HBEC-2026-11-07-code-runner-secret-missing.md`

---

**Completed By:** Copilot
**Duration:** 2026-11-07 deployment session
