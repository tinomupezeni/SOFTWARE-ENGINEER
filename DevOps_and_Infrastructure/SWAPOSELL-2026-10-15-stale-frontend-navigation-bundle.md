# Stale Frontend Navigation Bundle

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary

The Home icon source change was not visible at `localhost:8080` because the
nginx frontend container was still serving a previously built Vite bundle.
Rebuilding and recreating the frontend container deployed the updated
navigation.

## Symptoms

- The source navigation mapped the primary destination to Lucide's `Home`
  icon, but the browser still showed the previous navigation appearance.
- The served HTML referenced the older bundle `index-CkiSsq7X.js`.

## Environment Details

- **Server/Host:** Local Docker Compose frontend at `http://localhost:8080`
- **Services Affected:** Frontend nginx container
- **Related Components:** Vite production build, Docker Compose frontend
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis

Compared `Navbar.tsx` with the served frontend container and inspected
frontend logs and the active asset referenced by nginx.

### 2. Root Cause Analysis

The host-side `npm run build` updated the working tree's `dist` output but the
nginx container serves assets baked into its image during `docker compose
build frontend`. The container had not been rebuilt after the navigation
change.

### 3. Key Findings

- Source had `icon: Home`.
- The running container served the prior bundle.
- Rebuilding the image changed the active bundle to `index-BuqROgz9.js`.
- The container then returned HTTP 200 for the frontend root.

## Root Cause

The local verification workflow did not automatically rebuild the Docker
frontend image after frontend source changes, allowing nginx to serve stale
compiled assets.

## Prevention / Rule

**Guardrail:** After frontend source changes, local Docker verification must
run `docker compose build frontend --quiet && docker compose up -d frontend`
before checking browser-visible behavior.

This ensures the served nginx image contains the same compiled bundle that
passed the host-side Vite build.

## Solution

### Immediate Fix

Rebuilt and recreated the frontend container, then verified the active bundle
and HTTP response.

### Long-term Fix

Use the container rebuild as the required local deployment check whenever
testing behavior at `localhost:8080`.

## Prevention

- [x] Frontend image rebuild completed
- [ ] Monitoring/alerts needed
- [x] Documentation updated through this issue log
- [ ] Additional code changes required

## Related Issues

- `Frontend_and_UI/SWAPOSELL-2026-10-15-missing-home-navigation-icon.md`

## References

- `swappify-social-hub/src/components/Navbar.tsx`
- `swappify-social-hub/Dockerfile`

---

**Resolved By:** Copilot
**Time to Resolution:** Same session
