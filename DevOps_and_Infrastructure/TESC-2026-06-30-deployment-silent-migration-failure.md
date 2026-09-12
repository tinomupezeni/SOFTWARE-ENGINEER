# Deployment Reported Success While Migration Never Ran

**Date:** 2026-06-30
**Project:** TESC (ScalarEye)
**Environment:** Production / VPS
**Severity:** Critical
**Status:** Investigating

## Summary
The TESC deployment pipeline could report completion while targeting a nonexistent backend container for database migrations. The script used `docker exec tesc-backend-1 ... || true`, while the running container was `tesc-main-backend-1`. The suppressed error could leave migrations unapplied and contribute to gateway timeouts.

## Symptoms
- Users observed a `504 Gateway Timeout` through the gateway.
- Backend and frontend containers appeared to be running.
- The migration step did not fail the deployment when its container name was wrong.

## Environment Details
- **Server/Host:** TESC VM
- **Services Affected:** Backend, gateway, and migration step
- **Related Components:** `deploy_pipeline.sh`, Docker Compose naming
- **Time First Observed:** 2026-06-30

## Investigation Steps

### 1. Initial Diagnosis
Compared `docker ps` names with the name hard-coded in the deployment script and separated direct-backend checks from gateway checks.

### 2. Root Cause Analysis
The script targeted `tesc-backend-1`, but Docker was running `tesc-main-backend-1`. The trailing `|| true` converted the failed `docker exec` into a successful-looking pipeline step.

### 3. Key Findings
- Container names were assumed instead of resolved from Compose.
- A release-critical migration command had error suppression.
- The gateway symptom could only be diagnosed reliably after validating the backend directly.

## Root Cause
Deployment automation used a stale container name and suppressed the resulting migration failure.

## Prevention / Rule
**Guardrail:** Deploy scripts run migrations via `docker compose exec <service-name-from-compose>` — never a hand-typed container name — with no `|| true` on the command, and the deploy step then queries `django_migrations` for the expected latest migration name and fails the deploy if it isn't there.

Two independent failures have to both happen for this bug to hide: a name mismatch (compose service name vs. the container's actual runtime name) and error suppression on the command that would have surfaced it. Resolving the service name through Compose itself removes the first; refusing to swallow a non-zero exit on a release-critical step removes the second — either alone would have caught this.

## Solution

### Immediate Fix
Run migrations against the actual Compose service and inspect backend logs and localhost responses independently of the gateway.

```bash
docker compose ps
docker compose exec <backend-service> python manage.py migrate --noinput
docker compose logs --tail 50 <backend-service>
curl -I http://localhost:8000/api
```

### Long-term Fix
Use `docker compose exec <service>` or a machine-readable service lookup instead of hard-coded generated container names. Remove `|| true` from migrations, health checks, and release-critical steps.

## Prevention
- [ ] Replace hard-coded container names with Compose service names
- [ ] Remove error suppression from migration and health-check steps
- [ ] Add a CI/deployment gate proving migrations ran successfully
- [ ] Add direct-container and gateway-level verification

## Related Issues
- Guide 19: Issue-to-Verified-Production Engineering Workflow

## References
- Antigravity CLI history, TESC workspace, 2026-06-30

---

**Resolved By:** Not yet resolved in available history
**Time to Resolution:** Unknown
