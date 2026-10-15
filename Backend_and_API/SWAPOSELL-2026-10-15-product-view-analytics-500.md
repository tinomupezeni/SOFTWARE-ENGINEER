# Product Detail Returned 500 While Updating View Analytics

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The UUID product detail endpoint returned HTTP 500 whenever a listing was opened because view tracking assigned a Django `F()` expression to `product.views` and immediately passed that unresolved expression into analytics updates.

## Symptoms
- `GET /api/listings/<product-uuid>/` returned HTTP 500.
- The response reported: `int() argument must be a string, a bytes-like object or a real number, not 'CombinedExpression'`.
- The failure occurred during the normal detail-page view-tracking path.

## Environment Details
- **Server/Host:** Local Docker Compose development environment
- **Services Affected:** Django listing API
- **Related Components:** `modules/listings/views.py`, product view analytics
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Requested a live product using its new UUID public ID and inspected the backend response and container logs.

### 2. Root Cause Analysis
`track_product_view()` assigned `F('views') + 1` to the in-memory model instance, saved it, and then called `update_product_analytics(product)`. The in-memory value remained a `CombinedExpression`, not the persisted integer.

```bash
curl http://localhost:8000/api/listings/<product-uuid>/
docker compose logs --tail=80 backend
```

### 3. Key Findings
- The UUID lookup itself succeeded.
- The 500 happened after the lookup while tracking the view.
- The analytics serializer expected a numeric view count.

## Root Cause
The code relied on a database-side expression without refreshing the model instance before using the field in application code.

## Prevention / Rule
**Guardrail:** After assigning a Django `F()` expression to a model field, call `refresh_from_db()` before passing that instance to code that reads the field as a Python value.

This ensures analytics and response serialization never receive unresolved ORM expressions.

## Solution

### Immediate Fix
Incremented the in-memory integer directly and refreshed the saved field before updating analytics.

### Long-term Fix
Keep analytics updates behind a tested service boundary that verifies persisted numeric counters after each tracked event.

## Prevention
- [x] Refresh persisted view count before analytics calculation
- [x] Verify a live UUID detail request after rebuilding the service
- [ ] Add an API test asserting detail GET increments views without a 500

## Related Issues
- UUID public identifier migration

## References
- `backend/modules/listings/views.py`
- `backend/swapapp/models.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
