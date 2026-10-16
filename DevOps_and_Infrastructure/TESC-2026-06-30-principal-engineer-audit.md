# Principal Engineer Architecture Audit

**Date:** 2026-06-30
**Project:** TESC
**Environment:** Production
**Severity:** Critical
**Status:** Workaround Applied

## Summary
A comprehensive Principal Engineer audit was conducted on the production environment (10.50.200.35) and deployment pipeline. Identified critical gaps in database disaster recovery, SSL/TLS security, CI/CD pipeline integrity, and performance scaling.

## Symptoms
- No automated database backups are configured on the production host.
- Production services are served over plain HTTP, exposing sensitive data and credentials.
- The deployment script (`deploy_pipeline.sh`) is currently broken due to recent testing framework migrations.
- Gunicorn is directly exposed to the internet without a reverse proxy, and there is no caching layer in production.

Repository-side remediation has since corrected the deployment migration gate,
and the current Compose production definition includes nginx and Redis.
Production VM backup scheduling and certificate-backed HTTPS still require
VM-level execution and credentials.

## Environment Details
- **Server/Host:** `10.50.200.35`
- **Services Affected:** PostgreSQL, Django Backend, Deployment Pipeline, Networking
- **Related Components:** `docker-compose.prod.yml`, `deploy_pipeline.sh`

## Investigation Steps

### 1. Initial Diagnosis
Inspected production container configurations, server crontab for automated tasks, and the manual CI/CD pipeline script.

### 2. Root Cause Analysis
- `crontab -l` returned no results for the `user` account, confirming zero backup automation.
- `docker-compose.prod.yml` revealed direct port bindings (8000, 8080, 8081) with no reverse proxy/SSL termination.
- `deploy_pipeline.sh` explicitly executes legacy `.py` smoke tests, which were recently migrated to Pytest.
- `docker-compose.prod.yml` lacks the Redis service referenced in the system architecture docs.

### 3. Key Findings
- **Disaster Recovery (Critical):** Single point of failure. If the `postgres_data` Docker volume corrupts, 100% of production data is lost.
- **Security (Critical):** Traffic is unencrypted (HTTP). Lack of Nginx/Traefik reverse proxy.
- **CI/CD Pipeline (Critical):** The deployment script will fail on the smoke testing step because `master_smoke_test.py` no longer exists in the root directory.
- **Performance/Scalability (Medium):** Gunicorn serves requests directly. No Redis cache exists to offload database reads. Scalability is strictly vertical (single VM).

## Root Cause
Infrastructure and deployment practices have not evolved alongside the application's complexity. Technical debt accumulated as the MVP transitioned to production without enterprise hardening.

## Solution

### Immediate Fix
- Updated the repository deployment path to use Compose service names and
  verify migrations with `migrate --check`.
- Added `scripts/backup_database.sh`, which creates and validates a
  custom-format PostgreSQL archive.
- Confirmed the production Compose definition includes nginx and Redis.

### Long-term Fix
- Configure certificate-backed HTTPS on the production VM and enforce HTTP
  redirect once certificate paths and renewal ownership are provided.
- Schedule the validated backup helper to an off-host destination and perform
  a restore drill.
- Evaluate rolling deployment separately; the current single-VM Compose
  topology remains a known limitation.

## Prevention
- [ ] Schedule regular automated disaster recovery drills.
- [ ] Enforce SSL/HTTPS exclusively via infrastructure configuration.
- [x] Standardize repository-side deployment migration verification.

## Related Issues
- See previous technical debt audit: `2026-06-30-technical-debt-audit.md`

## References
- Docker Postgres Backup Strategies
- Nginx Reverse Proxy with Django Configuration

---

**Resolved By:** Antigravity AI
**Time to Resolution:** Ongoing

## Current Verification

- `docker compose -f docker-compose.prod.yml config --quiet` passes.
- `scripts/deploy.sh` passes shell syntax validation and uses Compose service
  names plus an explicit migration check.
- Production Compose defines nginx, Redis, PostgreSQL, backend, Celery, and
  both frontends.

## Blocked Operational Follow-ups

- Production VM access and an approved off-host backup destination are needed
  to schedule backups and run a restore drill.
- Certificate files/issuer and DNS ownership are needed to enable HTTPS
  termination safely.
