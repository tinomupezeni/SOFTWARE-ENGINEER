# Flutter Mobile — Phase 6: Tasks

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests passing; real-device verification deferred — see Follow-ups)

## Summary
Added the Tasks domain to the mobile app end-to-end (list with status
filtering, create/edit form, detail with a dedicated "mark complete"
action, delete), the first of the four Phase 6 domains (Tasks > Expenses >
Notes > Quotations, prioritized by daily operational use).

## Context / Trigger
Phase 6 picks up after Phase 5 (dashboard charts) closed out the core
record-keeping loop (Contacts/Products/Sales/Dashboard). Tasks was
prioritized first within Phase 6 because it's used daily in the field,
ahead of Expenses (ties into profit reporting), Notes (likely a shared
widget), and Quotations (heavier workflow, lower mobile usage frequency).

## Scope
Included: full CRUD against the existing `/tasks/` API, status filter
chips (All/Pending/In Progress/Completed/Cancelled), overdue-task
indicator (red border + "Overdue · <date>" label, using `isOverdue` from
the backend rather than recomputing it client-side), priority badge
(outlined text, not a colored dot — see Decisions), a task-contact linking
sheet, and the dedicated `complete()` action via `POST /tasks/{id}/complete/`.

Excluded (matches the backend serializer's actual writable surface and the
"no over-engineering" rule): `assigned_to` (no team-members picker exists
on mobile yet), and the `product`/`sale`/`quotation` linked-object fields
(no pickers for those exist either). A task can be created/edited with
title/description/contact/due date/due time/priority/status only.

## Method
Followed the same backend-contract-first approach as prior phases: read
the actual `Task` model/serializer/viewset before writing Dart, then built
domain → data → presentation in that order, wiring the
`BlocProvider`-inside-`Builder` provider-scope pattern (already a known
bug class from earlier phases — see the Phase 4 Products report) into the
new routes from the first draft rather than discovering it again.

## Decisions & Findings
- **A new Tasks-owned contact picker** (`contact_select_sheet.dart`)
  rather than reusing POS's `contact_picker_sheet.dart` — the POS picker
  has a "New customer" creation affordance that doesn't belong in a task's
  contact-linking context, and reusing it would create an undesirable
  `pos` → `tasks` feature-boundary dependency.
- **Priority badge is a plain outlined text badge, not a colored dot** —
  this app's error/warning hues already carry specific meaning elsewhere on
  a task (the overdue indicator, in particular); reusing them for priority
  risks the same color meaning two different things on one card.
- **Status badge is neutral for every status except `completed`**, which
  uses the success-green semantic color — completed is the one
  unambiguous positive signal among the four states.
- **`completeTask` calls the backend's dedicated action endpoint**
  (`POST /tasks/{id}/complete/`), not a generic status `PATCH` — matches
  the backend's own API shape rather than working around it.
- Found and fixed a `bloc_test` gotcha while testing `complete()`:
  calling a cubit method that emits, from inside `blocTest`'s `verify:`
  callback, throws `Bad state: Cannot emit new states after calling close`
  because the bloc is already closed by the time `verify` runs. Fixed by
  converting that one case to a plain `test()` that drives the cubit
  directly instead of through `blocTest`.

## Changes Made
- `lib/features/tasks/domain/{entities,repositories}/*` —
  `TaskEntity`/`TaskPriority`/`TaskStatus`/`TaskDraft`, `TaskRepository`.
- `lib/features/tasks/data/{models,datasources,repositories}/*` —
  standard `TaskModel`/`TaskRemoteSource`/`TaskRepositoryImpl`.
- `lib/features/tasks/presentation/controllers/` —
  `TaskListCubit`, `TaskDetailCubit` (incl. `complete()`), `TaskFormCubit`.
- `lib/features/tasks/presentation/widgets/` — `task_status_badge.dart`,
  `task_priority_badge.dart`, `contact_select_sheet.dart`.
- `lib/features/tasks/presentation/screens/` — `task_list_screen.dart`,
  `task_form_screen.dart` (status field only shown when editing, matching
  the web `TaskForm.tsx`'s `{isEdit && (...)}` convention), `task_detail_screen.dart`.
- `lib/core/routing/app_router.dart` — new `/tasks`, `/tasks/new`,
  `/tasks/:id`, `/tasks/:id/edit` routes.
- `lib/main.dart`, `lib/features/more/presentation/screens/more_screen.dart`
  — `TaskRepository` added to the composition root; "Tasks" entry added to
  the More screen.
- Tests (32 total): `task_repository_impl_test.dart` (8),
  `task_list_cubit_test.dart` (4), `task_detail_cubit_test.dart` (4),
  `task_form_cubit_test.dart` (4), `task_list_screen_test.dart` (5),
  `task_detail_screen_test.dart` (5), `task_form_screen_test.dart` (5).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — all 32 Tasks-specific tests passing, no regressions in
  the existing suite.
- Real-device verification **not yet done** for this feature — see
  Follow-ups.

## Follow-ups / Deferred
- Real-device verification deferred: wireless ADB debugging dropped
  mid-session after an unrelated git-commit pass and has not reconnected
  since (`adb connect` → `Connection refused`). Planned as a combined pass
  together with Expenses once the phone reconnects, rather than blocking
  further Phase 6 work on it.
- `assigned_to`/`product`/`sale`/`quotation` task links — out of scope
  until mobile has the corresponding pickers.

## References
- `reports/CRM-2026-11-02-flutter-phase5-dashboard-charts.md`
- `reports/CRM-2026-11-02-flutter-phase4-products-crud.md`
- `backend/apps/tasks/{models,serializers,views}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/tasks/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** Partial session (part of a longer Phase 6 session)
