# Prod login broken: localhost-baked frontend bundles (VITE_API_URL trap)

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Environment:** Production (https://zchpcerp.zchpc.ac.zw)
**Severity:** Critical
**Status:** Resolved

## Summary

Prod login failed with CORS errors: the frontend called
`http://localhost:8000/api/v2/auth/token/` from the public domain.
The staging-built frontend images (promoted to prod during the design
refresh) had `VITE_API_URL=http://localhost:8000` baked in, because the
staging compose defaults to it and `.env` doesn't override it. Rebuilt
both frontends with explicit per-frontend prod origins, verified zero
`localhost:8000` in the bundles, promoted, and proved the token endpoint
reachable publicly.

## Symptoms

- Browser console on `https://zchpcerp.zchpc.ac.zw`:
  `Access to XMLHttpRequest at 'http://localhost:8000/api/v2/auth/token/'
  ... blocked by CORS policy`, `POST ... net::ERR_FAILED`.
- Login completely unusable on prod; API itself healthy.

## Environment Details

- **Server/Host:** erp-vm (10.50.14.12), `~/zchpc-erp` prod stack
- **Services Affected:** `zchpc_frontend`, `zchpc_portal`
- **Related Components:** `docker-compose.yml` build args,
  `employee-portal/Dockerfile`, `zchpc-erp-synergy-main/Dockerfile`,
  `build-and-push.sh`, both `vite.config.ts` (`define.__API_URL__`)
- **Time First Observed:** 2026-09-29 (tester report during test phase)

## Investigation Steps

### 1. Initial Diagnosis

Confirmed the bundle (not the API) was at fault: API healthy, but the
served JS contained `localhost:8000`. Traced the bake chain: staging
compose passes `VITE_API_URL=${VITE_API_URL:-http://localhost:8000}`;
staging `.env` sets no `VITE_API_URL`; both `vite.config.ts` files bake
`env.VITE_API_URL` into `__API_URL__` at build time.

### 2. Root Cause Analysis

```bash
curl https://zchpcerp.zchpc.ac.zw/api/v2/health/   # 200
curl https://employees.zchpc.ac.zw/api/v2/health/  # 200
```

cPanel proxies `/api/*` to the backend on **both** domains, so frontend
→ API is same-origin and needs no CORS — provided the bundle calls its
own origin. The localhost-baked bundle turned every API call into a
cross-origin call to the tester's own machine: unfixable server-side.

### 3. Key Findings

- Both frontends read the same var through two mechanisms
  (`import.meta.env` + `__API_URL__` define) — consistent values, so one
  build-arg fixes both.
- `build-and-push.sh` already encoded the correct per-frontend origins;
  the staging-compose path bypassed it.
- Portal Dockerfile default was the *admin* origin (wrong for no-arg
  portal builds).

## Root Cause

Vite embeds `VITE_API_URL` at build time. Staging builds default it to
`localhost:8000`, and those images were promoted to prod during the
design refresh — carrying a dev API URL into production.

## Prevention / Rule

**Guardrail:** never promote a frontend image without grepping the built
bundle for `localhost` first (`grep -o "localhost:8000" .../assets/*.js`
must be empty); bake the check into any promote/retag step. Long-term:
split the compose var per frontend (`VITE_API_URL_FRONTEND`,
`VITE_API_URL_PORTAL`) so one shared default can't serve two origins.

## Solution

### Immediate Fix

1. `employee-portal/Dockerfile` default → `https://employees.zchpc.ac.zw`
   (PR #34, merged `3cc52fe`).
2. Rebuilt on VM with explicit args:
   `frontend → https://zchpcerp.zchpc.ac.zw`,
   `portal → https://employees.zchpc.ac.zw` (== `build-and-push.sh`).
3. Verified bundles: correct origin present, `localhost:8000` absent
   (both staging and prod containers), then retagged + recreated prod.

### Long-term Fix

- Per-frontend compose vars (above); add the bundle-grep to the deploy
  checklist for every frontend promote.

## Prevention

- [x] Configuration changes needed (Dockerfile default + build procedure)
- [ ] Compose: split `VITE_API_URL` per frontend (follow-up)
- [ ] Deploy checklist: mandatory bundle-grep before promote

## Related Issues

- Design refresh promotion that carried the bad bake:
  `reports/ZCHPC-2026-09-29-design-refresh-contrast-sidebar.md`

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/34
- `DEPLOYMENT-STANDARDS.md` (Vite build-arg section — this incident is
  exactly the failure it describes)

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~40 min
