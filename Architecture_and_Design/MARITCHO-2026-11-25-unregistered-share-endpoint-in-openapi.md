# MARITCHO: PR #15 Architecture & Contract Drift - Unregistered Public Share Endpoint in OpenAPI Spec

**Date:** 2026-11-25
**Project:** MARITCHO
**Environment:** Development / Staging
**Severity:** Medium
**Status:** Investigating

## Summary
In PR #15 ("feat: shareable job links (WEB-024)"), the backend introduces a new public endpoint `GET /jobs/{job_id}/share` powered by `GetJobShareSummaryUseCase`. However, the central API contract specification `docs/architecture/openapi.yaml` was not updated to reflect this new endpoint or its response schema `JobShareOut`, causing contract drift between backend implementation and API specification.

## Symptoms
- The endpoint `GET /jobs/{job_id}/share` exists in `backend/app/apps/jobs/interface_adapters/router.py` and is tested in `backend/tests/test_job_share.py`.
- `docs/architecture/openapi.yaml` contains definitions for `PATCH /jobs/{job_id}` and `POST /workers/me/vetting/police-clearance` added in PR #14 / WEB-023, but lacks `GET /jobs/{job_id}/share`.
- API client generators and contract compliance testing against `openapi.yaml` will fail to recognize or validate the share teaser endpoint.

## Environment Details
- **Server/Host:** Local / CI
- **Services Affected:** backend (FastAPI jobs router), API contract documentation
- **Related Components:** `backend/app/apps/jobs/interface_adapters/router.py`, `docs/architecture/openapi.yaml`
- **Time First Observed:** 2026-11-25

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the PR #15 file diff against `main` for contract documentation updates (`docs/architecture/openapi.yaml`).

### 2. Root Cause Analysis
Ran search across `docs/architecture/openapi.yaml`:
```bash
grep -in "jobs/{job_id}/share" docs/architecture/openapi.yaml
```
Output returned `Not found in openapi.yaml`. Commit `d7cfa0c` added the router implementation, domain service, schemas, and test suite, but omitted updating `openapi.yaml`.

### 3. Key Findings
- New public endpoint `GET /jobs/{job_id}/share` is implemented in FastAPI.
- `docs/architecture/openapi.yaml` was not updated in commit `d7cfa0c`.

## Root Cause
Developer implemented the feature and test suite under `backend/` and frontend integration under `frontend/` but did not document the new public endpoint in the repository's OpenAPI specification (`docs/architecture/openapi.yaml`), violating Phase 3 / Phase 5 contract consistency standards in `AGENTS.md`.

## Prevention / Rule
**Guardrail:** CI contract linting gate (`openapi-spec-validator` or an automated diff comparison between FastAPI's generated `app.openapi()` and `docs/architecture/openapi.yaml`) that fails CI when endpoints or schemas are added to routers without corresponding updates in `docs/architecture/openapi.yaml`.

This rule ensures that any route addition or modification immediately enforces synchronization of the central API contract.

## Solution

### Immediate Fix
Document the `GET /jobs/{job_id}/share` route and `JobShareOut` schema in `docs/architecture/openapi.yaml` with appropriate summary, description, parameter format (`uuid`), and 200/404 responses.

### Long-term Fix
Add an automated test in `backend/tests/` that compares `app.openapi()["paths"]` against `docs/architecture/openapi.yaml` to ensure zero contract drift.

## Prevention
- [ ] Add `GET /jobs/{job_id}/share` to `docs/architecture/openapi.yaml`.
- [ ] Implement automated route-to-spec parity check in test suite.

## Related Issues
- PR #15 (feat: shareable job links WEB-024)
- PR #14 (pricing modes & job editing WEB-023)

## References
- `backend/app/apps/jobs/interface_adapters/router.py`
- `docs/architecture/openapi.yaml`

---

**Resolved By:** Antigravity (Code Review)
**Time to Resolution:** Pending PR merge / update
