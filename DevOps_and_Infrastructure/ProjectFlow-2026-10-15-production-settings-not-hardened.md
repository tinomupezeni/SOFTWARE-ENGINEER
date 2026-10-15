# ProjectFlow production settings are not hardened

**Date:** 2026-10-15
**Project:** ProjectFlow
**Environment:** Production configuration
**Severity:** Critical
**Status:** Investigating

## Summary
The Django settings contain development defaults that are unsafe for a deployed API:
`DEBUG` is enabled, every host is allowed, all origins are allowed despite an explicit
comment saying otherwise, and the Django secret key is hard-coded in source. The
configuration can therefore expose debug details, accept unintended host/origin traffic,
and make the signing key available to anyone with repository access.

## Symptoms
- Production behavior would be governed by development security settings.
- Cross-origin requests are accepted from arbitrary origins while credentials are enabled.
- The signing key is not managed as a deployment secret.
- Invalid host headers are not rejected.

## Environment Details
- **Server/Host:** ProjectFlow backend deployment
- **Services Affected:** Django API, authentication, browser clients
- **Related Components:** `projectflow_backend/settings.py`
- **Time First Observed:** 2026-10-15 during a codebase read

## Investigation Steps

### 1. Initial Diagnosis
Read the Django entrypoint configuration and compared security-sensitive defaults
against the repository's secure configuration guidance.

### 2. Root Cause Analysis
The settings file was left in quick-start development mode and does not derive the
security-sensitive values from validated environment configuration. `CORS_ALLOW_ALL_ORIGINS`
also overrides the defined origin list.

```bash
nl -ba projectflow_backend/settings.py | sed -n '31,40p'
nl -ba projectflow_backend/settings.py | sed -n '77,106p'
```

### 3. Key Findings
- `projectflow_backend/settings.py:35` contains a literal Django secret key.
- `projectflow_backend/settings.py:38` sets `DEBUG = True`.
- `projectflow_backend/settings.py:40` sets `ALLOWED_HOSTS = ["*"]`.
- `projectflow_backend/settings.py:106` sets `CORS_ALLOW_ALL_ORIGINS = True`
  while `CORS_ALLOW_CREDENTIALS = True` is enabled at line 83.
- The explicit comment immediately above line 106 says the value must be false,
  confirming configuration drift.

## Root Cause
Development configuration was committed as the active runtime configuration, without
a production settings profile or fail-fast validation for missing/unsafe security
values.

## Prevention / Rule
**Guardrail:** Add a startup configuration validator that fails when production mode
has `DEBUG=True`, wildcard hosts/origins, or a missing/non-placeholder secret key, and
run Django's deployment checks in CI.

This converts unsafe configuration from a review-only concern into a deterministic
boot and CI failure.

## Solution

### Immediate Fix
No code change was made during this read-only investigation. The deployed environment
should be treated as unsafe until the settings are hardened and the exposed signing key
is rotated.

### Long-term Fix
- Load `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, and CORS origins from deployment
  configuration with safe production defaults.
- Remove the committed key and rotate it wherever this application has run.
- Split local development settings from production settings or validate an explicit
  environment mode.
- Add `manage.py check --deploy` and configuration-focused tests to CI.

## Prevention
- [ ] Remove and rotate the committed signing key
- [ ] Disable debug mode in production
- [ ] Replace wildcard hosts and CORS with validated allowlists
- [ ] Add startup and CI configuration validation
- [ ] Run deployment checks before release

## Related Issues
- None found during this read.

## References
- `projectflow_backend/settings.py:31-40`
- `projectflow_backend/settings.py:77-106`
- Principal Engineer Guide 7, Software Security Engineering

---

**Resolved By:** Unassigned
**Time to Resolution:** Open
