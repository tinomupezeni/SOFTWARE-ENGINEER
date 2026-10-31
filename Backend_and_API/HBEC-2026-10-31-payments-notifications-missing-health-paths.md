# Payments and notifications lack separate live and ready health paths

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Development source review; production behavior not exercised
**Severity:** Medium
**Status:** Investigating

## Summary
The payments and notifications FastAPI entry points expose only `/health`. The repository's agent execution rule requires separate `/health/live` and `/health/ready` routes, with readiness dependency calls bounded to at most two seconds. This was found during a read-only architecture pass and has not yet been fixed or verified in production.

## Symptoms
- `PAYMENTS/app/main.py` defines `/health` with a database query and no explicit timeout bound.
- `NOTIFICATIONS/app/main.py` defines `/health` returning `ok` without a dependency check.
- Neither entry point defines the required separate live and ready pathways.

## Environment Details
- **Server/Host:** Source checkout at `/home/shadowe/Projects/HBEC`.
- **Services Affected:** Payments and notifications APIs.
- **Related Components:** FastAPI health routes and deployment probes.
- **Time First Observed:** 2026-10-31 architecture pass.

## Investigation Steps

### 1. Initial Diagnosis
Read the service entry points and searched for health route declarations.

### 2. Root Cause Analysis
Both services use a single health endpoint despite the platform's distinct liveness/readiness contract. The current implementation does not show a bounded readiness dependency probe.

```bash
rg -n 'health/(live|ready)|@app.get\("/health"\)' PAYMENTS/app/main.py NOTIFICATIONS/app/main.py
```

### 3. Key Findings
- Student and admin Django backends already have separate live and ready routes.
- Payments and notifications need route and probe changes plus deployment probe alignment.
- This finding is from source inspection only; no production probe journey was run.

## Root Cause
The two FastAPI services were implemented before or outside the repository's shared health-check contract.

## Prevention / Rule
**Guardrail:** Each HTTP service must expose both `/health/live` and `/health/ready`, and CI should exercise both routes with a failing dependency to verify that readiness is bounded and returns failure while liveness remains independent.

## Solution

### Immediate Fix
None in this session; the task was a read-only architecture pass.

```bash
rg -n 'health/(live|ready)|@app.get\("/health"\)' PAYMENTS/app/main.py NOTIFICATIONS/app/main.py
```

### Long-term Fix
Add separate routes and bounded dependency checks, update probes, and verify on the target environment.

## Prevention
- [ ] Implement distinct health routes in both services.
- [ ] Add negative readiness tests with dependency timeout bounds.
- [ ] Verify deployed probes and user path.

## Related Issues
- None recorded.

## References
- `AGENTS.md` in HBEC
- `PAYMENTS/app/main.py`
- `NOTIFICATIONS/app/main.py`

---

**Resolved By:** Pending
**Time to Resolution:** Ongoing
