# TESC Production Incident: Dashboard TypeErrors, Missing Admin Privileges, and DNS/Routing Failures

**Date:** YYYY-MM-DD
**Project:** TESC
**Environment:** Production (VM 10.50.200.35)
**Severity:** High
**Status:** Resolved

## Summary
The TESC production instance experienced multiple interconnected failures. Several dashboard pages crashed with `TypeError` due to unexpected pagination formats. The System Admin lost access to the "User Management" tab. Finally, direct IP access broke the frontend due to hardcoded API ports, while the main domain name threw `ERR_NAME_NOT_RESOLVED` because of a missing DNS record.

## Symptoms
- **Dashboard Crashes:** Users experienced blank pages on `/dashboard/innovation`, `/dashboard/special-enrollment`, and `/dashboard/scholarships` with console errors like `TypeError: e.filter is not a function` and `s.map is not a function`.
- **Missing Privileges:** The `admin@scalareye.com` user (System Admin) could not see the User Management tab under Settings.
- **API Connection Failures:** When accessing the site via raw IP (`10.50.200.35`), API calls failed. Accessing via `tesc.zchpc.ac.zw` resulted in `ERR_NAME_NOT_RESOLVED`.

## Environment Details
- **Server/Host:** 10.50.200.35 (VM)
- **Services Affected:** `tesc-main-frontend_client`, `tesc-main-frontend_admin`, `tesc-main-backend`
- **Related Components:** React frontend (Vite), Django backend (Gunicorn/Nginx)
- **Time First Observed:** 2026-07-08

## Investigation Steps

### 1. Dashboard TypeErrors
- Reviewed the frontend code crashing on `e.filter` and `s.map`.
- Discovered that the backend API was returning paginated objects (e.g., `{ count: X, results: [...] }`) instead of flat JSON arrays. The frontend expected raw arrays.

### 2. Missing User Management Tab
- Inspected `frontend/src/pages/Settings.tsx` and found the visibility condition was `currentUser?.level === "1"`.
- Investigated the backend models and realized `level` was removed from the `CustomUser` model in migration `0002_remove_customuser_level`.
- Checked `UserProfileSerializer` and found it did not expose `is_superuser` to the frontend.

### 3. DNS and API Routing Failures
- The user attempted to access `tesc.zchpc.ac.zw` and hit a DNS `SERVFAIL`. Ran `nslookup tesc.zchpc.ac.zw` to confirm the authoritative nameserver lacks an A-record.
- When accessed via raw IP (`10.50.200.35`), the frontend's `api.ts` file dynamically fell back to `http://10.50.200.35:8000/api`.
- Port 8000 is intentionally closed on the host firewall (routed internally via Nginx), causing connection refusals.

## Root Cause
1. **TypeErrors:** Global DRF pagination was enabled without corresponding frontend updates.
2. **Privileges:** Hardcoded legacy field (`level`) in the frontend after it was removed from the backend database schema.
3. **Routing:** `api.ts` used fragile absolute URL generation instead of relative paths, and public DNS records were incomplete.

## Prevention / Rule
**Guardrail:** A CI contract check that generates the frontend's expected API shape (fields it reads, functions it imports) and diffs it against the backend's actual current schema/serializer output and model fields — failing the build when the frontend still references a field the backend removed (`level`) or expects a shape the backend no longer sends (flat arrays vs. paginated objects).

Both the pagination TypeError and the missing-privileges bug are the same root shape: the backend's contract changed (pagination enabled, `level` field removed) and nothing forced a corresponding frontend update or even flagged the mismatch. A single automated contract check spanning both sides would catch either class of drift before deploy, rather than as a live dashboard crash.

## Solution

### Immediate Fix
1. **Privileges:** 
   - Added `is_superuser` to `UserProfileSerializer`.
   - Patched `frontend/src/pages/Settings.tsx` to check `is_superuser || role.name === "System Admin"`.
2. **API Routing:**
   - Patched both `frontend/src/services/api.ts` and `inst/src/services/api.ts` to return `/api` (relative path) instead of absolute URLs.
3. **Rebuild:**
   - Ran `docker compose up --build -d frontend_client frontend_admin` to apply frontend changes.

```bash
# Commands used to patch api.ts on VM
sed -i "s/return \`${protocol}\/\/${hostname}:8000\/api\`;/return \"\/api\";/g" frontend/src/services/api.ts
sed -i "s/return \`${protocol}\/\/${hostname}\/api\`;/return \"\/api\";/g" frontend/src/services/api.ts
sed -i "s/return \"https:\/\/tesc.zchpc.ac.zw\/api\";/return \"\/api\";/g" frontend/src/services/api.ts
```

### Long-term Fix
- Ensure all frontend API clients use relative routing to gracefully handle any domain, IP, or reverse proxy setup without breaking.

## Prevention
- [ ] Configuration changes needed: Add DNS A Record for `tesc.zchpc.ac.zw` pointing to `10.50.200.35`.
- [ ] Code changes required: Audit all legacy frontend files for the deprecated `user.level` attribute.

## References
- TESC Backend Commits
- Local DNS testing via `nslookup`

---

**Resolved By:** Antigravity AI
**Time to Resolution:** ~1 Hour
