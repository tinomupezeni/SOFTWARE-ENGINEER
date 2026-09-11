# Every Sale Creation Was Broken: ProductService.adjust_stock() Didn't Accept the `variant` It Was Always Called With

**Date:** 2026-09-11
**Project:** CRM Professional
**Environment:** Backend (discovered while writing the first backend test suite)
**Severity:** Critical (core feature down)
**Status:** Resolved

## Summary
While adding backend test coverage for `sales/services.py` and `products/services.py`, the very first test run of the *existing* test suite (`apps/sales/tests/test_views.py::test_create_sale`) failed with `TypeError: ProductService.adjust_stock() got an unexpected keyword argument 'variant'`. This is not a new regression from this session's work — it was already sitting on `main`, uncovered, because the frontend/product changes shipped earlier today only touched the frontend and the backend hadn't been redeployed in ~2 months (see the separate CI/CD drift log entry from earlier today).

## Symptoms
- `SaleService.create_sale()` (`apps/sales/services.py`) unconditionally calls `ProductService.adjust_stock(product=product, variant=variant, quantity=..., movement_type="out", ...)` for every line item, whether or not that item has a variant (`variant=None` when it doesn't).
- `ProductService.adjust_stock()` (`apps/products/services.py`) had the signature `adjust_stock(product, quantity, movement_type, reference="", created_by=None)` — no `variant` parameter at all.
- Net effect: **every single sale creation via the API crashed with a 500**, not just ones involving a product variant. `--cov-fail-under=40` in CI should have been catching this via the existing `test_create_sale` test; it's unclear why it wasn't blocking merges (worth checking whether CI has actually been running/passing on this branch).
- A second, related gap in the same function: the manual "Adjust Stock" endpoint (`ProductViewSet.adjust_stock`, backing `StockAdjustmentModal.tsx` in the frontend) accepted a `variant` field in its serializer but never passed it through to the service at all — so adjusting a variant's stock manually silently adjusted the *parent product's* aggregate stock instead.

## Root Cause
`StockMovement` and `ProductVariant.quantity_in_stock` were added to support per-variant stock tracking, but `ProductService.adjust_stock()` was never updated to accept or act on a variant — only the two call sites (`SaleService.create_sale`, and partially `ProductViewSet.adjust_stock`) were updated to *assume* variant support existed.

## Solution
- `ProductService.adjust_stock()` now accepts an optional `variant=None`. When given, it adjusts `variant.quantity_in_stock` (the specific sellable SKU) instead of the parent product's count, and stamps `StockMovement.variant`. Without one, behavior is unchanged.
- `ProductViewSet.adjust_stock` now resolves the `variant` id from the request into a `ProductVariant` instance and passes it through.
- Added `apps/products/tests/test_services.py` and `apps/sales/tests/test_services.py`, both with explicit regression tests for this exact scenario (variant stock adjusts independently of the parent product; insufficient variant stock raises with the variant's name).

## Prevention
- [x] Regression tests added at the service layer for both call sites.
- [ ] Confirm CI has actually been green on `main` recently — a crash this fundamental passing review is a sign either CI wasn't run, wasn't blocking merge, or this line was added after the last CI run and never pushed through a PR that ran tests.
- [ ] Manual QA pass on the "Add Size/Color Variant" + "Record Sale" flow in the actual UI once backend is redeployed (see the CI/CD drift entry — production backend hasn't been rebuilt in ~2 months, so this bug may not be live yet; confirm before it is).

---

**Resolved By:** Claude Code
**Time to Resolution:** ~40 minutes (found while writing tests, fixed same session)
