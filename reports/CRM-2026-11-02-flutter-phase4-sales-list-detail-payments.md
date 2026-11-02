# Flutter Mobile — Phase 4: Sales History, Detail, and Payment Recording

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests + real backend + real-device verification)

## Summary
Closed the second gap from the Phase 4 plan: the mobile app's "Sales" tab
was literally the POS checkout screen — there was no way to browse past
sales, view one, or record a follow-up payment on a credit sale. Added a
Sales history list (filterable by payment status), a sale detail screen
(reusing the existing receipt-image-share capability), and payment
recording — all built on an existing, already-complete backend contract.

## Context / Trigger
Continuation of the web-vs-mobile feature-parity plan
(`reports/CRM-2026-11-02-flutter-phase4-products-crud.md` covered Products;
this covers the second Phase 4 item). The parity audit found: no sales
list/history, no sale detail view, no way to record a payment against a
credit sale from the phone — the "Sales" bottom-nav tab routed straight to
the POS cart screen.

## Scope
Included: `listSales`/`getSale`/`updatePayment` on `SaleRepository`, a
`SaleListScreen` (replacing POS as the Sales tab's root, with status filter
chips and a "New sale" FAB that pushes the POS flow instead), a
`SaleDetailScreen` (summary + the existing `ReceiptCard` shown directly,
reusing the already-built share-as-image capability), and a payment-update
bottom sheet matching the existing stock-adjustment-sheet pattern.

Excluded (deliberately): PDF download (`download_pdf` action exists on the
backend but duplicates the already-built, arguably better, client-rendered
share-image flow for a mobile context), per-customer sales history
(`for_customer` action — no contact detail screen exists yet to hang it off
of; revisit once Contacts is upgraded from its current stub), refund/void
(not implemented on the backend at all — `destroy` is explicitly blocked
there, so there's nothing to build against).

## Method
Delegated a read-only backend-contract survey (Sale model fields, list vs.
detail serializer field differences, `update_payment`'s exact semantics,
pagination/filter query params) to a sub-agent before writing any Flutter
code — same approach as every prior phase.

## Decisions & Findings
- **`update_payment` is an absolute overwrite, not a delta** — the survey
  flagged this explicitly (`SaleService.update_payment` sets
  `payment_status`/`amount_paid` directly; the delta-aware, Payment-row-
  creating `record_payment` method exists but isn't wired to any endpoint).
  The payment form was designed around this: it shows "Amount paid
  (total)" pre-filled with the *current* amount, not an "add payment of X"
  field, so the UI's mental model matches what the API actually does.
- **Reused `ReceiptCard` + `shareWidgetAsImage` on the detail screen**
  instead of building a separate summary — these were already built for the
  post-checkout receipt screen and fit a historical sale's detail view
  exactly as well, so the Items/Total/Paid/Balance breakdown appears once
  (as the real receipt), not duplicated as a second plain list.
- **Moved POS to a pushed route (`/sales/new`)** rather than keeping it as
  the Sales tab's root — same "list + FAB pushes the actual form" pattern
  already established for Products. This required one small existing-code
  fix: `SaleReceiptScreen`'s "New sale" button used
  `Navigator.popUntil((route) => route.isFirst)`, which was correct when
  POS *was* the tab root (the first route on that branch's navigator) but
  would have popped the *entire app* back to its first-ever route once POS
  became a route pushed on top of the Sales list. Changed to a single
  `.pop()`, since Checkout replaces itself with Receipt via
  `pushReplacement`, so the stack is always exactly `[…, Pos, Receipt]` at
  that point.
- **List and detail refresh on return, unconditionally** (not gated on a
  returned "did anything change" boolean) — cheap (one GET), and correct
  for both "created a sale" and "recorded a payment that changed this row's
  status badge" without threading a return value through three nested
  pushed screens (List → New-sale route → Checkout → Receipt).
- Applied the same `Builder`-for-provider-scope pattern from the Products
  bug fix proactively here (the Sales route's refresh closures use
  `innerContext`, not the GoRoute builder's own `context`) — this phase did
  **not** reproduce that bug, because the lesson from Products was applied
  from the first draft.

## Changes Made
- `lib/features/sales/domain/repositories/sale_repository.dart`,
  `data/repositories/sale_repository_impl.dart`,
  `data/datasources/sale_remote_source.dart` — added
  `listSales`/`getSale`/`updatePayment`.
- `lib/features/sales/presentation/controllers/` — new:
  `sale_list_cubit.dart`/`sale_list_state.dart` (pagination + status
  filter, mirrors `ProductListCubit`), `sale_detail_cubit.dart`/
  `sale_detail_state.dart`, `payment_update_cubit.dart`/
  `payment_update_state.dart` (mirrors `StockAdjustmentCubit`).
- `lib/features/sales/presentation/widgets/payment_status_badge.dart` —
  new: semantic-palette badge (paid=success, partial=warning,
  credit=error), same pattern as `StockBadge`.
- `lib/features/sales/presentation/widgets/payment_update_sheet.dart` —
  new: modal bottom sheet, segmented payment-status control + amount field.
- `lib/features/sales/presentation/screens/sale_list_screen.dart` — new:
  status filter chips, paginated list, "New sale" FAB.
- `lib/features/sales/presentation/screens/sale_detail_screen.dart` — new:
  summary card, the real `ReceiptCard`, share button, "Record payment" FAB
  (hidden once `balanceDue == 0`).
- `lib/features/pos/presentation/screens/sale_receipt_screen.dart` — fixed
  the "New sale" button's pop behavior (see Decisions above).
- `lib/core/routing/app_router.dart` — Sales tab root now builds
  `SaleListScreen` (was `PosScreen`); added `/sales/new` and `/sales/:id`
  routes.
- New tests: `sale_repository_impl_test.dart` (added listSales/getSale/
  updatePayment contract cases), `sale_list_cubit_test.dart`,
  `sale_detail_cubit_test.dart`, `payment_update_cubit_test.dart`,
  `sale_list_screen_test.dart`, `sale_detail_screen_test.dart`. Updated
  `app_shell_navigation_test.dart`'s Sales-tab assertions for the new
  screen.

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing style notes).
- `flutter test` — 115/115 passing.
- `flutter build apk --debug` — builds clean.
- **Real device**: filtered the sales list by each status (All/Paid/
  Partial/Credit) against real seeded data; opened a credit sale
  (`S-000002`, Rumbidzai Ndlovu, balance 10.00); recorded a payment via the
  bottom sheet (set status to Paid, amount 10.00); confirmed in Postgres
  the sale now shows `payment_status='paid', amount_paid=10.00,
  balance_due=0.00`; confirmed the detail screen immediately reflected
  "Paid in full" with the FAB now hidden; navigated back to the list and
  confirmed the row updated to "Paid in full" too; confirmed via backend
  request logs that returning from both the detail screen and the "New
  sale" (POS) flow each triggered exactly the expected fresh
  `GET /api/v1/sales/?page=1`.

## Follow-ups / Deferred
- Per-customer sales history (`for_customer`) — once a real Contact detail
  screen exists to show it on.
- PDF download — only if a user specifically asks for it; the share-image
  flow already covers the "get the customer a receipt" need.

## References
- `reports/CRM-2026-11-02-flutter-phase4-products-crud.md`
- `Frontend_and_UI/CRM-2026-11-02-silently-swallowed-provider-lookup-breaks-list-refresh.md`
- `backend/apps/sales/{models,serializers,views,services}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/sales/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
