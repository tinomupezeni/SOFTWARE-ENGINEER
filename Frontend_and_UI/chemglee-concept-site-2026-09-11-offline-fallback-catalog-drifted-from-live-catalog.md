# Offline Fallback Catalog Was a Stale Early Mock Range, Not a Mirror of the Live Catalog

**Date:** 2026-09-11
**Project:** chemglee-concept-site
**Environment:** Production + Development
**Severity:** Medium
**Status:** Resolved

## Summary
`frontend/src/lib/fallbackCatalog.ts` is rendered client-side whenever the
storefront can't reach the products API, so the shop never shows an empty
page. It held an early, hand-written mock product range — items like
"Toilet Dip," "Tyre Polish," "Radiator Coolant," and "Hand Cleaner Paste" —
that were never part of the real catalog, at different prices and with
different images than what the live API actually returns. Anyone who hit the
fallback path saw a shop selling different products than the live one, not a
same-but-slightly-old version of it.

## Symptoms
- Fallback view showed products that don't exist in the real catalog at all.
- Prices and images in the fallback view didn't match the live site even for
  products that share a name.
- Made [[2026-09-11-www-subdomain-cors-misconfiguration-served-stale-catalog]]
  far more visible than a CORS bug alone would have been — instead of "a few
  products missing," `www` visitors saw an unrelated-looking storefront.

## Root Cause
The fallback snapshot was written once, early in development, as placeholder
mock data, and nothing ever kept it in sync as the real product range,
pricing, and imagery were built out in the backend. It was never treated as
"a snapshot of production" — just as a stand-in shop.

## Prevention / Rule
**Guardrail:** A scheduled CI job that regenerates `fallbackCatalog.ts` from the live `/api/products/` response and opens a diff/PR if it changed, plus a build-time check that fails if the file's generation timestamp is older than a set threshold (e.g. 30 days).

This turns "someone remembers to refresh the mock data" into an automated, dated artifact — any file meant to be "a snapshot of production" needs a mechanism that actually re-takes the snapshot, not a comment asking a future person to.

## Solution
Replaced the entire fallback list with an actual snapshot of the live
`/api/products/` response (taken 2026-09-11), matching real product names,
slugs, prices, and S3-hosted images, with a comment marking it explicitly as
a point-in-time mirror of the live catalog to keep updated going forward.

## Prevention
- [ ] No automated check ties this fallback snapshot to the live catalog —
      the next time products/prices change in the backend, this file can
      silently drift out of sync again with no warning. Worth a periodic
      manual refresh, or a script that regenerates it from the live API.

## Related Issues
- [[2026-09-11-www-subdomain-cors-misconfiguration-served-stale-catalog]]

## References
- `frontend/src/lib/fallbackCatalog.ts`
- Merged via PR #3 (`feat/admin-ux-postgres` → `main`), commit `ec3400c`

---

**Resolved By:** winstonjthinker (PR #3), merged by tinomupezeni
**Time to Resolution:** Same session as discovery
