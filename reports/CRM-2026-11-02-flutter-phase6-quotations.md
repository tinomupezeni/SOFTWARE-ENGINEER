# Flutter Mobile — Phase 6: Quotations (final domain)

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests passing; real-device verification deferred — see Follow-ups). **This closes Phase 6.**

## Summary
Added the Quotations domain to the mobile app: a list with search, a
create form with line items (via a product/variant picker), and a
read-only detail screen exposing create-revision, convert-to-sale, PDF
download (via the OS share sheet), and WhatsApp share actions — the
fourth and last of the Phase 6 domains (Tasks > Expenses > Notes >
Quotations).

## Context / Trigger
Direct continuation of Phase 6 after Notes (see
`CRM-2026-11-02-flutter-phase6-notes.md`). Quotations was deliberately
left last in the original Phase 6 plan on the assumption it would be "the
heaviest workflow, lowest mobile usage frequency" of the four — a
backend-and-web-usage survey (same approach as every other Phase 6
domain) confirmed the heavy-workflow half of that assumption (line items,
formula-based pricing, versioning, PDF generation, convert-to-sale) but
corrected the status-workflow half: `sent`/`accepted`/`rejected`/`expired`
exist as model choices but nothing in the backend or web app ever
transitions a quotation into them — only `draft` and `converted` are ever
actually reachable in practice.

## Scope
Included: full create (title, optional contact, expiry date, notes,
terms, line items), list with search, and read-only detail with its four
actions (create revision, convert to sale, download PDF, share via
WhatsApp) plus delete.

Excluded, matching the web frontend's own scope exactly:
- **No in-place item edit** — the backend serializer's nested-items
  support is create-only (no custom `update()`), and the web app itself
  has no edit UI either; "Create Revision" (clone as a new draft) is the
  only way to "change" an existing quotation, on both platforms.
- **No manual status-change UI** — matches the finding above; the status
  badge is read-only display, same as web.
- **`ItemFormula` (labor cost / materials cost / markup % → computed unit
  price) scoped out of mobile v1** — a real web feature, but an advanced,
  rarely-used pricing helper; mobile users can still enter any unit price
  directly. Noted as a clean, additive follow-up rather than a backend
  gap (the backend already supports it).
- **No currency selector** — the `Quotation` model has no currency field
  at all (unlike Sale/POS), so there was nothing to scope out here; this
  matches the web app, which also has none.

## Method
Same backend-contract-first approach as every other Phase 6 domain:
delegated a sub-agent survey of the `Quotation`/`QuotationItem`/
`ItemFormula` models, serializers, custom `@action` routes, and —
critically — the web frontend's actual create-form and detail-page scope,
before writing any Dart. That survey is what caught the status-workflow
correction above and confirmed the web TypeScript types are (unlike the
Notes case) fully in sync with the API, meaning no additional scope
double-checking was needed there.

## Decisions & Findings
- **`ModuleEnabledPermission`** — this domain is gated behind
  `organization.has_module("quotations")` server-side (403 if disabled),
  the one extra wrinkle beyond the other three Phase-6 domains' plain
  `TenantQuerySetMixin` + `IsTenantMember`. Mobile doesn't currently
  special-case this (a disabled-module org would just see a network error
  surfaced through the existing `_ErrorView`/snackbar paths) — flagged as
  a follow-up rather than solved now, since no other mobile feature has
  had to handle a module-gated 403 yet either.
- **PDF download reuses the receipt-sharing pattern** (`share_plus` +
  `path_provider`, writing to a temp file and handing it to the OS share
  sheet) rather than an in-app PDF viewer — the backend's
  `download_pdf` action requires the same JWT auth as every other
  endpoint, so it's fetched via the authenticated `Dio` client as raw
  bytes, not opened as a bare URL.
- **WhatsApp share uses `url_launcher`** (`https://wa.me/...` deep link,
  `LaunchMode.externalApplication`) rather than `share_plus` — unlike the
  Sales receipt (which shares a rendered image, since `wa.me` links can't
  carry attachments), the backend's `share_whatsapp` action already
  returns a pre-built `wa.me` URL with prefilled text, so mobile just
  opens it; this is the first use of `url_launcher` in the mobile app
  (it was already a pubspec dependency, unused until now).
- **`convertToSale` returns `SaleEntity`** (reusing the Sales feature's
  existing domain entity/model) rather than introducing a parallel type —
  a one-directional `quotations` → `sales` domain dependency, consistent
  with how `NoteDetailCubit`/`TaskDetailCubit` return their own feature's
  entity on a dedicated action.
