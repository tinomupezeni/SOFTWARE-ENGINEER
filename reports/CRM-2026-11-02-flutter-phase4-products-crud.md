# Flutter Mobile — Phase 4: Products Create/Update/Delete

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests + real backend + real-device CRUD cycle verified)

## Summary
Closed the first and largest gap identified in a web-vs-mobile feature
parity audit: the mobile app could list, view, and adjust stock for
products, but had no way to create, edit, or delete one — not even at the
data layer. Added full CRUD, matching the backend's writable-field contract,
with a single form screen shared between create and edit.

## Context / Trigger
A feature-parity comparison (web vs mobile, run via parallel research
passes across Contacts/Products/Sales/Dashboard) found Products was the
single biggest gap among the four domains mobile already partially covered:
no create, update, or delete at all, not even missing UI — missing at the
repository/datasource layer. The resulting phased plan put this first
("Phase 4 — complete the core loop") since list/detail/stock-adjustment
already existed and this was pure additive work on a proven foundation.

## Scope
Included: `createProduct`/`updateProduct`/`deleteProduct` on
`ProductRepository` and everywhere beneath it, a single
`ProductFormScreen` used for both create (FAB on the Stock list) and edit
(pencil icon on product detail), a delete confirmation dialog on product
detail, and routing/refresh wiring so the Stock list and detail screen stay
consistent with the server after each action.

Excluded (deliberately, matching the backend serializer's own scope and the
"no over-engineering" rule): variant create/edit (variants stay inline,
read-only in this form — editing them is a materially bigger UI, deferred),
product photo upload, supplier linking, tags/metadata. These exist on the
backend/web but aren't part of "close the stub gap" — they're closer to
Phase 5+ scope.

## Method
Delegated a read-only backend-contract survey (exact `Product` model
fields, `ProductSerializer` writable fields, nested variant handling, the
`/products/categories/` and `/adjust_stock/` special actions) to a
sub-agent before writing any Flutter code, same approach as prior phases —
got the field names and the "quantity_in_stock is read-only, only changed
via adjust_stock" rule right on the first pass rather than guessing.

## Decisions & Findings
- **`ProductDraft` as the single writable-fields type**, used for both
  create (`POST`) and update (`PATCH`) — the backend's PATCH is partial, but
  sending every writable field keeps the client's notion of "current state"
  unambiguous rather than diffing.
- **`ProductType` added to `ProductEntity`/`ProductModel` as an optional
  field with a default** (`physical`), not a required one — avoided touching
  the four existing test files that construct `ProductEntity` literals,
  consistent with "don't over-engineer/don't touch what isn't in scope."
- **One form screen for create and edit**, switching on whether a
  `ProductEntity? product` was passed in, rather than two near-duplicate
  screens — matches the existing codebase's preference for one flexible
  widget over parallel near-copies.
- **Delete confirmation dialog** follows the exact pattern already
  established for logout confirmation (`AlertDialog`, `TextButton` cancel +
  `FilledButton` destructive action) — no new UI pattern introduced for a
  destructive action that already had a precedent in this app.
- **Found and fixed a real bug along the way**: the Stock list didn't
  refresh after create/delete due to a `context.read` provider-scope
  mistake in the router — see
  `Frontend_and_UI/CRM-2026-11-02-silently-swallowed-provider-lookup-breaks-list-refresh.md`
  for the full root-cause writeup; not duplicated here.

## Changes Made
- `lib/features/products/domain/entities/product_entity.dart` — added
  `ProductType` enum + `productType` field (default `physical`).
- `lib/features/products/domain/entities/product_draft.dart` — new: the
  writable-fields DTO used for create/update.
- `lib/features/products/domain/repositories/product_repository.dart`,
  `data/repositories/product_repository_impl.dart`,
  `data/datasources/product_remote_source.dart` — added
  `createProduct`/`updateProduct`/`deleteProduct`.
- `lib/features/products/data/models/product_model.dart` — parses
  `product_type` from the API response.
- `lib/core/validation/number_validation.dart` — new: shared
  non-negative-number and required-text validators (form-field validation,
  HCI guide's validate-on-blur pattern).
- `lib/features/products/presentation/controllers/product_form_cubit.dart`
  (+ `product_form_state.dart`) — drives both create and edit; `isEditing`
  derived from whether a `productId` was supplied.
- `lib/features/products/presentation/screens/product_form_screen.dart` —
  new: Name/SKU/Category/Product type/Buy price/Sell price/Low stock
  threshold/Active fields.
- `lib/features/products/presentation/screens/product_list_screen.dart` —
  added the "Add product" FAB.
- `lib/features/products/presentation/screens/product_detail_screen.dart` —
  added edit (pencil) and delete (trash) `AppBar` actions; delete shows a
  confirmation dialog, then pops `true` on success so the list refreshes.
- `lib/core/routing/app_router.dart` — new routes `/products/new` and
  `/products/:id/edit`; refresh-after-navigation wiring (see the linked bug
  entry for why this needed a `Builder` indirection).
- New/updated tests: `test/features/products/product_repository_impl_test.dart`
  (create/update/delete contract + a validation-error mapping case),
  `product_form_cubit_test.dart`, `product_form_screen_test.dart` (create
  validation, edit pre-fill, both submit paths),
  `test/core/shell/app_shell_navigation_test.dart` (regression test for the
  refresh bug, using the real `buildAppRouter`).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — 92/92 passing.
- `flutter build apk --debug` — builds clean against the real backend
  contract.
- **Real device** (Samsung Galaxy S22+, reconnected wireless debugging
  twice mid-session after the connection dropped — see the existing ADB
  pairing-port guardrail, which again correctly caught a user-supplied
  connect-port-not-pairing-port mixup): created a product end-to-end
  (verified in Postgres via Django shell), edited its price (verified the
  change persisted and the detail screen's margin recalculated), deleted it
  (verified removal in Postgres and that the Stock list correctly showed
  "No products found" for a matching search afterward), and confirmed via a
  live `adb logcat` capture that the create-then-refresh sequence fires
  exactly as designed (`onAddProduct` → `loadFirstPage` on the same cubit
  instance → a fresh `GET /products/?page=1`).

## Follow-ups / Deferred
- Variant create/edit UI, product photo upload, supplier linking — out of
  scope for "close the stub gap"; revisit if a future phase specifically
  asks for them.
- Minor known limitation: editing a product from its detail screen doesn't
  propagate back to refresh the Stock *list* screen underneath (only
  deleting does, since delete pops the detail screen entirely). Low
  priority — the list naturally refreshes on next visit/pull-to-refresh,
  and the edited values are correct on the detail screen itself immediately.

## References
- `reports/CRM-2026-11-02-flutter-home-dashboard.md`
- `Frontend_and_UI/CRM-2026-11-02-silently-swallowed-provider-lookup-breaks-list-refresh.md`
- `backend/apps/products/{models,serializers,views}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/products/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
