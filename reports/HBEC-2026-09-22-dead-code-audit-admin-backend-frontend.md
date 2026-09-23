# Admin Backend/Frontend Dead-Code Audit — "No Frontend Caller" Was Not Enough

**Date:** 2026-09-22
**Project:** HBEC
**Type:** Audit / Cleanup
**Status:** Completed

## Summary
A deliberate dead-code audit of `ADMIN/adminBackend/` and `ADMIN/adminFrontend/`,
covering unwired endpoints and dead code on both sides. Started from "does the
admin frontend call this endpoint" as the initial signal, but that alone was
not sufficient and would have caused real damage if acted on directly: of 5
backend endpoints and 4 whole apps initially flagged as unused, cross-service
(Harness, Student) and DB-level (FK/model dependency) verification pulled
**most of them off the list**. Two turned out to be missing-frontend-wiring
bugs, not dead code, and got fixed instead of deleted. Only what survived all
three checks — no frontend caller, no cross-service caller, no DB-level
dependency — was actually removed.

## Context / Trigger
User request: "start a codebase auditing session, specifically focusing on
dead code removal, endpoints not wired to frontend, that are doing nothing,
lets start with admin backend n frontend." Explicit follow-up instruction
before any removal: "be absolutely sure those dead codes are not referenced
by harness or student, same at database level, and we also need to then do
thorough testing to make sure this removal didn't break anything."

## Scope
`ADMIN/adminBackend/` and `ADMIN/adminFrontend/` only, this pass. Cross-service
checks reached into `AGENTIC_HARNESS/` and all of `STUDENT/` (backend,
frontend, both mobile apps) as verification, not as removal targets — those
got their own audit the next day.

## Method
1. Three parallel research passes: enumerate every backend endpoint and
   cross-reference against every real frontend caller; symbol-level dead-code
   scan of the backend (unreferenced views/serializers/models/tasks); dead-code
   scan of the frontend (unreferenced components/hooks/exports).
2. Before removing anything flagged "unused": verify in this order —
   (1) grep the flagged name/model across `AGENTIC_HARNESS/` and all of
   `STUDENT/` for HTTP or replication-stream dependency, (2) grep
   `ADMIN/adminBackend/apps/*/models.py` for inbound FKs to the flagged model
   from other apps, (3) check whether the model is the *only* creation site
   for data something downstream (replication, a Celery task) already reads.
   Only remove what clears all three.
3. Deployment topology confirmed first: one shared Postgres instance,
   separate logical databases per service — no cross-database FK is even
   possible, so HTTP/replication checks are the correct method for
   cross-service dependency, intra-database FK checks for same-service.

## Decisions & Findings

**Pass 1 (initial flagging + verification):**
- `apps/governance/` looked unwired because the admin UI's audit log reads
  through a **duplicate** endpoint in `system_settings`, not governance's own
  `AuditLogListView`. The app itself (`SyllabusRelease`, `AuditEvent`) is
  core, FK'd from `curriculum` and `replication`, actively written from 4+
  apps. Blocked from removal (at this point — see pass 2).
- `apps/artifacts/` models are FK'd via the governance chain and used by
  `replication`'s own separate `Artifact`-querying logic — alive, just not
  through its own app's views. Models blocked; its two view-only endpoints
  left as an open question.
- `CurriculumTreeView`, `CurriculumUnitListCreateView`/Detail,
  `MarkingStandardListCreateView`/Detail are the **only creation sites** in
  the codebase for models that `replication` already packages into
  Harness-bound release payloads — a built backend feature with no frontend
  built for it, not dead code. Decision: do not remove, log as a product gap.
- `AttachMarkSchemeView` looked superseded by `PaperForm.tsx`'s inline upload
  at paper-creation time — but the *edit* page calls `updatePaper()`, a
  JSON-only `PATCH` that silently drops any `File` a user selects. This view
  is the only real capability for replacing a mark scheme on an existing
  paper; the edit form just never called it. Decision: this is a bug, not
  dead code — fix it (see References), don't delete it.
- `apps/replication/services.py` had two more dead functions the original
  grep pass missed: `build_ai_payload()` and `build_harness_questions_payload()`,
  both importing `apps.indexing.models.Question`, both with zero callers
  anywhere — found only by tracing every import of the app being removed,
  not by the initial endpoint-caller grep.

**Pass 2 (follow-up, resolving the two deferred items):**
- `apps/governance/`'s own `AuditLogListView` — confirmed true duplicate:
  `system_settings/views.py`'s `AuditLogsView` queries the identical
  `AuditEvent` model with a superset of filtering plus a detail view
  governance lacked. Decision: remove it and its now-unused
  `AuditEventSerializer`. Governance's 9 release-workflow views left
  untouched — confirmed a real, substantial state-machine service with no
  frontend built for it yet, the same built-but-unwired pattern as the
  curriculum endpoints above.
