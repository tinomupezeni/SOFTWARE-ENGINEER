# www.chemgleeonline.com Was CORS-Blocked, So Visitors There Saw a Different, Stale Catalog

**Date:** 2026-09-11
**Project:** chemglee-concept-site
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Caddy served the same storefront SPA on both `chemgleeonline.com` and
`www.chemgleeonline.com`, but `backend/config/settings/production.py`'s
`CORS_ALLOWED_ORIGINS` only ever listed the bare domain. Every API call from a
browser on `www` was rejected by CORS, so the frontend silently treated the
API as unreachable and rendered the hardcoded offline fallback catalog
instead — a different, older 18-product range at different prices, under a
"live catalog is unreachable" banner. Two people looking at the same
storefront on the same day, one via `www` and one via the bare domain, saw
different products.

## Symptoms
- Products page showed fewer/different items with old prices on `www`.
- "Live catalog is unreachable" banner shown on `www` even though the API was
  healthy.
- Behavior differed by device/browser only because of which host name a
  visitor happened to land on (e.g. via a shared `www` link vs. a bookmark to
  the bare domain).

## Environment Details
- **Services Affected:** Django backend (CORS config), Caddy edge routing,
  React storefront (`useProducts` hook, product catalog rendering)
- **Related Components:** `Caddyfile.prod`, `backend/config/settings/production.py`,
  `frontend/src/hooks/useProducts.ts`
- **Time First Observed:** found during review of PR #3 (`feat/admin-ux-postgres`)

## Root Cause
`CORS_ALLOWED_ORIGINS` was derived from `ALLOWED_HOSTS`/configured origins
without ever pairing an origin with its `www.`/bare counterpart, so only one
of the two publicly reachable hostnames could actually call the API. The
frontend had no visibility into *why* a request failed — a CORS rejection and
a genuine outage both just look like a failed fetch — so it fell back to the
offline snapshot in both cases.

A second factor made it worse: `useProducts` only retried a failed request
once (`retry: 1`), so even a transient blip on a patchy mobile connection
could tip a request into the same fallback path.

## Solution
- `production.py` now runs every configured CORS origin through a
  `_with_www_twins()` helper that adds the missing `www.`/bare counterpart for
  each origin (skipping `localhost`/`127.*`).
- `Caddyfile.prod` also collapses the two live origins into one canonical
  address: `www.chemgleeonline.com` now permanently redirects to
  `chemgleeonline.com` instead of being reverse-proxied as a second copy of
  the SPA. This removes the two-origins-for-one-site situation at the root,
  not just the CORS symptom of it.
- `useProducts` retry bumped from 1 to 3 attempts with backoff (0.5s/1s/2s),
  so a real transient blip no longer looks identical to a hard outage.

## Prevention
- [ ] Add CORS origins to whatever pre-deploy production settings check
      already exists (`chore: harden postgres deployment checks` added one
      for Postgres; CORS/ALLOWED_HOSTS pairing would fit the same pattern)
- [ ] Since `www` now redirects rather than serving the SPA, confirm no other
      code still assumes `www.chemgleeonline.com` is a first-class origin
      (e.g. hardcoded absolute URLs, canonical tags)

## Related Issues
- [[2026-09-11-offline-fallback-catalog-drifted-from-live-catalog]] — the
  fallback catalog this bug was silently routing visitors into was itself
  stale relative to the real live catalog, which is why the wrong-CORS symptom
  looked like "totally different products," not just "missing a few."

## References
- `Caddyfile.prod`, `backend/config/settings/production.py`,
  `frontend/src/hooks/useProducts.ts`
- Merged via PR #3 (`feat/admin-ux-postgres` → `main`), commit `ec3400c`

---

**Resolved By:** winstonjthinker (PR #3), merged by tinomupezeni
**Time to Resolution:** Same session as discovery
