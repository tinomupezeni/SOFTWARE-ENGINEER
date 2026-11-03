# MongoDB Was Published on All Host Interfaces Without Authentication

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production VM
**Severity:** High
**Status:** Open; external reachability not established

## Summary
The production Compose file publishes MongoDB port 27017 on `0.0.0.0` and `::`. A local Docker `mongosh` session listed databases without authentication. Host firewall reachability was not tested.

## Symptoms
- Docker advertises port mapping `0.0.0.0:27017->27017/tcp` and `[::]:27017->27017/tcp`.

## Environment Details
- **Server/Host:** `agromarket-vm`
- **Services Affected:** MongoDB and marketplace data
- **Related Components:** `docker-compose.yml`, MongoDB container configuration
- **Time First Observed:** 2026-11-03 release inspection

## Investigation Steps

### 1. Initial Diagnosis
Inspected `docker ps`, the Compose file, and a local `mongosh` database listing.

### 2. Root Cause Analysis
Compose maps host port 27017 to MongoDB without a host address restriction; MongoDB accepted a local unauthenticated session.

### 3. Key Findings
- MongoDB uses the persistent `market-link-main_mongo_data` volume.
- A verified database backup was taken before the functional release.
- External access through the VM firewall remains unknown.

## Root Cause
The database port was exposed on all host interfaces without a configured authentication boundary.

## Prevention / Rule
**Guardrail:** Keep MongoDB on the private Compose network, or bind its host port to loopback and require authentication where remote access is needed.

This limits access to marketplace data independent of firewall assumptions.

## Solution

### Immediate Fix
Recorded the finding and preserved the existing MongoDB service during the functional application release.

### Long-term Fix
Plan a controlled database port and authentication change with a tested rollback and connection-path checks.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-11-03-vm-mail-url-settings-missing.md`

## References
- `docker-compose.yml`

---

**Resolved By:** Pending
**Time to Resolution:** Pending

## Verification

- `docker ps` showed host-wide port publishing; local `mongosh` required no credentials.
