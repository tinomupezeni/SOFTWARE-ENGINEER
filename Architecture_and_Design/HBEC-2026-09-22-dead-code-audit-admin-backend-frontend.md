# Admin Backend/Frontend Dead-Code Audit — "No Frontend Caller" Was Not Enough

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Development → verified live on staging
**Severity:** Low (cleanup, no live-behavior change) — logged for the process
finding, not for the deletions themselves
**Status:** Resolved

## Summary
A deliberate dead-code audit of `ADMIN/adminBackend/` and `ADMIN/adminFrontend/`
started from "does the admin frontend call this endpoint." That single signal
was not sufficient and would have caused real damage if acted on directly: of
5 backend endpoints and 4 whole apps initially flagged as unused, cross-service
(Harness, Student) and DB-level (FK/model dependency) verification pulled
**most of them off the list**. Two turned out to be missing-frontend-wiring
bugs, not dead code (see the sibling entries this references). Only what
survived all three checks — no frontend caller, no cross-service caller, no
DB-level dependency — was actually removed.

## Investigation Steps

### 1. Initial Diagnosis
Grepped `ADMIN/adminFrontend/src` for every backend URL pattern in
`ADMIN/adminBackend/apps/*/urls.py`. Flagged apps `sources`, `indexing`,
`governance`, `artifacts` and 5 individual views as having no frontend caller.

### 2. Verification pass (the step that mattered)
Before removing anything: checked whether the Agentic Harness or Student
backend/frontend/mobile called any flagged item over HTTP or via the Redis
replication stream, then checked DB-level FK dependencies within admin's own
database, then confirmed deployment topology (one shared Postgres instance,
separate logical databases per service — no cross-database FK is even
possible, so HTTP/replication checks are the correct method for cross-service,
or intra-database FK checks are the correct method for same-service).

### 3. Key Findings
- `apps/governance/` looked unwired because the admin UI's audit log reads
  through a **duplicate** endpoint in `system_settings`, not governance's own
  `AuditLogListView`. The app itself (`SyllabusRelease`, `AuditEvent`) is
  core, FK'd from `curriculum` and `replication`, actively written from 4+
  apps. **Blocked from removal.**
- `apps/artifacts/` models are FK'd via the governance chain and used by
  `replication`'s own separate `Artifact`-querying logic — alive, just not
  through its own app's views. **Models blocked; its two view-only endpoints
  remain an open question, not resolved in this pass.**
- `CurriculumTreeView`, `CurriculumUnitListCreateView`/Detail,
  `MarkingStandardListCreateView`/Detail are the **only creation sites** in
  the codebase for models that `replication` already packages into
  Harness-bound release payloads — a built backend feature with no frontend
  built for it, not dead code. **Not removed** — logged as a product gap.
- `AttachMarkSchemeView` looked superseded by `PaperForm.tsx`'s inline upload
  at paper-creation time — but the *edit* page (`PaperFormPage.tsx`) calls
  `updatePaper()`, a JSON-only `PATCH` that silently drops any `File` a user
  selects. This view is the only real capability for replacing a mark scheme
  on an existing paper; the edit form just never calls it. **Not removed** —
  this is a real bug, logged separately
  (`Backend_and_API/HBEC-2026-09-22-admin-edit-paper-mark-scheme-silently-dropped.md`).
- `apps/replication/services.py` had **two more dead functions** the original
  grep pass missed: `build_ai_payload()` and `build_harness_questions_payload()`,
  both importing `apps.indexing.models.Question`, both with zero callers
  anywhere. Found only by tracing every import of the app being removed, not
  by the initial endpoint-caller grep.

## Root Cause
"No frontend caller" is necessary but not sufficient evidence of dead code in
a system with multiple consumers (Harness, Student, replication payloads) and
duplicate implementations of the same read path. Two of the five originally
flagged individual endpoints were actually missing-wiring bugs wearing dead
code's clothes.

## Prevention / Rule
**Guardrail:** before removing anything flagged "unused" in this codebase,
verify in this order: (1) grep the flagged name/model across `AGENTIC_HARNESS/`
and all of `STUDENT/` for HTTP or replication-stream dependency, (2) grep
`ADMIN/adminBackend/apps/*/models.py` for inbound FKs to the flagged model
from other apps, (3) check whether the model is the *only* creation site
for data something downstream (replication, a Celery task) already reads.
Only remove what clears all three. A model reachable by any of them is not
dead, whatever the frontend does or doesn't call.

