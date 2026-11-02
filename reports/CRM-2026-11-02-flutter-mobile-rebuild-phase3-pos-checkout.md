# Flutter Mobile Rebuild — Phase 3 POS / Checkout

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Module Scaffolding
**Status:** Completed (scope-reduced — see Decisions & Findings)

## Summary
Completed Phase 3 of the Flutter mobile rebuild: the Sales tab is now a
real point-of-sale flow — product search → add to cart → select/quick-add
customer → choose currency and payment terms → complete the sale against
the real Django `SaleViewSet` → receipt with WhatsApp share. This is the
pilot-critical phase (the one the boss's physical POS test machine is
for), but the device-test half of its test gate remains blocked — see
Follow-ups.

## Context / Trigger
Direct continuation of Phase 2
(`CRM-2026-11-02-flutter-mobile-rebuild-phase2-stock-and-products.md`) per
the 7-phase plan. The user said "proceed."

## Scope
Included: a new Contacts module (search + walk-in quick-create — minimal,
not full CRUD), a new Sales module (create-sale + WhatsApp receipt link,
reusing the backend's existing endpoints), and the POS feature itself
(cart, add-to-cart/variant picker, checkout form, receipt screen).

Excluded (deliberately, not oversights):
- **Barcode/camera scanning and Bluetooth printer support** — both require
  a physical device to build against meaningfully and this environment has
  neither an Android emulator nor an iOS simulator (carried over from
  Phases 0–2). Building camera-facing UI with zero ability to verify it
  renders or focuses correctly would be shipping unverified code, so it's
  deferred to when the test POS machine is available, per the original
  plan's own test-gate note.
- **Full product/contact CRUD** — same reasoning as Phase 2; this phase
  needed *a* contact and *a* product to sell, not management screens for
  either.
- **Optimistic UI on checkout submission** — the Phase 3 plan (drafted
  before this phase started) suggested optimistic updates with rollback
  for cart actions generally. Checkout itself (money + stock deduction) is
  **not** treated optimistically: the "Complete sale" button blocks with a
  spinner until the server confirms, because a sale is expensive/awkward
  to roll back client-side if the server rejects it (e.g. stock changed
  underneath the cashier). Optimistic UI is still used correctly for the
  cheap, locally-reversible action — adding/removing a cart line — which
  has no server round-trip at all until checkout.

## Method
Read `backend/apps/sales/{models,serializers,services,views}.py` and
`backend/apps/contacts/{models,serializers,views,filters}.py` directly
before writing any client code — in particular this is what surfaced that
`Sale.contact` is a required, non-nullable `ForeignKey` with no
anonymous/cash-sale concept server-side, which is why the checkout flow
*must* always resolve to a real `Contact` (hence the walk-in quick-create
path, not a "skip customer" option).

## Decisions & Findings
- **No anonymous/cash sale exists server-side** — every sale needs a
  contact. The contact picker therefore offers "add as new customer"
  (phone-only, since `Contact.phone` is the only required field) rather
  than a placeholder "walk-in" contact, since inventing one client-side
  would silently diverge from what the backend actually models.
- **Reused `ProductListCubit` as-is** for the POS product browser instead
  of writing a parallel one — its search/pagination/low-stock logic is
  identical to the Stock tab's; only the tap action (add-to-cart sheet vs.
  navigate-to-detail) and the surrounding chrome (cart summary bar)
  differ.
- **Extracted a shared `mapDioError`** (`core/network/dio_error_mapper.dart`)
  after noticing the Phase 2 pattern (`_mapError`/`_extractDetail`
  duplicated per repository) was about to be copied a third and fourth
  time for Contacts and Sales. Auth keeps its own thin wrapper (it needs a
  distinct `AuthFailure` type for 401s), but Products/Contacts/Sales all
  now share the same mapper.