- `apps/artifacts/views.py`'s two endpoints — confirmed superseded:
  `apps/replication/views.py` has its own `ArtifactDownloadView`, mounted at
  `/_internal/artifact/download/<key>/`, the codebase's established
  convention for cross-service reads. Decision: remove `views.py`,
  `urls.py`, `serializers.py` entirely; the `Artifact`/`PrecomputeJob` models
  stay, alive via replication's own queries.
- Found and removed while re-auditing the ingestion feature further:
  `ReviewQueueList`/`ReviewItemCard`/`ReviewItemDetail`/`ReviewStatusBadge`
  and their exclusive hooks/API functions — the rest of a retired standalone
  `/ingestion/review` page.

**Still not removed (deliberately, not silently dropped):**
- `CurriculumTreeView`/`CurriculumUnitListCreateView`/`MarkingStandardListCreateView`
  — real backend capability with no frontend, a product gap not a bug.
- `AttachMarkSchemeView` — fixed (wired to the edit flow) rather than removed.
- Governance's 9 release-workflow views — a product gap, would need its own
  frontend to become reachable.

## Changes Made
1. `apps/sources/`, `apps/indexing/` — whole apps removed. Self-documented
   `PARKED (2026-08-09)`, zero rows, zero producer, zero external caller.
2. `build_ai_payload()`, `build_harness_questions_payload()`
   (`apps/replication/services.py`) — removed, zero callers.
3. `DashboardLLMUsageSeriesView` (`apps/dashboard/views.py`) — removed;
   built for a sparkline the shipped `LLMUsageCard.tsx` explicitly doesn't
   use ("reads without a chart"), a design pivot not a duplicate.
4. ~18 files, admin frontend — unused shadcn/ui primitives plus a fully
   orphaned toast implementation chain (`toaster.tsx`, `toast.tsx`, both
   `use-toast.ts` copies, `use-mobile.tsx`), transitively dead once
   `toaster.tsx` — their sole consumer — was identified as unused itself.
5. `apps/governance/`'s `AuditLogListView` + `AuditEventSerializer` — removed.
6. `apps/artifacts/views.py`, `urls.py`, `serializers.py` — removed entirely;
   models untouched.
7. Remaining retired ingestion review-page components/hooks — removed.

Staging DB: `source_documents`, `indexed_items`, `questions`,
`content_chunks` confirmed empty before touching anything, then
reverse-migrated (`migrate indexing zero`, `migrate sources zero`) against
the still-running old container — the only point at which this is possible,
since it requires the app still registered in `INSTALLED_APPS`.

## Verification
- Full admin backend suite: 731/731 passing (throwaway Postgres,
  `-p no:schemathesis`), migrations apply cleanly with no reference to the
  removed apps, `manage.py check` clean, `ruff check` clean on touched files.
- Full admin frontend suite: 242/242 passing, `tsc -b --noEmit` clean.
- `npm run build` failure (`mathlive` package entry resolution) confirmed
  pre-existing via `git stash` — reproduces identically on unmodified code.
- Staging: migrations reverse-applied and confirmed (`showmigrations` shows
  both apps fully unapplied, `\dt` confirms all 4 tables dropped), both
  services rebuilt and redeployed, removed routes confirmed 404, kept routes
  confirmed still working.

## Follow-ups / Deferred
- `CurriculumTreeView`/`CurriculumUnitListCreateView`/`MarkingStandardListCreateView`
  and governance's 9 release-workflow views remain built-but-unwired product
  gaps — would need their own frontend work to become reachable, not a
  cleanup task.
- The Student side of the codebase got its own follow-up audit the next day
  (see References).

## References
- `Backend_and_API/HBEC-2026-09-22-admin-ingestion-review-mapping-endpoint-missing.md`
  (broken frontend call surfaced by this audit, since fixed)
- `Backend_and_API/HBEC-2026-09-22-admin-edit-paper-mark-scheme-silently-dropped.md`
  (silently-dropped-file bug surfaced by this audit, since fixed)
- `reports/HBEC-2026-09-23-dead-code-audit-student-backend-frontend.md`
  (same methodology, Student side)
- `ADMIN/adminBackend/apps/sources/`, `apps/indexing/` (removed)
- `ADMIN/adminBackend/apps/replication/services.py`
  (`build_ai_payload`, `build_harness_questions_payload`, removed)
- `ADMIN/adminBackend/apps/dashboard/views.py`, `urls.py`
  (`DashboardLLMUsageSeriesView`, removed)
- `ADMIN/adminBackend/apps/governance/views.py`, `serializers.py`, `urls.py`
  (`AuditLogListView`, `AuditEventSerializer`, removed)
- `ADMIN/adminBackend/apps/artifacts/views.py`, `serializers.py`, `urls.py`
  (removed entirely; models untouched)
- `ADMIN/adminFrontend/src/components/ui/`, `src/hooks/` (unused files removed)
- `ADMIN/adminFrontend/src/features/ingestion/` (remaining retired
  review-page components/hooks removed)

---

**Completed By:** Claude Sonnet 5
**Duration:** Same session — initial flag, cross-service/DB verification,
and staging-verified removal.
