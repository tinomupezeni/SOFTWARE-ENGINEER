# Staging structured logs tagged deployment.environment=production

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Staging
**Severity:** Low
**Status:** Resolved

## Summary
Every structured log line emitted by HBEC's staging Django services (admin
and student backends, plus their worker/beat Celery processes) carried
`"deployment.environment": "production"` instead of `"staging"`, making log
aggregation/filtering by environment silently wrong on staging.

## Symptoms
- Noticed while manually verifying the IGCSE `Grade.Phase` change on staging
  (see the `feat(admin): add IGCSE to Grade.Phase...` work): a test Grade
  created via `manage.py shell` on the staging container emitted an outbox
  log line stamped `"deployment.environment": "production"`.
- No errors, no user-facing impact — purely a log-field correctness issue,
  but a real hazard for anyone querying logs/APM by environment.

## Environment Details
- **Server/Host:** hbca-vps, `/home/winstontino/HBEC` (staging)
- **Services Affected:** `admin-backend`, `admin-worker`, `admin-beat`,
  `student-backend`, `student-worker`, `student-beat` (all 6 Django-based
  staging services — anywhere `core/logging.py` runs)
- **Related Components:** `docker-compose.staging.yml`
- **Time First Observed:** 2026-09-10, during IGCSE staging verification

## Investigation Steps

### 1. Initial Diagnosis
A shell-created test row's log line showed `deployment.environment:
production` despite running against the staging container.

### 2. Root Cause Analysis
Grepped both backends for the log field:
```bash
grep -rn "APP_ENV" ADMIN/adminBackend/ STUDENT/hbec_backend/
```
Found both `ADMIN/adminBackend/core/logging.py:19` and
`STUDENT/hbec_backend/core/logging.py:83` set the field as:
```python
"deployment.environment": os.getenv("APP_ENV", "production"),
```
Checked `docker-compose.staging.yml` — `APP_ENV` was never set in any of the
6 Django service `environment:` blocks (only `DJANGO_SETTINGS_MODULE:
config.settings.production`, which is a genuinely correct Django settings
module name shared by both environments, not an environment label).

### 3. Key Findings
- Not a hardcoded literal — `APP_ENV` is read from the environment with a
  `"production"` fallback, and staging simply never set it.
- Affects all 6 Django services on staging identically, since they share the
  same `core/logging.py` pattern.
- `docker-compose.production.yml` was unaffected — it correctly falls back
  to `"production"` by omission, since that happens to be the right value
  there too, which is likely why this went unnoticed.

## Root Cause
`docker-compose.staging.yml` never set the `APP_ENV` environment variable
for any Django service, so `core/logging.py`'s `os.getenv("APP_ENV",
"production")` silently defaulted to `"production"` on staging.

## Prevention / Rule
**Guardrail:** A compose-file linter (or a simple diff script run in CI)
that compares every environment-identifying variable block (`APP_ENV`,
`DEPLOYMENT_ENV`, etc.) across `docker-compose.staging.yml` and
`docker-compose.production.yml` for each shared service, and fails if one
defines it and the sibling doesn't.

A silently-defaulting env var is exactly what let this hide: the guardrail
doesn't remove the fallback (a sane default is fine), it catches the
specific case of one environment's compose file simply never setting a
variable the other one relies on being explicit.

## Solution

### Immediate Fix
Added `APP_ENV: staging` immediately after `DJANGO_SETTINGS_MODULE:
config.settings.production` in all 6 staging service blocks
(`docker-compose.staging.yml`): `student-backend`, `admin-backend`,
`student-worker`, `student-beat`, `admin-worker`, `admin-beat`. Committed as
`fafe7fcf`, pushed to `master` (auto-deploys staging per `cd.yml`).

### Long-term Fix
None needed beyond the above — production already resolves correctly via
the default and was left untouched.

## Prevention
- [x] Configuration changes needed — done (`APP_ENV: staging` added)
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a
- [ ] Code changes required — none; `core/logging.py`'s fallback design is
      fine, the env var was just missing

## Related Issues
- Found during verification of the IGCSE `Grade.Phase` addition
  (2026-09-10), unrelated to that change itself.

## References
- `ADMIN/adminBackend/core/logging.py:19`
- `STUDENT/hbec_backend/core/logging.py:83`
- `docker-compose.staging.yml`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~15 minutes
