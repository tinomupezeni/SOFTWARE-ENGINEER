# Flutter Mobile — Phase 4: Contacts Promoted from POS Stub to a Real Module

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests + real backend + real-device verification)

## Summary
Closed the last gap from the Phase 4 plan and the original feature-parity
audit's single biggest finding: mobile Contacts was not a module at all —
just a `search()` + `quickCreate()` stub built to serve the POS walk-in-
customer flow. Added a full Contacts list (searchable, filterable by
contact type), detail view, create/edit form, and soft delete, reachable
from a new entry in the More tab.

## Context / Trigger
Final item from the Phase 4 plan (after Products CRUD and Sales history/
payments). The original parity audit found mobile Contacts had "no list
screen, no detail screen, no edit, no delete, no contact type/stage — all
of which exist on web" — the largest lift of the domains audited, which is
why it was sequenced last in Phase 4.

## Scope
Included: full CRUD on the core `Contact` fields (name, phone, email,
location, contact type, notes, active flag), list with search + contact-
type filter chips, detail view (including the backend's computed
`lifetime_value`/`outstanding_credit`), soft delete (matches the backend's
own semantics — `DELETE` sets `is_active = False`, nothing is destroyed).

Excluded (deliberately, matching the backend's own bigger-ticket features):
the B2B `client_profile` fields (company name, VAT number, industry,
website, social links — a `Client` subclass via multi-table inheritance,
materially bigger UI for a narrower audience), the `timeline` action
(merged notes/tasks/sales/quotations feed — most of those mobile modules
don't exist yet, so a timeline would mostly be empty), file attachments.
None of these block "promote from stub to real module."

## Method
Delegated a read-only backend-contract survey (exact `Contact`/`Client`
model fields, list-vs-detail serializer differences, writable fields,
filter/search query params, special actions, delete semantics) to a
sub-agent before writing any Flutter code — same approach as every prior
phase. This surfaced the one fact the UI design hinges on: delete is a
soft `is_active = False`, never a real row removal.

## Decisions & Findings
- **List hides inactive (deleted) contacts by default** (`is_active=true`
  sent on every list request) rather than showing them greyed out — matches
  the already-established Products delete UX (delete makes it disappear
  from the browse list) instead of inventing a second convention.
- **`ContactEntity` grew from a 3-field POS stub to the full set, with the
  new fields defaulted** rather than all-required — this kept the existing
  POS `search()`/`quickCreate()` call sites and their tests compiling
  unchanged; only the four places actually constructing a full
  `ContactEntity` literal needed any thought, and none of them needed
  touching since the stub's 3-field usage still satisfies the new
  constructor.
- **Entry point is a "Contacts" row in the More tab, not a 5th bottom-nav
  tab.** The bottom nav's four destinations (Home/Stock/Sales/More) are the
  daily-use surfaces; browsing the contacts list is lower-frequency than
  those (most contact lookups happen inline, via the existing POS picker
  sheet, not as a standalone "go browse contacts" action) — adding a tab
  for it would dilute the thumb-zone real estate the HCI guide reserves for
  the highest-frequency actions.
- **Contact type gets a neutral badge, not the success/warning/error
  palette** used for stock/payment status — a contact type (lead/
  potential/regular/client) is a category, not a health or payment state,
  so coloring it with that palette would misapply the "color means one
  thing" principle the app otherwise follows consistently (`StockBadge`,
  `PaymentStatusBadge`).
- **Reused the `Builder`-for-provider-scope pattern** from the Products bug
  fix in every new route here too (list screen's `onOpenContact`/
  `onAddContact` closures use `innerContext`) — applied correctly from the
  first draft, no repeat of that bug.

## Changes Made
- `lib/features/contacts/domain/entities/contact_entity.dart` — grew from
  `{id, fullName, phone}` to the full field set (first/last name, email,
  location, `ContactType` enum, notes, `isActive`, `lifetimeValue`,
  `outstandingCredit`), new fields defaulted to avoid breaking existing
  call sites.
- `lib/features/contacts/domain/entities/contact_draft.dart` — new: the
  writable-fields DTO for create/update.
- `lib/features/contacts/domain/repositories/contact_repository.dart`,
  `data/repositories/contact_repository_impl.dart`,
  `data/datasources/contact_remote_source.dart`,
  `data/models/contact_model.dart` — added `listContacts`/`getContact`/
  `createContact`/`updateContact`/`deleteContact`; existing
  `search`/`quickCreate` untouched.
- `lib/features/contacts/presentation/controllers/` — new:
  `contact_list_cubit.dart`/`_state.dart` (pagination + debounced search +
  type filter, mirrors `ProductListCubit`), `contact_detail_cubit.dart`/
  `_state.dart`, `contact_form_cubit.dart`/`_state.dart` (mirrors
  `ProductFormCubit`).
- `lib/features/contacts/presentation/widgets/contact_type_badge.dart` —
  new: neutral categorical badge (see Decisions above).
- `lib/features/contacts/presentation/screens/` — new:
  `contact_list_screen.dart` (search + type filter chips + FAB),
  `contact_detail_screen.dart` (summary card, notes, edit/delete actions),
  `contact_form_screen.dart` (shared create/edit form).
- `lib/features/more/presentation/screens/more_screen.dart` — added the
  "Contacts" entry point.
- `lib/core/routing/app_router.dart` — new routes: `/contacts`,
  `/contacts/new`, `/contacts/:id`, `/contacts/:id/edit`.
- New tests: `contact_repository_impl_test.dart` (added listContacts/
  getContact/createContact/updateContact/deleteContact contract cases),
  `contact_list_cubit_test.dart`, `contact_detail_cubit_test.dart`,
  `contact_form_cubit_test.dart`, `contact_list_screen_test.dart`,
  `contact_detail_screen_test.dart` (real `GoRouter` harness, same pattern
  as the dashboard/products detail screens), `contact_form_screen_test.dart`.

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing style notes).
- `flutter test` — 142/142 passing.
- `flutter build apk --debug` — builds clean.
- **Real device**: opened Contacts from the More tab against live seeded
  data (list renders names/phones/type badges, filter chips narrow
  correctly); opened a contact's detail (Rufaro Banda — phone, location,
  lifetime value all correct); edited the contact's type from Potential to
  Client via the edit form and confirmed in Postgres the change persisted
  (`contact_type='client'`); restored it back to `potential` afterward to
  keep the demo dataset clean. (Device screen locked mid-session on idle
  timeout before the detail-screen-reflects-the-edit step could be
  re-screenshotted — the Postgres confirmation already proves the write
  path end-to-end, so this wasn't re-attempted blind against a locked
  screen.)

## Follow-ups / Deferred
- B2B `client_profile` fields, `timeline` action, file attachments — only
  if specifically requested; `timeline` in particular depends on mobile
  modules (Tasks, Quotations) that don't exist yet.
- Per-customer sales history (`Sale.for_customer`) could now be surfaced on
  this detail screen, since a real Contact detail screen exists — flagged
  as a follow-up in the Sales report, now unblocked.

## References
- `reports/CRM-2026-11-02-flutter-phase4-products-crud.md`
- `reports/CRM-2026-11-02-flutter-phase4-sales-list-detail-payments.md`
- `Frontend_and_UI/CRM-2026-11-02-silently-swallowed-provider-lookup-breaks-list-refresh.md`
- `backend/apps/contacts/{models,serializers,views,filters}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/contacts/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