This is what caught `governance`, `artifacts`' models, and the curriculum
authoring endpoints before they were deleted — the two real bugs surfaced
in step 1's kind of check (a *frontend* trace, not a backend one) but for a
different reason: the caller existed in the UI, it just called the wrong
thing.

## Solution

### Immediate Fix — removed (verified dead by all three checks)
1. **`apps/sources/`** — whole app. Self-documented `PARKED (2026-08-09)`,
   zero rows, zero producer, zero external caller.
2. **`apps/indexing/`** — whole app. Same status; downstream of `sources`.
3. **`build_ai_payload()`, `build_harness_questions_payload()`**
   (`apps/replication/services.py`) — zero callers, both referenced the
   now-removed `indexing.Question`.
4. **`DashboardLLMUsageSeriesView`** (`apps/dashboard/views.py`,
   `/dashboard/llm-usage/series/`) — built for a sparkline; the shipped
   `LLMUsageCard.tsx` explicitly uses a bar-share visualization instead
   ("so relative load reads without a chart"), confirming a design pivot,
   not a duplicate implementation.
5. **~18 files, admin frontend** — unused shadcn/ui primitives
   (`form.tsx`, `sidebar.tsx`, `drawer.tsx`, `avatar.tsx`, `pagination.tsx`,
   `input-otp.tsx`, `aspect-ratio.tsx`, `navigation-menu.tsx`, `breadcrumb.tsx`,
   `context-menu.tsx`, `menubar.tsx`, `carousel.tsx`, `toggle-group.tsx`,
   `accordion.tsx`, `hover-card.tsx`) plus a fully orphaned toast
   implementation chain (`toaster.tsx`, `toast.tsx`, both `use-toast.ts`
   copies) and `use-mobile.tsx`, found transitively dead only after
   `toaster.tsx` — their sole consumer — was removed. The app's real toast
   system is `sonner`, used throughout `src/features/*`.

### Staging DB
`source_documents`, `indexed_items`, `questions`, `content_chunks` confirmed
empty on staging before touching anything, then reverse-migrated
(`migrate indexing zero`, `migrate sources zero`) against the still-running
old container — the only point at which `manage.py migrate <app> zero` is
possible, since it requires the app still registered in `INSTALLED_APPS`.

### Not removed (deliberately left for follow-up, not silently dropped)
- `apps/governance/`'s own duplicate `AuditLogListView`/`ReleaseListView`
  (superseded by `system_settings`'s copy, but not verified deletion-safe in
  this pass)
- `apps/artifacts/views.py`'s two endpoints (models are alive; whether these
  specific views are a safe-to-drop duplicate of `replication`'s own
  `ArtifactDownloadView` was not resolved)
- `CurriculumTreeView`/`CurriculumUnitListCreateView`/`MarkingStandardListCreateView`
  — real backend capability with no frontend, a product gap not a bug
- `AttachMarkSchemeView` — see the sibling bug entry

### Verification
- Full admin backend suite: 731/731 passing (throwaway Postgres,
  `-p no:schemathesis`), migrations apply cleanly with no reference to the
  removed apps, `manage.py check` clean, `ruff check` clean on touched files.
- Full admin frontend suite: 242/242 passing, `tsc -b --noEmit` clean.
- `npm run build` failure (`mathlive` package entry resolution) confirmed
  **pre-existing** via `git stash` — reproduces identically on unmodified
  code, unrelated to this change.
- Staging: migrations reverse-applied and confirmed (`showmigrations` shows
  both apps fully unapplied, `\dt` confirms all 4 tables dropped).

## Prevention
- [x] Code changes required — done
- [x] Documentation to update — this entry, plus 2 sibling bug entries
- [x] Configuration changes needed — staging DB schema updated
- [ ] Monitoring/alerts to add — n/a

## Related Issues
- `Backend_and_API/HBEC-2026-09-22-admin-ingestion-review-mapping-endpoint-missing.md`
  (broken frontend call surfaced by this audit)
- `Backend_and_API/HBEC-2026-09-22-admin-edit-paper-mark-scheme-silently-dropped.md`
  (silently-dropped-file bug surfaced by this audit)

## References
- `ADMIN/adminBackend/apps/sources/`, `apps/indexing/` (removed)
- `ADMIN/adminBackend/apps/replication/services.py`
  (`build_ai_payload`, `build_harness_questions_payload`, removed)
- `ADMIN/adminBackend/apps/dashboard/views.py`, `urls.py`
  (`DashboardLLMUsageSeriesView`, removed)
- `ADMIN/adminFrontend/src/components/ui/`, `src/hooks/` (unused files removed)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — initial flag, cross-service/DB
verification, and staging-verified removal.