- **Contact and product pickers duplicated, not shared** — the contact
  picker is a third copy of the same sheet now in Tasks/Notes/Quotations
  (see those reports); the product picker is new (two-step: search, then
  an inline variant list if the picked product has variants), built as
  its own leaf widget per this codebase's established per-feature
  convention rather than reusing POS's `add_to_cart_sheet.dart` (whose
  quantity-focused "add to cart" framing doesn't fit a quotation line
  item's broader field set — description, discount, no stock-availability
  check).

## Changes Made
- `lib/features/quotations/domain/entities/` — `QuotationItemEntity`,
  `QuotationEntity` (+ `QuotationStatus` enum, `QuotationRevisionEntity`),
  `QuotationItemDraft`/`QuotationDraft`.
- `lib/features/quotations/domain/repositories/quotation_repository.dart`
  — `listQuotations`, `getQuotation`, `createQuotation`, `deleteQuotation`,
  `createRevision`, `convertToSale` (returns `SaleEntity`), `downloadPdf`
  (raw bytes), `getWhatsappShareUrl`.
- `lib/features/quotations/data/{models,datasources,repositories}/*` —
  standard pattern, plus the four custom-action calls on the remote
  source.
- `lib/features/quotations/presentation/controllers/` —
  `QuotationListCubit` (debounced search, pagination),
  `QuotationDetailCubit` (`createRevision()`, `convertToSale()` — reloads
  on success —, `downloadPdf()`, `getWhatsappShareUrl()`),
  `QuotationFormCubit` (create-only).
- `lib/features/quotations/presentation/widgets/` —
  `contact_select_sheet.dart`, `product_select_sheet.dart` (new, two-step
  product+variant picker), `quotation_status_badge.dart`.
- `lib/features/quotations/presentation/screens/` —
  `quotation_list_screen.dart`, `quotation_form_screen.dart` (dynamic line-
  items array, each with its own description/qty/unit-price/discount
  fields), `quotation_detail_screen.dart` (items, notes, terms, version
  history, the four actions).
- `lib/core/routing/app_router.dart` — new `/quotations`,
  `/quotations/new`, `/quotations/:id` routes.
- `lib/main.dart`, `lib/features/more/presentation/screens/more_screen.dart`
  — `QuotationRepository` added to the composition root; "Quotations"
  entry added to the More screen.
- `test/core/shell/app_shell_navigation_test.dart` — updated (see
  Verification) to scroll the More screen before asserting on "Log out",
  since the new Quotations menu entry pushed it off the test's fixed-size
  viewport.
- Tests (32 total): `quotation_repository_impl_test.dart` (9, incl. all
  four custom actions), `quotation_list_cubit_test.dart` (3),
  `quotation_detail_cubit_test.dart` (5), `quotation_form_cubit_test.dart`
  (2), `quotation_list_screen_test.dart` (4), `quotation_detail_screen_test.dart`
  (6, incl. the converted-status action-hiding case and delete-confirm),
  `quotation_form_screen_test.dart` (3, incl. adding/removing a line item
  via the product picker).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — full suite at 263 tests (up from 231 before
  Quotations), zero regressions once a pre-existing shared test
  (`app_shell_navigation_test.dart`) was updated for the taller More
  screen — not a functional bug, just a test that needed to scroll to
  reach a button it previously found without scrolling.
- Real-device verification **not yet done** for this feature — see
  Follow-ups.

## Follow-ups / Deferred
- Real-device verification deferred, combined with Tasks/Expenses/Notes
  (see those reports' Follow-ups) — blocked on ADB wireless-debugging
  reconnection, which has failed every attempt this session.
- `ItemFormula` (labor/materials/markup pricing calculator) — additive,
  backend already supports it; revisit if a future phase specifically
  asks for it.
- Module-disabled (403) handling for `quotations` specifically — currently
  falls through to the generic error/snackbar path; no mobile feature has
  needed bespoke module-gating UX yet.
- **Phase 6 is now complete**: Tasks, Expenses, Notes, and Quotations have
  all been built, tested, and committed. The one cross-cutting item still
  open across all four is the combined real-device verification pass,
  blocked on ADB reconnection for the entire session.

## References
- `reports/CRM-2026-11-02-flutter-phase6-notes.md`
- `reports/CRM-2026-11-02-flutter-phase6-expenses.md`
- `reports/CRM-2026-11-02-flutter-phase6-tasks.md`
- `backend/apps/quotations/{models,serializers,views,services}.py`
- `frontend/src/features/quotations/`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/quotations/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** Partial session (part of a longer Phase 6 session)
