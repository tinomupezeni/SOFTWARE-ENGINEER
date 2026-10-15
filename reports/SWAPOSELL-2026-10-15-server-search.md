# Server-backed marketplace search

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Feature / Search Architecture
**Status:** Completed

## Summary
Implemented a server-backed search experience for Swap-O-Sell. Search now supports multi-term matching across listing and seller data, server-side category/price/condition/location filters, relevance ordering, proximity ranking, and pagination without losing matches outside the current client page.

## Context / Trigger
The existing Search page fetched listings and applied its filters in React. This produced incomplete results with pagination and did not search seller identity or swap preference text. GitHub code searches were used to compare common Django/marketplace query patterns before changing the boundary.

## Scope
Included the listings API query contract, Search page request parameters, relevance ordering, input validation, and focused API tests. Full-text search infrastructure such as PostgreSQL `SearchVector`, Elasticsearch, typo tolerance, autocomplete suggestions, and search analytics were intentionally deferred until dataset size and usage justify the operational cost.

## Method
Reviewed the existing API and UI, checked GitHub implementations using `gh search code`, moved filtering before pagination, split queries into terms combined with AND semantics, matched each term across listing and seller fields with OR semantics, and retained proximity ordering when coordinates are supplied.

## Decisions & Findings
- Search terms match listing name, description, category, location, swap preferences, seller username/name, and seller location.
- Multiple search terms must all match somewhere, avoiding overly broad results for phrases such as `solar harare`.
- Relevance ordering prioritizes name, category, seller username, description, and location matches before recency.
- Price bounds are validated by the API, including min-greater-than-max rejection.
- The frontend sends filters to the server and renders the returned page directly.
- PostgreSQL full-text search and autocomplete are deferred; the current `icontains` approach is appropriate for the current scale and avoids premature infrastructure.

## Changes Made
- Updated `backend/modules/listings/views.py` with server-side search terms, seller-field matching, condition filtering, price validation, and relevance ordering.
- Updated `swappify-social-hub/src/pages/Search.tsx` to send all search/filter/sort parameters and remove client-only filtering.
- Added `backend/modules/listings/test_search.py` with three focused API tests.
- Added issue log `SWAPOSELL-2026-10-15-search-pagination-filtering.md`.

## Verification
- `gh search code` completed for GitHub comparison patterns.
- Django system checks passed.
- Three search API tests passed.
- Frontend `npm run build` passed.
- Backend and frontend Docker images rebuilt successfully.
- `http://localhost:8080/` and proxied `/api/health/` returned successfully.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add Playwright coverage for typing, filters, empty results, and pagination.
- Add a dedicated autocomplete/suggestions endpoint if search behavior warrants it.
- Consider PostgreSQL full-text indexes or trigram search when listing volume makes `icontains` expensive.
- Add search analytics for zero-result queries and conversion.

## References
- `backend/modules/listings/views.py`
- `backend/modules/listings/test_search.py`
- `swappify-social-hub/src/pages/Search.tsx`
- `SWAPOSELL-2026-10-15-search-pagination-filtering.md`

---

**Completed By:** Copilot
**Duration:** Same development session
