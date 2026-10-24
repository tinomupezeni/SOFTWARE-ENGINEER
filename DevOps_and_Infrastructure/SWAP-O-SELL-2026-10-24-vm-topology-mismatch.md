# Target VM Does Not Match Production Compose Topology

**Date:** 2026-10-24
**Project:** Swap-O-Sell
**Environment:** Production deployment target
**Severity:** High
**Status:** Investigating

## Summary
The `mywealth-vm` host does not currently match the infrastructure topology required by Swap-O-Sell's production Compose deployment. Apache serves port 80 and PostgreSQL 14 runs as a host service, while the repository expects an external Docker `proxy-tier` network and a Caddy container named `caddy-proxy`.

## Symptoms
- Port 80 responds with `Server: Apache/2.4.52 (Ubuntu)`.
- PostgreSQL 14 is running as `postgresql@14-main.service` and listens on host port 5432.
- No Docker runtime or `caddy-proxy` container is available.
- The production Compose file declares `proxy-tier` as an external Docker network.

## Environment Details
- **Server/Host:** `mywealth-vm` (`10.50.23.166`), SSH user `user`
- **Services Affected:** Frontend, admin frontend, backend ingress, and PostgreSQL
- **Related Components:** `docker-compose.production.yml`, `deploy/deploy.sh`, Apache, host PostgreSQL
- **Time First Observed:** 2026-10-24 17:30 +02:00

## Investigation Steps

### 1. Initial Diagnosis
Inspected listening ports, running processes, systemd services, and the local HTTP response:

```bash
ssh mywealth-vm 'ss -ltnp; ps -eo user,pid,cmd; systemctl list-units --type=service --state=running'
ssh mywealth-vm 'curl -I http://127.0.0.1/'
```

### 2. Root Cause Analysis
The VM appears to be a general-purpose Ubuntu host with an existing Apache/PostgreSQL installation, not the Docker/Caddy host described by the repository deployment documentation. The production Compose file cannot be started as designed until the runtime and edge-network prerequisites are established or the deployment topology is intentionally adapted.

### 3. Key Findings
- Apache owns the public HTTP listener on port 80.
- PostgreSQL 14 is already installed outside Docker.
- The expected Docker external network and Caddy service cannot exist while Docker is absent.
- Existing host services must not be stopped or replaced without owner approval and a backup/rollback plan.

## Root Cause
The selected VM was not provisioned with the infrastructure contract assumed by the repository's production deployment.

## Prevention / Rule
**Guardrail:** Require a target-host preflight that verifies Docker Engine, Compose, the external proxy network, the edge proxy container, required ports, and database topology before any deployment promotion.

This prevents a reachable but incompatible host from being treated as production-ready and avoids disrupting unrelated Apache or PostgreSQL services.

## Solution

### Immediate Fix
Pending an explicit decision to provision the VM for the repository's Docker/Caddy topology or to adapt the deployment to the existing Apache/host-PostgreSQL topology.

### Long-term Fix
Keep the production topology contract in a machine-readable preflight script and document ownership, backup, port allocation, and rollback boundaries for shared VM services.

## Prevention
- [ ] Decide whether this VM is dedicated to Swap-O-Sell
- [ ] Provision Docker Engine and Compose
- [ ] Establish the edge proxy/network contract
- [ ] Define whether PostgreSQL is containerized or shared
- [ ] Back up existing host services before any changes

## Related Issues
- `SWAP-O-SELL-2026-10-24-vm-missing-docker.md`

## References
- `/home/shadowe/Projects/swap-o-sell/docker-compose.production.yml`
- `/home/shadowe/Projects/swap-o-sell/deploy/deploy.sh`
- `/home/shadowe/Projects/swap-o-sell/deploy/README.md`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
