# seed_catalog (Demo/Mock Data) Was Documented as a Deploy Step, Ran Against a Populated Production Database

**Date:** 2026-09-18
**Project:** chemglee-concept-site
**Environment:** Production
**Severity:** Medium (mock data mixed into a real product catalogue; the "14 vs 18 products" symptom users actually saw)
**Status:** Resolved (merged to `main` via PR #4)

## Summary
Found during the same site-content audit as commit `c224bb6`. The
storefront showed 14 products in some contexts and 18 in others. Root cause:
`seed_catalog` — an early mock-data management command — was listed in the
production README as a step to run on deploy, with no guard against running
it against a database that already has real products. 18 is the mock
count; 14 is the real shop. This is the same *shape* of bug as
`chemglee-concept-site-2026-09-11-offline-fallback-catalog-drifted-from-live-catalog.md`
(`Frontend_and_UI/`) — a stale/mock snapshot standing in for the real
catalogue — but on the backend seed path rather than the frontend fallback
path.

## Root Cause
`seed_catalog` was written as convenience tooling for a fresh/empty
database during early development, then never revisited once the
production README started recommending it as a routine deploy step — with
no check for "does this database already have real products."

## Solution
`seed_catalog` now refuses to touch a database that already has products.
Both READMEs (root and `backend/`) now label it explicitly as demo data, and
the production deploy instructions no longer mention running it at all.

## Prevention
- [x] Code changes required — done (guard added)
- [ ] Documentation to update — done (both READMEs), verify no other
      internal runbook still references running `seed_catalog` on an
      existing production deploy

## References
- Commit `c224bb6` ("Say only what we can back up, and link where every
  claim leads"), merged to `main` in this session's PR #4 merge (`8bcc3dd`).
- `backend/apps/catalog/management/commands/seed_catalog.py`

---

**Resolved By:** winstonjthinker + Claude Opus 5 (1M context), PR #4
**Time to Resolution:** N/A (site audit)
