# Flutter Mobile — Phase 6: Notes

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests passing; real-device verification deferred — see Follow-ups)

## Summary
Added the Notes domain to the mobile app: a searchable list split into
Pinned/Notes sections, a create form (title, content, optional contact
link), and a detail screen with inline title/content editing, a pin
toggle, and delete — the third of the four Phase 6 domains.

## Context / Trigger
Direct continuation of Phase 6 after Expenses (see
`CRM-2026-11-02-flutter-phase6-expenses.md`), per the established priority
order (Tasks > Expenses > Notes > Quotations). A backend-contract survey
was run first (same approach as every other Phase 6 domain) to confirm the
`Note` model, serializer, viewset, and — critically — how the web
frontend actually scopes the feature, since the backend model supports far
more than the web UI exposes.

## Scope
Included: full CRUD against `/notes/`, the `toggle_pin` action, search
(`?search=`), and linking a single Contact.

Excluded, matching the web frontend's own scope exactly (not a backend
limitation — the model and serializer support all of this, the web app's
own form just never exposed it): linking to Deal/Product/Sale/Quotation,
`note_type`, `tags`, and `is_pinned` as a create-time field. A note can
only be created with title/content/contact on mobile, same as on web.

Also excluded: a separate edit form — matching `NoteForm.tsx` (create-only)
and `NoteDetail.tsx` (inline edit of title/content only) exactly, rather
than inventing a more capable mobile-only edit flow.

## Method
Delegated the backend-contract survey to a sub-agent before writing any
Dart, explicitly asking it to also check how the *web frontend* uses the
API — not just the backend serializer — since a "fat model" with five
optional link fields is exactly the kind of case where only the frontend's
actual usage tells you the real intended scope. That survey surfaced that
`deal`/`product`/`sale`/`quotation` linking and `note_type`/`tags` exist on
the backend but have no web UI at all, which is what let this phase match
scope precisely instead of over-building against the full model.

## Decisions & Findings
- **Scope matches the web app, not the backend model** — the `Note`
  model's "Universal Linking" design (five nullable FKs, no exclusivity
  constraint) is backend flexibility that neither web nor mobile currently
  surfaces; building the mobile form against the full model would have
  been scope creep relative to both the actual product and the "no
  over-engineering" project rule.
- **Detail screen allows inline edit (title/content only), matching web
  exactly** — unlike Expenses (no detail screen at all) or Tasks/Products
  (separate edit route), Notes has its own detail screen because the web
  `NoteDetail.tsx` does too, and inline-edits directly rather than routing
  to a separate edit screen, for the same reason.
- **`NoteDetailCubit.save()`/`togglePin()` return `Result<NoteEntity>`**
  rather than a bare `bool` (as `TaskDetailCubit.complete()` does) — chosen
  so the detail screen can surface the actual failure message on a failed
  save/pin-toggle instead of a generic error, since inline-edit failures
  (e.g. a blank-content validation error from the server) are more common
  here than a one-shot action like completing a task.
- **Contact picker duplicated, not shared, from Tasks** —
  `features/notes/presentation/widgets/contact_select_sheet.dart` is a
  byte-for-byte copy of the Tasks feature's own sheet. Deliberately not
  extracted to a shared location: this codebase's established convention
  (see the Tasks report) is that leaf UI widgets belong to their feature,
  and the duplication cost here is low (~115 lines) relative to the
  cross-feature coupling a shared version would introduce.

## Changes Made
- `lib/features/notes/domain/{entities,repositories}/*` — `NoteEntity`,
  `NoteDraft`, `NoteRepository`.
- `lib/features/notes/data/{models,datasources,repositories}/*` —
  `NoteModel`, `NoteRemoteSource` (incl. `togglePin()`), `NoteRepositoryImpl`.
- `lib/features/notes/presentation/controllers/` — `NoteListCubit`
  (debounced search, pagination, client-side pinned/others split),
  `NoteDetailCubit` (`save()`, `togglePin()`), `NoteFormCubit` (create-only).
- `lib/features/notes/presentation/widgets/contact_select_sheet.dart`.
- `lib/features/notes/presentation/screens/` — `note_list_screen.dart`,
  `note_detail_screen.dart` (inline edit + pin + delete),
  `note_form_screen.dart` (create-only).
- `lib/core/routing/app_router.dart` — new `/notes`, `/notes/new`,
  `/notes/:id` routes.
- `lib/main.dart`, `lib/features/more/presentation/screens/more_screen.dart`
  — `NoteRepository` added to the composition root; "Notes" entry added to
  the More screen.
- Tests (26 total): `note_repository_impl_test.dart` (7, incl.
  `toggle_pin`), `note_list_cubit_test.dart` (4, incl. the pinned/others
  split), `note_detail_cubit_test.dart` (5, incl. save-success/
  save-failure/pin-toggle), `note_form_cubit_test.dart` (2),
  `note_list_screen_test.dart` (4), `note_detail_screen_test.dart` (4,
  incl. pin toggle and delete-confirm), `note_form_screen_test.dart` (2).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — full suite at 231 tests (up from 203 before Notes), no
  regressions.
- Real-device verification **not yet done** for this feature — see
  Follow-ups.

## Follow-ups / Deferred
- Real-device verification deferred, combined with Tasks and Expenses (see
  those reports' Follow-ups) — blocked on ADB wireless-debugging
  reconnection, which has failed every attempt this session.
- Quotations (the final Phase 6 domain) not yet started.
- If a future phase ever needs to link a Note to Deal/Product/Sale/
  Quotation on mobile, the backend already supports it (see the survey in
  References) — this would be additive, not a backend change.

## References
- `reports/CRM-2026-11-02-flutter-phase6-expenses.md`
- `reports/CRM-2026-11-02-flutter-phase6-tasks.md`
- `backend/apps/notes/{models,serializers,views}.py`
- `frontend/src/features/notes/`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/notes/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** Partial session (part of a longer Phase 6 session)
