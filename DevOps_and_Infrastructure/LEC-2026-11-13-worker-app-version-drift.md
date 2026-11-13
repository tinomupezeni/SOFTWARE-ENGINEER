# Worker and beat containers do not receive the deployed application version

**Date:** 2026-11-13
**Project:** LEC Biotec
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
The production deployment runs the API, Celery worker, and Celery beat from the
same `lec-api:latest` image, but only the API container receives the deployed
`APP_VERSION` value. The API reports commit `389bf1c`, while the worker reports
`0.0.0`, making cross-service artifact identity unreliable.

## Symptoms
- The public deep health endpoint reports version `389bf1c`.
- `lec_api` has `APP_VERSION=389bf1c`.
- `lec_worker` has `APP_VERSION=0.0.0`.
- `lec_beat` uses the same compose pattern and is not given the deploy version.

## Environment Details
- **Server/Host:** `tino-vps` / `administrator@93.127.143.153`
- **Services Affected:** `lec_api`, `lec_worker`, `lec_beat`
- **Related Components:** `docker-compose.yml`, `deploy.sh`, deployment health/version reporting
- **Time First Observed:** 2026-11-13 19:00 UTC

## Investigation Steps

### 1. Initial Diagnosis
Checked the running Compose project, container image IDs, container environment,
public health endpoints, and applied migrations over SSH.

### 2. Root Cause Analysis
The production Compose file explicitly sets `APP_VERSION` on `api` only:

```yaml
api:
  environment:
    APP_VERSION: ${APP_VERSION:-0.0.0}
```

`worker` and `beat` load `.env` but do not declare the exported deployment
version. The image is shared, but runtime environment variables are
container-specific, so those processes fall back to `.env`'s `APP_VERSION=0.0.0`.

### 3. Key Findings
- `lec_api` image ID: `sha256:ef102b64...`; `APP_VERSION=389bf1c`.
- `lec_worker` uses the same image ID but has `APP_VERSION=0.0.0`.
- Public shallow and deep health checks returned HTTP 200.
- Deep health reported database, cache, and storage as up.
- All migrations were applied and the migration job exited with code 0.

## Root Cause
The Compose service definitions are not configuration-parity complete: the
deployment identity is passed to the API but omitted from the Celery services.

## Prevention / Rule
**Guardrail:** Add a CI configuration-parity check that requires every service
built from the application image to declare or inherit the same `APP_VERSION`
runtime value, and make deployment verification compare the value across API,
worker, and beat.

This prevents a shared image from being mistaken for shared runtime identity and
ensures logs and task processing can be tied to the exact deployed source.

## Solution

### Immediate Fix
Added `APP_VERSION: ${APP_VERSION:-0.0.0}` to the `worker` and `beat` services
in `docker-compose.yml`, committed as `3ff367d`, and deployed it to production.

### Long-term Fix
Add a deployment verification check that fails when the API, worker, and beat
report different versions.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation updated
- [x] Code changes required

## Related Issues
- `LEC-BIOTEC-2026-11-12-production-env-missing.md`
- `LEC-BIOTEC-2026-11-12-open-pr-ci-runner-drift.md`

## References
- `/home/shadowe/Projects/lec-biotech-ascend/docker-compose.yml`
- `/home/shadowe/Projects/lec-biotech-ascend/deploy.sh`
- Production deep health: `https://lecbiotec.com/api/v1/health/deep`

---

**Resolved By:** Copilot
**Time to Resolution:** Same deployment session
