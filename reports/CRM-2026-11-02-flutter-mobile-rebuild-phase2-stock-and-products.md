# Flutter Mobile Rebuild — Phase 2 Stock & Products

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Module Scaffolding
**Status:** Completed

## Summary
Completed Phase 2 of the Flutter mobile rebuild: a real Stock & Products
module wired against the existing Django `ProductViewSet` — paginated
product list with search and low-stock filtering, product detail with
variants and stock-movement history, and a stock-adjustment form that
posts to the real `adjust_stock` action. This is the first feature module
built on top of the Phase 0/1 foundation and app shell.

## Context / Trigger
Direct continuation of Phase 1
(`CRM-2026-11-02-flutter-mobile-rebuild-phase1-auth-and-shell.md`) per the
7-phase plan. The user said "proceed."

## Scope
Included: product list (paginated, search, low-stock filter), product
detail (price/margin/stock info, variants, stock-movement history), and a
stock-adjustment bottom sheet (movement type, optional variant, quantity,
reference) — the Stock tab in the app shell now shows this instead of the
Phase 1 placeholder.

Excluded: creating or editing products (the backend supports it; this
phase is about *viewing stock and adjusting quantities*, not full product
CRUD — deferred, likely folded into a later phase rather than a dedicated
one), and the `categories`/`low_stock` dedicated endpoints (the list
endpoint's own `low_stock` filter param covers the Phase 2 need without a
second data path).

## Method
Read `backend/apps/products/{views,serializers,filters}.py` directly to
get the exact contract (pagination shape, filter query params, the
`StockAdjustmentSerializer`'s field names and validation, the
`non_field_errors`-style vs. per-field DRF error shapes) before writing any
Flutter code, rather than guessing the API surface. Wrote repository-level
tests against that contract using `http_mock_adapter` so a future backend
contract change would be caught by a failing test, not discovered at
runtime.

## Decisions & Findings
- **DRF `DecimalField`s serialize as JSON strings** (e.g. `"12.50"`), not
  numbers — added a shared `parseDouble`/`parseNullableDouble` helper
  (`core/utils/json_parsing.dart`) rather than repeating ad hoc parsing per
  model, after noticing the same shape would recur in every future feature
  module hitting this backend.
- **Variant price overrides are nullable-inherits-parent**
  (`ProductVariant.effective_buy_price`/`effective_sell_price` server-side)
  — mirrored as `ProductVariantEntity.effectiveBuyPrice(parentPrice)` /
  `effectiveSellPrice(parentPrice)` rather than duplicating the fallback
  logic at every call site.
- **Stock-adjustment errors come back as flat per-field DRF errors**
  (`{"quantity": ["Insufficient stock..."]}`), a different shape from the
  auth endpoint's `non_field_errors` — the `_extractDetail` helper here is
  intentionally more general (scans all field values) rather than reusing
  the auth repository's narrower version verbatim.
- **`http_mock_adapter`'s last-match-wins semantics** (documented in the
  Phase 1 report) didn't need a workaround this time — each test's request
  shape was distinct enough (different routes/bodies) to avoid ambiguity.
- **Client-side quantity validation is a pure static method**
  (`StockAdjustmentCubit.validateQuantity`), tested with zero repository
  setup — the plan's test gate specifically asked for this split.

## Changes Made
- `lib/features/products/` — full data/domain/presentation layers:
  entities (`ProductEntity`, `ProductVariantEntity`, `StockMovementEntity`
  with a `StockMovementType` enum mirroring the backend's choices),
  models, `ProductRemoteSource`, `ProductRepositoryImpl`,
  `ProductListCubit` (search debounce, low-stock toggle, pagination),
  `ProductDetailCubit`, `StockAdjustmentCubit`, and the three screens/
  widgets (`ProductListScreen`, `ProductDetailScreen`,
  `showStockAdjustmentSheet`, `StockBadge`, `ProductListTile`).
- `lib/core/network/paged_result.dart` — shared paginated-result type.
- `lib/core/utils/json_parsing.dart` — shared DRF-decimal-string parsing.
- `lib/core/routing/app_router.dart` — Stock tab now builds
  `ProductListScreen` (with its own `ProductListCubit`); added a top-level
  `/products/:id` route (pushed full-screen, outside the bottom-nav shell)
  for the detail screen.
- `lib/main.dart` — added `RepositoryProvider<ProductRepository>` to the
  composition root, reusing the same authenticated `Dio` instance as auth.
- Removed the now-superseded `StockPlaceholderScreen`.
- `test/core/shell/app_shell_navigation_test.dart` — updated for the real
  Stock tab (was asserting on the Phase 1 placeholder text).
- New tests: `stock_adjustment_validation_test.dart` (pure validation),
  `stock_adjustment_cubit_test.dart`, `product_list_cubit_test.dart`,
  `product_repository_impl_test.dart` (contract-level, via
  `http_mock_adapter`), `stock_adjustment_sheet_test.dart`,
  `product_list_screen_test.dart`.

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as Phases 0–1, plus one new equivalent in the products data
  layer).
- `flutter test` — 39/39 passing.
- Not yet done: real device/emulator run — still blocked, same as prior
  phases (no Android emulator/iOS simulator available in this
  environment).

## Follow-ups / Deferred
- Product create/edit (full CRUD) — not scheduled as its own phase yet;
  revisit scope once Phase 3 (POS) clarifies whether the pilot needs
  on-the-fly product creation at the till.
- Real on-device verification, same carryover as Phases 0–1.
- Phase 3 (POS/checkout — the pilot-critical phase for the boss's test
  machine) is next per the agreed plan.

## References
- `CRM-2026-11-02-flutter-mobile-rebuild-phase1-auth-and-shell.md`
- `backend/apps/products/{views,serializers,filters}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/products/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
