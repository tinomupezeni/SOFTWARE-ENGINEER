# Redis Host Port Conflict Preventing Stack Boot

**Date:** 2026-10-03
**Project:** ATTENDANCE
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The local Docker Compose stack failed to boot due to an `ERR_CONNECTION_REFUSED` cascading error. The root cause was attempting to bind the Redis container to the host's `6379` port, which was already in use by another host process.

## Symptoms
- The user received `ERR_CONNECTION_REFUSED - http://localhost:8080/` when attempting to access the Laravel dashboard.
- The `docker compose up -d` command threw a daemon error: `Bind for 0.0.0.0:6379 failed: port is already allocated`.
- The `attendance-redis-1` container failed to start, which prevented the dependent `attendance-backend-1` and `attendance-admin-1` containers from booting.

## Environment Details
- **Server/Host:** Local Development Environment
- **Services Affected:** Redis, FastAPI Backend, Laravel Admin Dashboard
- **Related Components:** `docker-compose.yml`
- **Time First Observed:** 2026-10-03T23:39

## Investigation Steps

### 1. Initial Diagnosis
Checked the container status logs when the dashboard failed to load. Noticed the entire stack aborted during the Redis container initialization phase.

### 2. Root Cause Analysis
Analyzed the Docker daemon output:
```bash
Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint attendance-redis-1: Bind for 0.0.0.0:6379 failed: port is already allocated
```
The `docker-compose.yml` was explicitly mapping the internal Redis port to the host port `6379`. Since another project or the host itself was running Redis, the port collision killed the stack.

### 3. Key Findings
- Internal services (like the FastAPI backend) communicate with Redis using the internal Docker DNS (`redis:6379`).
- Exposing the Redis port to the host is unnecessary for this architecture unless direct manual inspection via `redis-cli` from the host is required.

## Root Cause
Hardcoding a common host port (`6379`) in a `docker-compose.yml` file without checking host availability causes fatal collisions in multi-project local environments.

## Prevention / Rule
**Guardrail:** Remove `ports` mappings for internal-only datastores (Redis, Postgres) in development `docker-compose.yml` unless explicitly required. If required, map to ephemeral/random host ports (e.g., `ports: ["6379"]` which maps to a random available host port).

By relying exclusively on internal Docker networking, we guarantee the stack can spin up cleanly regardless of what is running on the host machine.

## Solution

### Immediate Fix
Removed the `ports` block from the `redis` service definition in `docker-compose.yml`.

### Long-term Fix
Ensure all future service definitions follow the pattern of not exposing internal infrastructure ports to the host interface.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 5 minutes
