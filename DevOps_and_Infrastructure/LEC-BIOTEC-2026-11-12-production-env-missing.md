# Production Compose environment missing from VPS

**Date:** 2026-11-12
**Project:** LEC Biotec
**Environment:** Production
**Severity:** Critical
**Status:** Investigating

## Summary

The production VPS directory `/opt/webapps/lec-biotech` contains
`docker-compose.yml` but no `.env` file. The Compose file requires `DB_NAME`,
`DB_USER`, and other production settings during interpolation, so the current
deployment cannot be reproduced, validated, or safely updated from the
repository.

## Symptoms

- `docker compose config --quiet` fails before deployment:
  `required variable DB_NAME is missing a value`.
- The existing containers are running from a four-week-old deployment.
- The API and worker containers report `APP_VERSION=0.0.0`, so the running
  artifact is not tied to a commit identity.
- The web container and API are reachable, but a direct host health probe using
  `127.0.0.1` receives Django `400 DisallowedHost`; the public proxy path must
  be tested with the configured host and scheme.

## Environment Details

- **Server/Host:** `administrator@93.127.143.153` (`vps-tino`)
- **Services Affected:** LEC Biotec Compose stack and deployment procedure
- **Related Components:** `deploy.sh`, `docker-compose.yml`, production `.env`
- **Time First Observed:** 2026-11-12 12:47 UTC

## Investigation Steps

### 1. Initial Diagnosis

Connected to the VPS over SSH and inspected the application directory, Compose
configuration, containers, images, listeners, and local HTTP endpoints without
printing secret values.

### 2. Root Cause Analysis

The deployment script validates a local `.env`, but it only copies
`docker-compose.yml` to the VPS. The `.env` transfer is commented out, while
the remote Compose file references `.env` for `env_file` and required
interpolation values. The VPS currently has no `.env`, leaving the running
containers dependent on environment values from their previous creation.

```bash
ssh administrator@93.127.143.153
cd /opt/webapps/lec-biotech
docker compose config --quiet
# required variable DB_NAME is missing a value: set DB_NAME in .env
```

### 3. Key Findings

- Remote `.env`: missing.
- `lec_api`, `lec_worker`, and `lec_beat`: running four weeks old with
  `APP_VERSION=0.0.0`.
- `lec_biotech_ascend`: running the old `lec-web` image, also four weeks old.
- PostgreSQL, Redis, API, worker, and web containers are currently running and
  report healthy where health checks apply.
- The migration container exited successfully four weeks ago, but the current
  migration revision was not trusted because the Compose configuration cannot
  be reproduced without the environment file.

## Root Cause

Production configuration is treated as a local deployment prerequisite but is
not provisioned or verified at the remote application directory. The deploy
script's commented `.env` copy line leaves the VPS without the configuration
required by the checked-in Compose contract.

## Prevention / Rule

**Guardrail:** `deploy.sh` must fail closed unless the remote `.env` exists and
the remote `docker compose config --quiet` succeeds before any image build or
service mutation.

This makes the remote configuration an explicit preflight invariant and
prevents a deployment from proceeding with stale container environment state
or an unreproducible Compose definition.

## Solution

### Immediate Fix

No production changes were made. Deployment was stopped pending confirmation
and secure provisioning of the real production environment configuration.

### Long-term Fix

- Provision the real `.env` on the VPS through the approved secret-management
  path; never commit or print it.
- Update `deploy.sh` to verify remote configuration and environment-key
  completeness before `docker compose up`.
- Stamp the verified commit identity into every application container.
- Run migration, readiness, artifact-identity, and read-only smoke checks after
  deployment.

## Prevention

- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues

- `LEC-BIOTEC-2026-11-12-open-pr-ci-runner-drift.md`

## References

- `deploy.sh`
- `docker-compose.yml`
- `.env.example`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/10. Deployment And Maintenance.md`

---

**Resolved By:** Pending production owner action
**Time to Resolution:** Open
