# CanopyRx Phase 3 Backend (sync API + surveillance + dealers)

**Date:** 2026-09-28
**Project:** CANOPYRX
**Type:** Architecture Decision / Scope Decision
**Status:** Completed

## Summary
Built `services/api` (FastAPI + PostGIS): idempotent batch sync, GeoJSON/cluster/drift-export surveillance, nearest-dealer mapping, OTel-style `/health` + `/health/ready`, Leaflet supervisor map, Compose staging + backup/rollback runbook. Gates green (ruff, mypy --strict, 7/7 pytest) plus a full live round-trip against the composed stack.

## Context / Trigger
Phase 3 of `docs/planning/project-plan.md` (PRD US-5/US-6, ADR-002/ADR-004).

## Scope
Included: all endpoints, Alembic 0001, dealer seeds, dashboard v1, Compose, runbook, mobile outbox payload extension to match `ScanIn`. Excluded: JWT (API key for v1), SMS sync, auto-retraining push.

## Method
Contract-first from the mobile outbox outward; throwaway PostGIS container for tests; pre_deploy rule (curl the real stack, not just green CI).

## Decisions & Findings
- Client UUID as PK + `on_conflict_do_nothing` → retries counted as duplicates, verified live (accepted 1 → duplicates 1).
- GPS nullable end-to-end (consent model); geojson/clusters exclude nulls; drift-export carries no coordinates at all.
- Real failures fixed: (1) function-scoped pytest-asyncio loops vs module-global async engine → `asyncio_default_test_loop_scope = "session"`; (2) `ST_X(geography)` doesn't exist → cast to geometry at the query boundary; (3) `row.count` hits `Row.count()` not the label → labeled `n`; (4) alembic console script lacks cwd on sys.path → `PYTHONPATH=/srv/api` in Dockerfile; (5) host ports 8000/8001 taken → `API_PORT` override in Compose.
- Cross-boundary catch: mobile outbox lacked `action/spray_needed/severity_label/followup_days` the API requires — extended Dart payload + test asserting `ScanIn` key compatibility.

## Changes Made
CANOPYRX (uncommitted, per only-commit-when-asked): `services/api/` (app, alembic, seeds, tests, Dockerfile), `docker-compose.yml`, `docs/releases/backend-runbook.md`, mobile payload extension + test.

## Verification
- `ruff check` + `format --check` clean; `mypy --strict` clean (14 files).
- `pytest` 7/7 vs throwaway PostGIS (auth, idempotency, GPS-consent, dealers, dashboard, drift-export).
- Live Compose stack: migrate + seed + readiness UP + mobile-shaped sync POST + retry-dedupe + geojson pin + cluster cell + nearest-dealer distances + 401 on bad key. Stack torn down after.

## Follow-ups / Deferred
- Target-device camera/TFLite latency (needs hardware + Phase-1 model); release APK budget; JWT/multi-tenant; monthly restore-test per runbook; commit CANOPYRX when asked.

## References
- ADR-002/ADR-004; PRD US-5/US-6; runbook `docs/releases/backend-runbook.md`; prior reports (gate1, phase1-triage, phase2-mobile)

---

**Completed By:** OpenCode (Muse Spark)
**Duration:** ~1 session