- **Found and fixed a real crash before it shipped**: the global
  `ElevatedButtonThemeData` sets `minimumSize: Size.fromHeight(48)` (an
  *infinite*-width minimum, by Flutter's own `Size.fromHeight` semantics)
  to satisfy the HCI guide's touch-target rule. That's safe inside a
  stretched `Column` (every other button in the app) but crashes any
  button placed as a bare `Row` child — exactly the POS cart summary bar's
  "Charge" button. Full write-up and guardrail in the bug-log entry (see
  References) since this is a pattern other future screens could still hit.
- **`validateQuantity`/`validatePositiveWholeNumber` unified**: Phase 2's
  `StockAdjustmentCubit.validateQuantity` and this phase's add-to-cart
  quantity field needed the identical rule, so it moved to
  `core/validation/quantity_validation.dart` rather than being copied —
  `StockAdjustmentCubit.validateQuantity` now delegates to it, keeping its
  existing call sites/tests unchanged.

## Changes Made
- `lib/features/contacts/` — new module: `ContactEntity`, `ContactModel`,
  `ContactRemoteSource`, `ContactRepositoryImpl` (search + quickCreate).
- `lib/features/sales/` — new module: `SaleEntity`/`SaleItemEntity`
  (+ `PaymentStatus`/`Currency` enums), `NewSaleItem` (request shape),
  `SaleRemoteSource`, `SaleRepositoryImpl` (createSale +
  getWhatsappReceiptLink).
- `lib/features/pos/` — new module: `CartItem`/`CartState`/`CartCubit`
  (pure client-side, optimistic-by-nature since there's no server round
  trip until checkout), `CheckoutCubit` (+ pure `validate`/
  `resolveAmountPaid` static methods), `PosScreen`, `CheckoutScreen`,
  `SaleReceiptScreen`, and the `showContactPickerSheet`/
  `showAddToCartSheet` modal sheets + `CartSummaryBar`.
- `lib/core/network/dio_error_mapper.dart` — shared Dio→Failure mapping;
  refactored `AuthRepositoryImpl`, `ProductRepositoryImpl` to use it
  (removing their duplicated private mappers).
- `lib/core/validation/quantity_validation.dart` — shared quantity
  validation, consumed by `StockAdjustmentCubit` and the add-to-cart sheet.
- `pubspec.yaml` — added `url_launcher` (opens the wa.me receipt link).
- `lib/core/routing/app_router.dart` / `lib/main.dart` — Sales tab now
  builds `PosScreen`; added `ContactRepository`/`SaleRepository` to the
  composition root's `RepositoryProvider`s.
- Removed the now-superseded `PosPlaceholderScreen`.
- `test/core/shell/app_shell_navigation_test.dart` — updated for the real
  Sales tab (was asserting on the Phase 1/2 placeholder).
- New tests across `test/features/{contacts,sales,pos}/`: repository
  contract tests (via `http_mock_adapter`) for Contacts and Sales, cart
  arithmetic, checkout validation + submission cubit tests, and widget
  tests for the add-to-cart sheet and cart summary bar (including the one
  that caught the `ElevatedButton`/`Row` crash above).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — 68/68 passing.
- **Not done — the actual pilot-critical gate**: a real on-device test on
  the boss's POS test machine (checkout time, mis-tap rate, stock
  decrement verified against the backend ledger after a real transaction).
  This phase cannot be marked fully verified until that happens; what's
  verified here is the logic and contract, not the physical-device
  experience.

## Follow-ups / Deferred
- Real device/emulator test — this is the one that actually matters for
  Phase 3 specifically, more than any prior phase, since POS is the
  pilot's whole point. Needs the physical test machine or at minimum an
  Android emulator with accepted SDK licenses.
- Barcode scanning (camera) and Bluetooth receipt printer support — once a
  device is available to build and test against.
- Full product/contact CRUD — revisit scope in Phase 4 (CRM parity).

## References
- `CRM-2026-11-02-flutter-mobile-rebuild-phase2-stock-and-products.md`
- `Frontend_and_UI/CRM-2026-11-02-elevated-button-infinite-width-crash-in-row.md`
- `backend/apps/sales/{models,serializers,services,views}.py`
- `backend/apps/contacts/{models,serializers,views,filters}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/{contacts,sales,pos}/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
