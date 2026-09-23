# Student Backend/Frontend Dead-Code Audit

**Date:** 2026-09-23
**Project:** HBEC
**Type:** Audit / Cleanup
**Status:** Completed

## Summary
Continuation of the dead-code audit methodology validated on
`ADMIN/adminBackend`/`ADMIN/adminFrontend`
(`reports/HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`),
applied to `STUDENT/hbec_backend`/`STUDENT/Frontend`. Same discipline:
nothing removed on "no frontend caller" alone — every candidate verified
against cross-service dependency (Harness, Admin), DB-level FK dependency,
and whether the "dead" thing was actually a duplicate-read, a superseded
path, or a missing-wiring bug wearing dead code's clothes.

## Context / Trigger
Direct continuation of the previous day's admin audit: "ok continue cleaning
the dead code out, on admin will move to student next," followed by "lets
startr on student side."

## Scope
`STUDENT/hbec_backend/` and `STUDENT/Frontend/` only. Cross-referenced
against three consumers this time (Frontend, Expo mobile, Flutter mobile),
not the admin audit's one. Harness and Admin backend used as cross-service
verification targets, not removal candidates.

## Method
Same three checks as the admin audit, applied in the same order: cross-
service HTTP/replication-stream dependency, DB-level FK dependency, and
"is this the only creation site for something read downstream." Carried
forward a lead from the admin audit — Student has its own independent
`apps/sources`/`apps/indexing`/`apps/governance`/`apps/artifacts`, same
names as Admin's now-removed dead apps — but treated it as a lead to verify,
not an assumption to trust.

## Decisions & Findings

**The carried-forward assumption didn't fully hold.** `apps/governance` and
`apps/artifacts` are genuinely live in Student (`artifacts` is called from
both `STUDENT/Frontend`'s and Expo's offline download services). Only
`apps/sources`/`apps/indexing` matched the "whole dead app" shape — and even
then without Admin's self-documenting `PARKED` docstring, making the
verification pass more load-bearing here than for Admin, since there was no
author's note to corroborate.

**`apps/governance` needed splitting, not a single verdict.** Its public
read (`ActiveReleasesView`) was a genuine duplicate — `apps/offline`
independently builds its own release catalog. But its *write* side (the
whole admin release-workflow, plus the audit log reading from it) was
confirmed actually dead in production, not a missing-wiring bug like
Admin's governance turned out to be: the real `SyllabusRelease` writer is
`apps/replication/stream_consumer.py`, which already does its own
`get_or_create` — this workflow layer is a redundant parallel path with
zero external callers on any side. Its `AuditEvent` writer was only ever
called from within this same dead path, so the audit log view read a model
that was never actually populated. Different verdict from both of Admin's
comparable cases (blocked-because-load-bearing, and blocked-because-only-
creation-site) — here the model is populated by a different, live path
entirely, which is what made the workflow layer safe to remove.

**`apps/ai_gateway`'s `SubmitMarkingView`/`SessionFeedbackView`** looked
like the Admin `AttachMarkSchemeView` false positive (a real backend proxy
with no caller) but resolved the opposite way: the frontend posts straight
to the Harness, with its own job-polling mechanism a plain proxy POST
couldn't replicate — genuinely superseded, not a missing wire.

**Test-only code left alone, per the established rule.** `ReleaseWorkflowService`
and `HarnessClient.submit_for_marking`/`get_session_feedback` have real,
substantial dedicated test coverage independent of the removed views.
Removed the views, left the tested service-layer code in place.

**A same-named-but-different function trap.** The research pass reported
`src/hooks/useAnalytics.ts` as 3-of-4-functions dead, citing a `fetchDueTopics`
with "9 live callers" as the survivor. Verifying directly found those 9
callers belong to an entirely different `fetchDueTopics` in
`src/features/analytics/api/analyticsApi.ts` — same name, zero relation to
the one in the dead `src/lib/analyticsApi.ts`. The whole file was dead, not
3 of 4 functions. Caught by tracing the exact import path per candidate
rather than trusting a name match against a caller-count claim.

## Changes Made

