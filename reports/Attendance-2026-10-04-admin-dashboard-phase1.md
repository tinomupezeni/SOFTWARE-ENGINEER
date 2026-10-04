# Admin dashboard Phase 1: exception queue, evidence, CSV, auth, compliance

**Date:** 2026-10-04
**Project:** Attendance
**Type:** Feature implementation (plan: `Attendance/docs/admin-dashboard-plan.md` Phase 1)
**Status:** Completed

## Summary
Implemented all seven Phase 1 items for the Laravel admin dashboard plus the backend support they required: exception review queue with status filter, forensic evidence detail page, streaming CSV export, session auth with audit identity on overrides, POTRAZ/POPIA compliance minimum (consent gate, biometric revoke, disclosure footer), rapid-repeat anomaly badges, and witness reason codes. Verified with `php -l`, `php artisan test` (3 passed), and live endpoint checks against throwaway PostGIS.

## Context / Trigger
Phase 0 fixed three broken flows but the dashboard still lacked every MVP feature from Sprint 4 / Research §19/§28: no triage, no evidence, no export, no auth, no compliance. User directed Phase 1 start.

## Scope
Included: backend ledger enrichment (list fields, `?status` filter, detail endpoint, biometric revoke), admin filter tabs, evidence view, CSV export, login/logout + `auth` middleware + seeder, consent checkbox, revoke button, footer, reason codes, rapid-repeat flags, auth-aware tests.
Excluded: dashboard live KPIs (Phase 2), teleport/multiplexing detection (blocked: events persist neither coordinates nor device id — needs schema migration), consent-timestamp persistence (backend has no column), full compose staging smoke (stack not deployed).

## Method
Backend first (contract), admin second (consumer), per guide 19. Each layer verified before building on it: route table assertion, then seeded-PostGIS behavioral script covering list/filter/detail/override/revoke/404s, then admin tests. Throwaway containers only (`--rm` postgis/redis/php); no production or shared data touched.

## Decisions & Findings
- Minimal hand-rolled session auth instead of Breeze: sqlite + users table already existed, no composer toolchain locally; Breeze would add npm/build weight for one admin account. Seeder reads `ADMIN_EMAIL`/`ADMIN_PASSWORD`, refuses to seed without a password.
- `SESSION_DRIVER` database→file: no sessions table migration exists; file driver is correct for single-admin local deploy.
- Reason codes stored as `[CODE] text` prefix: zero backend contract change, still queryable.
- Rapid-repeat is time-only (<5min same-employee pairs, both flagged); teleport honestly deferred with the reason recorded above.
- Incidental: `mocker.patch("app.main.get_redis")` test seam is broken (logged separately as `Backend_and_API/Attendance-2026-10-04-pytest-redis-mock-seam.md`); Feature ExampleTest updated for auth redirects.

## Changes Made
Backend `app/routers/admin.py`: enriched `GET /admin/ledger` (+`verification_status, workplace, employee_code, monotonic, ?status=` with 400 on unknown), new `GET /admin/ledger/{id}`, new `POST /admin/employees/{id}/revoke-biometric`.
Admin: `LedgerController` (filter/show/export/override with `Auth::id()` + reason codes + rapid-repeat), `AuthenticatedSessionController`, `auth` route group, `EmployeeController` (consent gate + revoke), seeder, `.env` session driver, views (ledger index/show, login, consent, revoke, header user + sign out, footer), auth redirect tests.
Attendance repo has no git; changes are uncommitted working tree.

## Verification
- `php -l` clean on all touched PHP files.
- `php artisan test`: 3 passed (8 assertions), including guest→login redirects.
- `phase1_ledger_check.py` vs throwaway PostGIS+schema: list/filter-400/detail/404/override/revoke/404 + ledger-append-only assertion — all passed; container removed afterwards.

## Follow-ups / Deferred
- Phase 2 polish (live dashboard KPIs, workplace edit/delete, a11y pass).
- Schema migration persisting coordinates/device id for real kinematic detection + consent timestamps.
- Full `docker compose` staging smoke before any deploy; `git init` + first commit for Attendance.

## References
- Bug logs resolved: ledger-override-contract-mismatch, device-pair-polling-route-missing, workplace-create-address-null.
- Bug logs still open: dashboard-fabricated-metrics, pytest-redis-mock-seam.
- Plan: `Attendance/docs/admin-dashboard-plan.md`.

---

**Completed By:** Phase 1 session
**Duration:** Same day
