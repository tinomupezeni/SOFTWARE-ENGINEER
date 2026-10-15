# Search filters were applied only to the loaded client page

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The Search page fetched a broad listing page and then applied query, category, price, condition, and location filters in the browser. With paginated API results, valid matches on later pages were invisible and result counts described only the current page rather than the marketplace.

## Symptoms
- Search matched only listings already present in the current response page.
- Filter counts were inconsistent with server pagination.
- Seller fields and swap preferences were not searchable.
- Sorting was performed after the page had already been truncated by the API.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Search page and listings API
- **Related Components:** `Search.tsx`, `/api/listings/`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Compared the Search page's client-side filtering chain with the paginated listings response.

### 2. Root Cause Analysis
The browser filtered `products` after `Server.fetchProducts()` returned one API page. The backend accepted only a subset of the available search and filter parameters.

```bash
gh search code 'filter_backends SearchFilter' --language Python --limit 10
gh search code 'Q(name__icontains' --language Python --limit 10
```

### 3. Key Findings
- GitHub implementations generally apply filtering and ordering before pagination.
- The backend already owned listing retrieval and proximity ordering.
- Search terms could safely be applied as an AND across terms, with OR matching across listing and seller fields.

## Root Cause
Search responsibilities were split incorrectly: the server paginated before the client filtered and sorted.

## Prevention / Rule
**Guardrail:** Search, filtering, relevance ordering, and pagination must be completed by the listings API; the frontend must render the returned result set without re-filtering it.

This prevents page-local search omissions and keeps counts, sorting, and result availability consistent.

## Solution

### Immediate Fix
Moved search filters and sorting parameters into the API request and removed duplicate client-side filtering/sorting.

### Long-term Fix
Added API regression tests for multi-term seller/listing search, server-side condition/price filters, and invalid price ranges.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Related to proximity-aware listing ranking and dynamic marketplace listing APIs.

## References
- `swappify-social-hub/src/pages/Search.tsx`
- `backend/modules/listings/views.py`
- `backend/modules/listings/test_search.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
