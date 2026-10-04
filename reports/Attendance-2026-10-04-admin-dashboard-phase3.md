# Admin dashboard Phase 3: CI, docs, staging smoke, kinematic schema

**Date:** 2026-10-04
**Project:** Attendance
**Type:** Feature implementation (plan: `Attendance/docs/admin-dashboard-plan.md` Phase 3)
**Status:** Completed

## Summary
Closed out the dashboard program: hermetic backend tests + CI for both services, README/openapi docs, the first full `docker compose` staging smoke (all green), and migration 002 persisting device/coordinates/consent with teleport + device-share flags in the review queue. Committed to VerifiedHQ (`ae83d4d`); all issue logs now Resolved.

## Context / Trigger
Phase 3 scope agreed with user: gates/docs first, live smoke, schema work last.

## Scope
Included: `FakeRedis` rewrite + `aclose()`, two CI workflows, README walkthrough, `.env.example` keys, openapi admin section, compose smoke, migration 002 + model/sensor-fusion/ledger wiring + consent_at, admin kinematic flags + evidence display.
Excluded: branch protection (needs GitHub UI — flagged to user), workplace delete (still FK-unsafe), full-app ruff paydown (87 pre-existing findings; CI holds `tests/` clean and full lint advisory).

## Method
Same contract-first order: migration SQL → backend wiring → admin consumers. Both migration paths verified (fresh init applies 001+002; 002 re-applied onto a 001-only DB). Two more self-caught edit collisions repaired by re-reading regions (kinematics insert ate a method signature; a duplicate body survived deletion — both caught by `php -l` + re-read, not by tests).

## Decisions & Findings
- Raw-SQL `migrations/` is the project's real mechanism; `engineering_standards.md` mandates Alembic but nothing uses it — recorded in-plan as a doc-vs-reality gap rather than silently switching systems midstream.
- Models use `Float` to match the `DOUBLE PRECISION` migration columns exactly (first draft said `Numeric`, corrected after `\d` inspection).
- Kinematic flags stay Suspicious Observations per the contextual-suspicion principle; thresholds (300 km/h, 3-min share window, 5-min repeat) are constants-adjacent inline values, documented in code.
- Compose DB volume carries stale dev data (EMP777/Lewisam) — local-only, noted for future seed hygiene.

## Changes Made
VerifiedHQ `ae83d4d` (17 files): CI workflows, hermetic `tests/test_api.py`, migration 002, backend wiring (models/schemas/sensor_fusion/ledger/consent), admin kinematic flags + views, README/openapi/plan updates.
Still uncommitted nowhere — working trees clean except intended files.

## Verification
- Backend: 3 passed hermetic; `ruff check tests/ + redis_client.py` clean.
- Admin: `php -l` clean; `php artisan test` 3 passed; `npm run build` (Phase 2, unchanged).
- Migration script vs throwaway PostGIS: kinematic fields, consent 201/400, append-only — passed. Upgrade path 001→002 applied clean.
- Staging smoke: compose build, `/health` ok, `/health/ready` connected, nonce/filter/400-guard/workplaces-geojson/admin-login-200 — then `compose down`.

## Follow-ups / Deferred
- Enable branch protection + confirm first CI run on GitHub.
- Whole-app ruff paydown (87 findings, mostly E501/B008/UP045).
- Seed hygiene for the persistent compose volume.

## References
- Bug log resolved: pytest-redis-mock-seam (last open Attendance entry).
- Reports: phase1, phase2, repo-init.
- VerifiedHQ: `81ae9e8` → `ae83d4d`.

---

**Completed By:** Phase 3 session
**Duration:** Same day
