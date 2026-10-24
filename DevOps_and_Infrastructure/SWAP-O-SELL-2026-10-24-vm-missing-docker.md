# Target VM Missing Docker Runtime

**Date:** 2026-10-24
**Project:** Swap-O-Sell
**Environment:** Production deployment target
**Severity:** High
**Status:** Investigating

## Summary
The `mywealth-vm` SSH target is reachable, but the host does not have the Docker CLI installed. The planned deployment uses Docker Compose to build and run the backend, storefront, admin app, and PostgreSQL services, so deployment cannot proceed until the container runtime is provisioned.

## Symptoms
- SSH connection to `mywealth-vm` succeeds.
- Host reports Ubuntu 22.04.5 LTS.
- `docker --version` returns `docker: command not found`.

## Environment Details
- **Server/Host:** `mywealth-vm` (`10.50.23.166`), SSH user `user`
- **Services Affected:** All Swap-O-Sell production services
- **Related Components:** Docker Engine, Docker Compose plugin, `docker-compose.production.yml`
- **Time First Observed:** 2026-10-24 17:29 +02:00

## Investigation Steps

### 1. Initial Diagnosis
Connected with the configured SSH alias and attempted to inspect the host runtime:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 mywealth-vm \
  'docker --version; docker compose version'
```

### 2. Root Cause Analysis
The SSH account reached the VM successfully, but the first Docker probe failed because the `docker` executable is not present on the host. The remote command stopped at that failure before any Compose or existing application-state inspection could run.

### 3. Key Findings
- The VM is reachable over SSH.
- The host is Ubuntu 22.04.5 LTS.
- Docker Engine is not installed or is not available on `PATH`.
- The repository's production deployment requires Docker Compose.

## Root Cause
The deployment target has not been provisioned with the required Docker runtime.

## Prevention / Rule
**Guardrail:** Add a preflight step to the deployment workflow that fails before artifact transfer unless `docker --version` and `docker compose version` succeed on the target host.

This prevents a successful SSH connection from being mistaken for a deployable host and catches missing runtime dependencies before build or service changes begin.

## Solution

### Immediate Fix
Pending confirmation that the account may install Docker or that the VM administrator will provision it.

### Long-term Fix
Document Docker Engine and Compose plugin installation as a VM prerequisite and enforce the preflight check in `deploy/deploy.sh` or the CI deployment job.

## Prevention
- [ ] Add Docker/Compose target preflight to deployment automation
- [ ] Document VM runtime prerequisites
- [ ] Add host-level monitoring for Docker daemon availability
- [ ] Confirm backup and rollback procedures before first production start

## Related Issues
- None yet.

## References
- `/home/shadowe/Projects/swap-o-sell/docker-compose.production.yml`
- `/home/shadowe/Projects/swap-o-sell/deploy/deploy.sh`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
