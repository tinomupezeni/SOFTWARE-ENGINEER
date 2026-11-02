# Flutter Mobile — Phase 6: Expenses

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests passing; real-device verification deferred — see Follow-ups)

## Summary
Added the Expenses domain to the mobile app end-to-end: a list screen with
a totals summary card and category filter chips, create/edit (no separate
detail screen, matching the web app's own convention), and delete — the
second of the four Phase 6 domains, prioritized ahead of Notes/Quotations
because it feeds directly into the profit picture.

## Context / Trigger
Direct continuation of Phase 6 after Tasks (see
`CRM-2026-11-02-flutter-phase6-tasks.md`), per the established priority
order (Tasks > Expenses > Notes > Quotations).

## Scope
Included: full CRUD against `/expenses/`, the `/expenses/summary/` action
(total + by-category breakdown) surfaced as a summary card above the list,
category filter chips, and a currency/amount/category/date/notes form.

Excluded: a separate expense detail/read-only screen — the web app has
none either (tapping a row opens the edit form directly), so mobile
doesn't invent one.

## Method
Same backend-contract-first approach as every other Phase 6 domain:
surveyed the real `Expense` model/serializer/summary action before writing
Dart, then built domain → data → presentation, reusing the Tasks feature's
structure as the template since both are flat list+form domains with no
sub-entities.

## Decisions & Findings
- **"No detail screen" domain** — tapping a list row passes the
  already-fetched `ExpenseEntity` straight to the edit form via go_router's
  `extra:` parameter, avoiding a redundant `GET` and matching the web
  frontend's own UX exactly rather than introducing a mobile-only detail
  view the web app doesn't have.
- **List screen owns delete directly** (no separate delete cubit) — each
  row has its own trailing delete button with a confirm dialog that calls
  `repository.deleteExpense(id)` straight from the list screen, matching
  the lean "simple action = direct repository call" pattern already used
  by Products' own list-row delete. Required adding `repository` as a
  constructor param to `ExpenseListScreen` specifically for this.
- **Summary-fetch failure doesn't block the list** —
  `ExpenseListCubit.loadFirstPage()` fetches the summary and the expense
  list together, but tolerates a summary-endpoint failure silently (`summary:
  null`) rather than surfacing it as a list-level error, since the list is
  the more important of the two.
- **Just-in-time `Currency` refactor**: moved the `Currency` enum out of
  `features/sales/domain/entities/sale_entity.dart` (where it was defined
  privately) into a new shared `lib/core/money/currency.dart`, since
  Expenses was the second real domain needing it. `sale_entity.dart` now
  both imports and `export`s the relocated enum, so every existing Sales/
  POS call site kept compiling unchanged — confirmed via a clean
  `flutter analyze` + full `flutter test` pass immediately after the move,
  before starting Expenses-specific code.
- Hit and fixed a Dart extension-visibility gotcha: `Currency.wireValue`
  (an extension method) wasn't resolvable in `expense_list_screen.dart`
  even though `ExpenseEntity` (which uses `Currency`) was already imported
  — an extension's defining library must be imported directly in any file
  that calls its methods; transitively importing the type isn't enough.
  Fixed by adding the direct import.

## Changes Made
- `lib/core/money/currency.dart` — new shared `Currency` enum +
  `CurrencyWire` extension (relocated from Sales).
- `lib/features/sales/domain/entities/sale_entity.dart` — now imports and
  re-exports `core/money/currency.dart` instead of defining `Currency`
  locally.
- `lib/features/expenses/domain/{entities,repositories}/*` —
  `ExpenseCategory`, `ExpenseEntity`, `ExpenseDraft`,
  `CategoryTotalEntity`/`ExpenseSummaryEntity`, `ExpenseRepository`.
- `lib/features/expenses/data/{models,datasources,repositories}/*` —
  `ExpenseModel`/`ExpenseSummaryModel`, `ExpenseRemoteSource` (incl.
  `getSummary()`), `ExpenseRepositoryImpl`.
- `lib/features/expenses/presentation/controllers/` —
  `ExpenseListCubit` (summary + paginated list together, category filter,
  pagination), `ExpenseFormCubit` (shared create/edit).
- `lib/features/expenses/presentation/screens/` —
  `expense_list_screen.dart` (summary card, category chips, inline delete),
  `expense_form_screen.dart` (description/amount+currency/category/date/notes).
- `lib/core/routing/app_router.dart` — new `/expenses`, `/expenses/new`,
  `/expenses/:id/edit` routes; `/expenses` wires the "no detail screen"
  `onOpenExpense` pattern directly to the edit route.
- `lib/main.dart`, `lib/features/more/presentation/screens/more_screen.dart`
  — `ExpenseRepository` added to the composition root; "Expenses" entry
  added to the More screen.
- Tests (25 total): `expense_repository_impl_test.dart` (7),
  `expense_list_cubit_test.dart` (4), `expense_form_cubit_test.dart` (4),
  `expense_list_screen_test.dart` (6, incl. the inline delete-confirm
  flow), `expense_form_screen_test.dart` (4).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — full suite passing (203 tests total across the app, up
  from 179 before Tasks+Expenses), no regressions.
- Real-device verification **not yet done** for this feature — see
  Follow-ups.

## Follow-ups / Deferred
- Real-device verification deferred, combined with Tasks (see that
  report's Follow-ups) — blocked on ADB wireless-debugging reconnection,
  which has failed every attempt this session.
- Notes and Quotations (the remaining two Phase 6 domains) not yet started.

## References
- `reports/CRM-2026-11-02-flutter-phase6-tasks.md`
- `backend/apps/expenses/{models,serializers,views}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/expenses/`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/core/money/currency.dart`

---

**Completed By:** Tino (via Claude Code)
**Duration:** Partial session (part of a longer Phase 6 session)
