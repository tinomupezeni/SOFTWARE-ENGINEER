# Unauthenticated Payment Settings Endpoint

**Date:** 2026-10-17
**Project:** HBEC
**Environment:** Source audit; deployment exposure not yet verified
**Severity:** High
**Status:** Resolved in source; deployment validation pending

## Summary
The Admin Backend exposes `InternalPaymentSettingsView` at `/_internal/settings/payment/` with `AllowAny` and decrypts sensitive payment settings before returning them. If the route is reachable from the public ingress, an unauthenticated caller can obtain payment credentials.

## Symptoms
- A source audit found an internal payment configuration endpoint without application-level authentication.
- The view itself states that production restriction or HMAC protection is still required.

## Environment Details
- **Server/Host:** HBEC Admin Backend
- **Services Affected:** `ADMIN/adminBackend`
- **Related Components:** Django URL routing, system settings, payment integration
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis
Traced the internal URL include to the payment settings view and inspected its permission class and response construction.

### 2. Root Cause Analysis
`config/urls.py` includes `apps.system_settings.internal_urls` under `/_internal/settings/`; `internal_urls.py` maps `payment/` to `InternalPaymentSettingsView`; the view uses `AllowAny` and decrypts keys in `SENSITIVE_KEYS`.

### 3. Key Findings
- `ADMIN/adminBackend/config/urls.py:46`
- `ADMIN/adminBackend/apps/system_settings/internal_urls.py:6`
- `ADMIN/adminBackend/apps/system_settings/views.py:664-678`

## Root Cause
The endpoint relies on an unverified deployment boundary instead of enforcing service identity at the application boundary.

## Prevention / Rule
**Guardrail:** Every endpoint under `/_internal/` that returns configuration or performs a privileged action must use the shared service-authentication permission and have a regression test asserting anonymous access is denied.

This prevents a proxy or network-policy drift from turning an internal route into a credential disclosure path.

## Solution

### Immediate Fix
`InternalPaymentSettingsView` now uses `IsInternalService`, matching the signed service-authentication control used by the neighboring internal endpoint. The targeted authorization tests were added, but execution is blocked in this checkout because PostgreSQL is not running on `127.0.0.1:5432`.

### Long-term Fix
Verify that the active ingress rejects public access to `/_internal/settings/payment/` and rotate any payment credentials if public reachability is confirmed. Bind authorization to the payment service identity and return only the minimum required configuration.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## References
- `ADMIN/adminBackend/config/urls.py:46`
- `ADMIN/adminBackend/apps/system_settings/internal_urls.py:6`
- `ADMIN/adminBackend/apps/system_settings/views.py:664-678`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
