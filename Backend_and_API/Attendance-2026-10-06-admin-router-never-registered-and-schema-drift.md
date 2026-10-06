# Admin Dashboard's Entire Backend API Was Dead Code: Router Never Registered, Then Found to Have Drifted From the Schema on Every Endpoint

**Date:** 2026-10-06
**Project:** Attendance
**Environment:** Production (smepulse-vm, first real exercise of this code path)
**Severity:** Critical
**Status:** Resolved

## Summary
The user reported "Failed to retrieve ledger from Ingestion API" when opening the Ledger page, and asked to confirm the admin dashboard and backend were actually connected. Investigation found `app/main.py` never called `app.include_router(admin.router)` — every `/admin/*` endpoint (ledger, employees, workplaces, devices — i.e. the entire admin dashboard's data layer) had 404'd since the initial commit. Once registered, the router failed to import at all (undefined model/schema names), and once that was fixed, nearly every write endpoint failed against the real database because `admin.py` had been written against an earlier version of `models.py`/`schemas.py` and never reconciled after later refactors. This had never been caught because the router was never wired in, so it was never exercised against a live Postgres instance.

## Symptoms
- Laravel admin dashboard: `/ledger` → "Failed to retrieve ledger from Ingestion API" (the one explicit error-check in the codebase; `LedgerController::index()` checks `$response->failed()`).
- The `/dashboard` Overview page showed zero data with **no error indicator at all** — a quieter instance of the same root cause. `DashboardController::index()` doesn't check `$response->failed()`, only catches exceptions; a 404 response decodes to `{"detail":"Not Found"}` via `->json()`, which is not an exception, so the code silently treated it as "no check-ins today" instead of surfacing a fault. This is exactly the false-positive trap guide 10 warns about — a working-looking 200 that isn't actually working.
- `curl http://backend:8000/admin/ledger` / `/admin/employees` → `404 {"detail":"Not Found"}` before any fix.

## Environment Details
- **Server/Host:** smepulse-vm, container `attendance-backend-1`
- **Services Affected:** FastAPI backend's entire `/admin/*` surface; Laravel admin dashboard (all 5 nav pages: Overview, Ledger, Workplaces, Employees, Devices)
- **Related Components:** `backend/app/main.py`, `backend/app/routers/admin.py`, `backend/app/schemas.py`, `backend/app/models.py`
- **Time First Observed:** 2026-10-06, user report after first production deployment

## Investigation Steps

### 1. Initial Diagnosis
`curl http://localhost:8002/admin/ledger?limit=50&offset=0` from the VM returned `404 {"detail":"Not Found"}`, not a 500 — ruling out a query bug and pointing at routing.

### 2. Root Cause Analysis — Layer 1 (routing)
```python
# app/main.py, before fix
from app.routers import checkin, exceptions, export
app.include_router(checkin.router)
app.include_router(exceptions.router)
app.include_router(export.router)
# admin.router was imported nowhere and never registered
```
`git log --oneline -- app/main.py` showed only two commits (initial commit, Phase 3), confirming this was never wired in at any point, not a regression.

### 3. Root Cause Analysis — Layer 2 (import failure once registered)
Registering `app.include_router(admin.router)` surfaced `ImportError: cannot import name 'Device' from 'app.models'` — the model is `EmployeeDevice`, not `Device`. Fixing that surfaced a second `ImportError: cannot import name 'WorkplaceUpdate' from 'app.schemas'` — along with `OverrideEvent`, `PairingTokenRequest`, `PairingTokenResponse`, `PairDeviceRequest`, none of which existed in `schemas.py` at all (a different, unrelated `OverrideEventRequest` existed, already in use by `exceptions.py` for a separate endpoint).

### 4. Root Cause Analysis — Layer 3 (runtime failures once it imported)
Cross-checked every admin.py handler against (a) the real Laravel controllers that call it (`EmployeeController`, `DeviceController`, `LedgerController`, `WorkplaceController` — the actual, working contract) and (b) the real SQLAlchemy models, and found:
- `EmployeeDevice` construction used `owner_employee_id=` (model column is `employee_id`).
- `list_devices` raw SQL selected `FROM devices` (table is `employee_devices`) with column `owner_employee_id` (column is `employee_id`).
- `view_ledger`/`ledger_event_detail` raw SQL selected `e.hardware_monotonic_time`, `e.gps_lat`, `e.gps_lng`, `e.gps_accuracy` — none of these columns exist; the real columns are `hardware_monotonic_nanoseconds`, `gps_latitude`, `gps_longitude`, `gps_accuracy_meters`.
- `override_attendance`'s compensating-event construction used `hardware_monotonic_time=0` (same wrong name).
- `register_employee` constructed `Employee(biometric_embedding=..., biometric_consent_at=...)` — neither attribute exists on the model (real columns: `biometric_template_encrypted`, `biometric_consent_timestamp`) — and omitted `organization_id`, a `NOT NULL` FK with no default.
- `create_workplace`'s raw `INSERT INTO workplaces (...)` also omitted `organization_id` (same NOT NULL FK gap) **and** omitted the `id` primary key column entirely — the model's `default=uuid.uuid4` is a Python-side ORM default that raw SQL bypasses, so the insert hit a `NotNullViolationError` on `id`.
- `generate_pairing_token` JSON-serialized a payload containing a Pydantic `UUID` value (`owner_employee_id`) directly into Redis via `json.dumps`, which doesn't know how to serialize `UUID`.
- No `Organization` row existed anywhere and nothing in the app ever created one — `organization_id` is modeled as multi-tenant but no part of the application (including `checkin.py`, which imports `Organization` but never uses it) ever resolves or creates one.

## Root Cause
`admin.py` was written against an earlier iteration of `models.py`/`schemas.py` and never reconciled after later refactors (model/column renames, schema changes), and critically was **never registered in `main.py`**, so none of this drift was ever caught by running the code — not in development, not in CI (no test imports or exercises this router), not in any prior deployment (this was the first).

## Prevention / Rule
**Guardrail:** A FastAPI router that exists in the codebase but is reachable by zero tests and zero `include_router` calls is dead code with a false sense of completeness — the same "Potemkin tooling" pattern SOFTWARE-ENGINEER's SDLC guide names for declared-but-never-exercised tooling. Two mechanical guardrails close this specific gap: (1) a CI smoke test that imports `app.main:app` and asserts every router module under `app/routers/` is present in `app.routes` (catches "never registered" immediately, no DB needed); (2) at least one integration test per admin endpoint that runs against a real (test) Postgres instance, not mocks — this is the only thing that would have caught the model/column/schema drift, since every individual piece (import, Pydantic validation, SQL syntax) was independently plausible-looking.

## Solution

### Immediate Fix
- `app/main.py`: added `app.include_router(admin.router)`.
- `app/models.py` import in `admin.py`: `Device` → `EmployeeDevice`; added `Organization` import.
- `app/schemas.py`: added `WorkplaceUpdate`, `OverrideEvent`, `PairingTokenRequest`, `PairingTokenResponse`, `PairDeviceRequest`; rewrote `EmployeeCreate` to match the fields the Laravel controller actually sends (`biometric_embedding_base64`, `biometric_consent_at`) instead of its previous, unused fields.
- `admin.py`: fixed every column/attribute name listed above (`employee_id`, `hardware_monotonic_nanoseconds`, `gps_latitude`/`gps_longitude`/`gps_accuracy_meters`, `biometric_template_encrypted`/`biometric_consent_timestamp`), added a `_get_or_create_default_organization()` helper (the admin UI has no organization-management surface, so a single default tenant is created lazily on first use) and wired it into both `register_employee` and `create_workplace`, added explicit `uuid.uuid4()` generation to the raw-SQL workplace insert, and `str()`-cast the UUID fields before `json.dumps` in `generate_pairing_token`.
- Verified every one of the 5 dashboard pages (Overview, Ledger, Workplaces, Employees, Devices) end-to-end via a real logged-in session, and every underlying write path (create employee, create workplace, update workplace, generate pairing token, pair device) via direct API calls — not just that the pages returned 200, per the false-positive-trap guidance. Test records were deleted after verification.

### Long-term Fix
Add at least minimal integration test coverage for `admin.py` against a real test database (currently zero tests touch this router) and a CI check that fails the build if a router module exists under `app/routers/` without a corresponding `include_router` call.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- `Attendance-2026-10-06-migrations-never-run-in-production.md` — the second, independent layer of brokenness found in the same investigation (the database itself had no tables at all).

## References
- `Principal_Engineer/engineering-guides/1. SDLC.md` ("Potemkin tooling" pattern)
- `Principal_Engineer/engineering-guides/10. Deployment And Maintenance.md` (false-positive-trap smoke-testing guidance)

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** ~90 minutes
