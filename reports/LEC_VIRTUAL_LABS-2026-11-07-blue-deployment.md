# LEC Virtual Labs Blue Production Deployment

**Date:** 2026-11-07
**Project:** LEC Virtual Labs
**Type:** Deployment
**Status:** Completed

## Summary

Promoted GitHub `main` commit `4b2cb34` to the idle blue production color on
`hbca-vps`, verified the candidate before cutover, switched traffic from green
to blue, and completed post-cutover health and smoke checks.

## Context / Trigger

The production deployment was stale at `821903a` while GitHub contained the
current release. The owner explicitly requested deployment to the idle color
and stability testing.

## Scope

Included VPS checkout synchronization, blue image build/start, candidate
health and migration gates, Caddy cutover, public smoke tests, runtime health,
and rollback-target preservation. No schema rollback, secret changes, or
application source changes were made.

## Method

Fetched GitHub `main`, fast-forwarded the VPS checkout, ran the checked-in
blue/green deployment scripts, verified the candidate directly before
cutover, then verified the public routes and active runtime after cutover.

## Decisions & Findings

- Source commit: `4b2cb34b22b807ea55470c166e945e72e41b0a2d`.
- Candidate artifact: `vlabs-backend:sha-4b2cb34` and
  `vlabs-frontend:sha-4b2cb34`.
- Candidate migrations were fully applied and all healthchecks passed.
- Cutover changed `active_color` from `green` to `blue`; green remains intact
  as the rollback target.
- The public app returned `200`, unauthenticated API `401`, bridge asset `200`,
  and hashed frontend asset `200`.
- No localhost, loopback, or staging markers were found in the frontend shell.
- Post-cutover blue backend/frontend/Postgres were healthy, migrations stayed
  applied, Caddy routed both VLabs paths to blue, and no recent backend errors
  were found.
- OCI revision labels reported `unknown` despite correct immutable tags; this
  is tracked in the separate image-label issue log.

## Changes Made

- Production traffic cut over to blue.
- Project deployment runbook and session log updated.
- Global engineering issue log and this report committed and pushed.

## Verification

Candidate:

- backend/frontend health: passed;
- migrations: all applied;
- direct frontend root: `200`;
- proxied API: `401`;
- recent backend error scan: clean.

Production:

- `https://hbca.tech/vlabs/`: `200`;
- `https://hbca.tech/vlabs/api/labs/`: `401`;
- `https://hbca.tech/labs/_bridge/lec-bridge.js`: `200`;
- hashed frontend asset: `200`;
- active color: `blue`;
- Caddy routes: blue;
- services: healthy.

## Follow-ups / Deferred

- Populate and enforce OCI revision labels from the full checkout SHA in the
  deployment path. This does not block the current verified runtime because
  the immutable image tags and source checkout were checked directly.
- Keep green available for rollback until the release is accepted operationally.

## References

- `intelligent_memory_management/architecture/deploy-runbook.md`
- `scripts/deploy/deploy-color.sh`
- `scripts/deploy/cutover.sh`
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/LEC_VIRTUAL_LABS-2026-11-07-image-revision-label-unknown.md`

---

**Completed By:** Copilot
**Duration:** ~15 minutes
