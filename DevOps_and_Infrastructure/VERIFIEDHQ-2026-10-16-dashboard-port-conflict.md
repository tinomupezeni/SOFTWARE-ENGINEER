# VerifiedHQ Dashboard Port Conflict

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Starting the complete Docker Compose development stack initially could not
recreate the Laravel admin container because host port 8080 was occupied by the
SwapOSell frontend. After identifying the owning container, it was stopped and
the VerifiedHQ dashboard was recreated successfully on port 8080.

## Symptoms
- `docker compose up -d --build db redis backend admin` failed while starting
  `attendance-admin-1`.
- Docker reported: `Bind for 0.0.0.0:8080 failed: port is already allocated`.
- `curl http://127.0.0.1:8080` returned HTTP 200.

## Environment Details
- **Server/Host:** Local development workstation
- **Services Affected:** Laravel dashboard container startup
- **Related Components:** `docker-compose.yml`, existing process/container on port 8080
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
Started the backend and dashboard stack, then checked Compose status and the
dashboard HTTP endpoint.

### 2. Root Cause Analysis
The `swap-o-sell-frontend-1` container owned host port 8080. Docker therefore
rejected the VerifiedHQ admin container until that specific conflicting
container was stopped.

### 3. Key Findings
- FastAPI backend is healthy on port 8010.
- PostgreSQL and Redis are healthy.
- The dashboard endpoint is reachable through the recreated VerifiedHQ admin
  container.
- No application code failure was observed in the dashboard startup logs.

## Root Cause
A pre-existing `swap-o-sell-frontend-1` container owned the same host port as
the Compose admin service.

## Prevention / Rule
**Guardrail:** Development Compose services must use a documented, reserved port
map and a preflight check must report the owning process before startup.

This makes port collisions explicit and prevents partial-stack startup confusion.

## Solution

### Immediate Fix
Stopped only the identified `swap-o-sell-frontend-1` container and recreated
`attendance-admin-1` with the configured `8080:8000` mapping.

### Long-term Fix
Add a Compose preflight check for ports 55433, 6379, 8010, and 8080, and
document ownership of shared development ports.

## Prevention
- [x] Add development port ownership/preflight documentation
- [x] Choose one canonical dashboard owner for this session
- [ ] Add a Compose health verification script
- [x] Avoid automatic termination of unknown local processes

## References
- `docker-compose.yml`
- `docker compose ps -a`
- `curl -I http://127.0.0.1:8080`
- Docker error: `Bind for 0.0.0.0:8080 failed: port is already allocated`
- `docker stop swap-o-sell-frontend-1`
- `curl -I http://127.0.0.1:8080` → `302 /dashboard`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session
