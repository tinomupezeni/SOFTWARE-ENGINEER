# VerifiedHQ Dashboard Port Conflict

**Date:** 2026-10-16
**Project:** VerifiedHQ
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
Starting the complete Docker Compose development stack could not recreate the
Laravel admin container because host port 8080 was already occupied. The
dashboard remains reachable on the existing process at `http://127.0.0.1:8080`,
while PostgreSQL, Redis, and the FastAPI backend started successfully.

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
The configured host port 8080 was already bound before the Compose admin
container attempted to start. Docker therefore left the existing dashboard
service accessible and rejected the replacement container.

### 3. Key Findings
- FastAPI backend is healthy on port 8010.
- PostgreSQL and Redis are healthy.
- The dashboard endpoint is reachable despite the failed container recreation.
- No application code failure was observed in the dashboard startup logs.

## Root Cause
A pre-existing local dashboard process/container owns the same host port as the
Compose admin service.

## Prevention / Rule
**Guardrail:** Development Compose services must use a documented, reserved port
map and a preflight check must report the owning process before startup.

This makes port collisions explicit and prevents partial-stack startup confusion.

## Solution

### Immediate Fix
Keep the existing dashboard on port 8080 and run the rebuilt backend on port
8010. Do not terminate the unknown owner automatically.

### Long-term Fix
Identify and deliberately stop or remap the existing dashboard, then add a
Compose preflight check for ports 55433, 6379, 8010, and 8080.

## Prevention
- [ ] Add development port ownership/preflight documentation
- [ ] Choose one canonical dashboard owner
- [ ] Add a Compose health verification script
- [ ] Avoid automatic termination of unknown local processes

## References
- `docker-compose.yml`
- `docker compose ps -a`
- `curl -I http://127.0.0.1:8080`
- Docker error: `Bind for 0.0.0.0:8080 failed: port is already allocated`

---

**Resolved By:** Copilot
**Time to Resolution:** Same debugging session; remediation deferred
