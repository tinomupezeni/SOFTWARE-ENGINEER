# Production configuration exposes unsafe defaults

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The production deployment explicitly enables Django debug mode and the application settings allow every host and CORS origin. The production Compose file also supplies the default PostgreSQL password directly in deployment configuration. Together these defaults weaken production isolation and can expose diagnostics, broaden browser access, and leave the database protected by a predictable credential.

## Symptoms
- Production configuration is permissive by default rather than failing closed.
- Deployment configuration contains a predictable database password.
- The application can expose Django debug behavior if deployed as currently configured.

## Environment Details
- **Server/Host:** VPS deployment through `deploy.sh`
- **Services Affected:** Django backend and PostgreSQL
- **Related Components:** `projectflow_backend/settings.py`, `docker-compose.prod.yml`
- **Time First Observed:** 2026-10-15 during codebase review

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the Django settings and production Compose configuration.

### 2. Root Cause Analysis
The settings module contains permissive development defaults, while the production Compose service overrides `DEBUG` to `True` and injects `POSTGRES_PASSWORD=postgres`.

```bash
grep -nE 'DEBUG|ALLOWED_HOSTS|CORS_ALLOW_ALL_ORIGINS' projectflow_backend/settings.py
grep -nE 'DEBUG|POSTGRES_PASSWORD|DB_PASSWORD' docker-compose.prod.yml
```

### 3. Key Findings
- `projectflow_backend/settings.py` sets `DEBUG = True`.
- `projectflow_backend/settings.py` sets `ALLOWED_HOSTS = ["*"]`.
- `projectflow_backend/settings.py` sets `CORS_ALLOW_ALL_ORIGINS = True` while credentials are enabled.
- `docker-compose.prod.yml` sets `DEBUG=True` and `DB_PASSWORD=postgres`.
- `projectflow_backend/settings.py` contains a hardcoded Django `SECRET_KEY`.

## Root Cause
Development configuration was retained as the effective production configuration, and sensitive deployment values were kept as source-controlled defaults instead of being required at runtime.

## Prevention / Rule
**Guardrail:** Add a CI configuration gate that runs Django deployment checks with production environment variables and fails if `DEBUG` is true, `ALLOWED_HOSTS` or CORS is wildcarded, or a production secret/database credential uses a repository default.

This catches the exact unsafe settings before deployment and prevents permissive development defaults from silently becoming production behavior.

## Solution

### Immediate Fix
No code or deployment fix was applied during this read-only review.

### Long-term Fix
- Load `SECRET_KEY`, database credentials, `DEBUG`, `ALLOWED_HOSTS`, and allowed CORS origins from required environment variables.
- Remove `DEBUG=True` and plaintext default credentials from `docker-compose.prod.yml`.
- Add production startup validation and Django deployment-check CI coverage.
- Rotate any credentials that have been used outside local development.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- None known.

## References
- `projectflow_backend/settings.py`
- `docker-compose.prod.yml`
- Secure Application Configuration Guide (`SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/5. Secure Application Configuration.md`)

---

**Resolved By:** Unassigned
**Time to Resolution:** Ongoing