**Student backend:**
1. `apps/sources/`, `apps/indexing/` — whole apps removed. No `urls.py`
   (zero HTTP surface) in either, models never constructed outside their
   own tests, zero cross-service or DB-level FK dependency.
2. `apps/replication/services.py`'s webhook pipeline — `HMACVerifier`,
   `SyncHandler` (all `sync_*` + `bulk_sync`), `ReplicationService.
   process_webhook` — removed. The retired direct-HTTP-webhook path; its
   `/_internal/replicate/` endpoint was removed 2026-02-21, orphaning the
   handler instead of cleaning it up alongside it. `normalize_level_and_grade()`
   stays (used by the live `stream_consumer.py`). `ReplicationEvent`/
   `SyncCheckpoint` models stay (read by monitoring views).
3. `apps/governance`'s `ActiveReleasesView`, `AdminReleaseListView`,
   `AdminReleaseDetailView`, `AdminReleaseWorkflowView`, `AuditLogView` +
   their now-unused serializers — removed. `ExamModeView` (same file, a
   live, separate feature) untouched.
4. `apps/ai_gateway`'s `SubmitMarkingView`, `SessionFeedbackView` — removed.

**Student frontend:**
5. `src/hooks/useAnalytics.ts` + `src/lib/analyticsApi.ts` — whole file
   removed, corrected from the initial 3-of-4-functions finding.
6. `src/components/NavLink.tsx` — removed, zero JSX usage anywhere.
7. 21 unused shadcn/ui primitives in `src/components/ui/` — removed, same
   bulk-scaffolding pattern as Admin's frontend, each individually
   re-verified via component-name JSX grep. `src/hooks/use-mobile.tsx`
   removed with them (was `sidebar.tsx`'s only consumer).
8. Checked but not removed: Student's own toast/`use-toast`/`toaster`
   chain — unlike Admin's, `<Toaster />` is actually mounted in `App.tsx`.

Staging DB: `source_documents`, `indexed_items`, `questions`,
`content_chunks`, `replication_replicationevent`, `replication_synccheckpoint`
all confirmed empty before touching anything. `sources`/`indexing`
reverse-migrated against the then-running old container.

## Verification
- Full Student backend suite (throwaway Postgres + Redis): 784/789 passing,
  5 pre-existing failures confirmed via `git stash` to reproduce identically
  on unmodified code. `manage.py check` clean, migrations apply with no
  reference to removed apps, `ruff check` clean on touched files.
- Full Student frontend suite: 1254/1265 passing, the 11 failures being the
  same pre-existing `TourManager.test.tsx` gap already documented earlier
  this session, unrelated. `tsc -b --noEmit` clean.
- Staging: migrations reverse-applied and confirmed, all four backend
  services rebuilt and redeployed, confirmed healthy, removed routes return
  404, live routes (`exam-mode` 403 permission-gated correctly,
  `ai/conversations/` 402 subscription-gated correctly) unaffected.

## Follow-ups / Deferred
- Harness and Mobile (Expo + Flutter) codebases remain unaudited by this
  methodology as of this report.
- Two Admin management commands (`sync_to_student.py`, `reconcile_student.py`)
  were found already dead/broken — POSTing to a route that no longer exists
  — as a byproduct of this audit's cross-service check. Not acted on; a
  separate Admin-side cleanup item.

## References
- `reports/HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`
  (same methodology, Admin side, the two false-positive lessons this audit
  built on)
- `STUDENT/hbec_backend/apps/sources/`, `apps/indexing/` (removed)
- `STUDENT/hbec_backend/apps/replication/services.py` (webhook pipeline
  removed, `normalize_level_and_grade` kept)
- `STUDENT/hbec_backend/apps/governance/views.py`, `serializers.py`,
  `urls.py` (5 views + serializers removed, `ExamModeView` kept)
- `STUDENT/hbec_backend/apps/ai_gateway/views.py`, `urls.py` (2 views
  removed)
- `STUDENT/Frontend/src/hooks/`, `src/lib/analyticsApi.ts`,
  `src/components/NavLink.tsx`, `src/components/ui/` (removed files)

---

**Completed By:** Claude Sonnet 5
**Duration:** Same session — initial flag, cross-service/DB verification (2
additional rounds beyond the first pass), and staging-verified removal.
