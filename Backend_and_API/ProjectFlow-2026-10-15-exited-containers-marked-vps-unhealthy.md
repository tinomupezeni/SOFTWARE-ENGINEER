# Exited One-Shot Containers Marked VPS Unhealthy

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
The VPS Observability dashboard reported zero healthy VPSes because the backend classified every inactive Docker container as unhealthy. This included expected one-shot migration/setup containers in `Exited` state, creating a false warning for otherwise healthy VPS hosts.

## Symptoms
- All three VPSes showed `Warning`.
- The dashboard showed `Healthy 0` and `Needs attention 3`.
- Several listed containers had normal `Exited (0)` statuses.
- HBCA also contained two genuinely unhealthy running containers.

## Environment Details
- **Server/Host:** ProjectFlow production VPS fleet
- **Services Affected:** Observability status classification and container badges
- **Related Components:** `observability/views.py`, `Infrastructure.tsx`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared the dashboard counts with the latest heartbeat payloads and backend health-classification code.

### 2. Root Cause Analysis
The backend used `not data.get('active', False)` as a failure condition. That made every exited container, including successful migrations and setup jobs, count as an unhealthy container.

### 3. Key Findings
- `chemglee-vps` had exited setup/migration containers but no unhealthy running containers.
- `restk-vps` had old exited containers and one restarting service.
- `hbca-vps` had two running containers reporting `unhealthy`.

## Root Cause
Container lifecycle state was treated as equivalent to service health. Docker's `exited` state is valid for one-shot jobs and retired containers, so it cannot by itself indicate VPS failure.

## Prevention / Rule
**Guardrail:** Health classification must use explicit Docker health failures (`unhealthy`, `restarting`, or `dead`) and not treat ordinary `exited` containers as failures.

This preserves visibility of actual service failures while preventing expected one-shot jobs from making the entire VPS appear unhealthy.

## Solution

### Immediate Fix
- Backend now flags only `unhealthy`, `restarting`, and `dead` containers.
- Frontend uses the same rule for red warning styling.
- Added a regression test covering an exited one-shot container.

### Long-term Fix
Add an explicit container role/desired-state signal if the fleet needs to distinguish an expected stopped service from an unexpectedly stopped persistent service.

## Prevention
- [x] Configuration changes needed
- [x] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `projectflow_backend/observability/views.py`
- `projectflow-hq/src/pages/Infrastructure.tsx`
- `projectflow_backend/observability/tests.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
