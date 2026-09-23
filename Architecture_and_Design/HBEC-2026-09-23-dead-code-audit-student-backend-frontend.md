# Student Backend/Frontend Dead-Code Audit

**Date:** 2026-09-23
**Project:** HBEC
**Environment:** Development → verified live on staging
**Severity:** Low (cleanup, no live-behavior change) — logged for the process
findings, not for the deletions themselves
**Status:** Resolved

## Summary
Continuation of the dead-code audit methodology validated on
`ADMIN/adminBackend`/`ADMIN/adminFrontend`
(`HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`), applied to
`STUDENT/hbec_backend`/`STUDENT/Frontend`. Same discipline: nothing removed
on "no frontend caller" alone — every candidate verified against
cross-service dependency (Harness, Admin), DB-level FK dependency, and
whether the "dead" thing was actually a duplicate-read, a superseded path,
or a missing-wiring bug wearing dead code's clothes.

## Investigation Steps

### 1. Initial Diagnosis
Enumerated every Student backend route and cross-referenced against
`STUDENT/Frontend`, `STUDENT/Mobile` (Expo), and `STUDENT/mobile_flutter` —
three consumers, not the admin audit's one. Also carried forward a
known lead from earlier this session: Student has its own independent
`apps/sources`/`apps/indexing`/`apps/governance`/`apps/artifacts` — same
names as Admin's now-removed dead apps, but separate implementations that
needed their own verification, not an assumption they'd match.

### 2. Key Findings — the correction that mattered
The prior-session assumption that all four Student apps mirrored Admin's
dead ones **did not hold**: `apps/governance` and `apps/artifacts` are
genuinely live in Student (`artifacts` is called from both
`STUDENT/Frontend`'s and Expo's offline download services; `governance`
turned out to have some live parts and some dead parts, not a clean
verdict either way — see below). Only `apps/sources`/`apps/indexing`
matched the "whole dead app" shape, and even then without Admin's
self-documenting `PARKED` docstring — dead by omission, not by the team's
own admission, which made the cross-service/DB verification pass more
load-bearing here than it was for Admin.

**`apps/governance` needed splitting, not a single verdict.** Its public
read (`ActiveReleasesView`) was a genuine duplicate — `apps/offline`
independently builds its own release catalog. But its *write* side (the
whole admin release-workflow — create/submit-review/approve/publish/
rollback, plus the audit log reading from it) was confirmed **actually
dead in production**, not a missing-wiring bug like Admin's governance
turned out to be: the real `SyllabusRelease` writer is
`apps/replication/stream_consumer.py`, which already does its own
`get_or_create` — this workflow layer is a redundant parallel path with
zero external callers on any side (Frontend, mobile, or Admin-initiated).
Its `AuditEvent` writer was only ever called from within this same dead
path, so the audit log view read a model that was never actually
populated. This is a different verdict from Admin's governance (blocked
because it was load-bearing) *and* from Admin's curriculum-authoring
endpoints (blocked because they were the only creation site for data
something downstream read) — here the model is populated by a different,
live path entirely, which is what made the workflow layer safe to remove.

**`apps/ai_gateway`'s `SubmitMarkingView`/`SessionFeedbackView`** looked
like the Admin `AttachMarkSchemeView` false positive (a real backend
proxy with no caller) but resolved the opposite way on inspection: traced
the real marking-submission path and found the frontend posts **straight
to the Harness**, with its own job-polling mechanism a plain proxy POST
couldn't replicate — a genuinely superseded, architecturally-consistent
alternate path, not a missing wire.

**Test-only code was left alone, per the established rule.** Both
`apps/governance`'s `ReleaseWorkflowService` and
`apps/ai_gateway`'s `HarnessClient.submit_for_marking`/
`get_session_feedback` have real, substantial dedicated test coverage
(`test_immutability.py`, `test_services.py`) exercising them directly,
independent of the now-removed views. Removed the views; left the tested
service-layer code in place, since "used only by tests" is real code, not
dead code, per this repo's established convention.

**A same-named-but-different function trap.** The dead-code fork reported
`src/hooks/useAnalytics.ts` (frontend) as 3-of-4-functions dead, citing a
`fetchDueTopics` with "9 live callers" as the survivor. Verifying directly
found those 9 callers belong to an entirely different `fetchDueTopics` in
`src/features/analytics/api/analyticsApi.ts` — same name, same rough
shape, zero relation to the one in the dead `src/lib/analyticsApi.ts`.
The whole file was dead, not 3 of 4 functions. Caught by tracing the
*exact* import path per candidate rather than trusting a name match.

## Root Cause
Two failure modes, matched to two different fixes:
1. Dead code without a self-authored marker (unlike Admin's `PARKED`
   docstrings) reads identically to live-but-unwired code from a caller
   grep alone — the cross-service/DB verification pass is what
   distinguishes them, and skipping it would have produced the same kind
   of false positive Admin's audit caught twice.
2. A same-named function in a different file is a distinct dead-code
   surface from the one actually being investigated — name-matching a
   grep result to "the" function in question, instead of tracing the
   specific import path, understates or overstates what's actually dead.

## Prevention / Rule
**Guardrail:** unchanged from the Admin entry — verify cross-service HTTP
dependency, DB-level FK dependency, and "is this the only creation site
for something read downstream" before removing anything flagged unused.
Added this session: when a caller-count claim survives verification (e.g.
"N live callers"), confirm those callers import the *exact same file*,
not a same-named export from a different one.

## Solution

### Removed — Student backend
1. **`apps/sources/`, `apps/indexing/`** — whole apps. No `urls.py` (zero
   HTTP surface) in either, models never constructed outside their own
   tests, zero cross-service (Harness/Admin) or DB-level FK dependency.
2. **`apps/replication/services.py`'s webhook pipeline** — `HMACVerifier`,
   `SyncHandler` (all `sync_*` + `bulk_sync`), `ReplicationService.
   process_webhook`. The retired direct-HTTP-webhook path; the
   `/_internal/replicate/` endpoint it served was removed 2026-02-21,
   orphaning the handler instead of cleaning it up alongside it.
   `normalize_level_and_grade()` stays (used by the live
   `stream_consumer.py`). `ReplicationEvent`/`SyncCheckpoint` models stay
   (read by monitoring views) — already not written to in production
   today, so removal doesn't change that, just makes it explicit.
3. **`apps/governance`'s `ActiveReleasesView`, `AdminReleaseListView`,
   `AdminReleaseDetailView`, `AdminReleaseWorkflowView`, `AuditLogView`**
   + their now-unused serializers. `ExamModeView` (same file, a live,
   separate feature) untouched.
4. **`apps/ai_gateway`'s `SubmitMarkingView`, `SessionFeedbackView`**.

### Removed — Student frontend
5. **`src/hooks/useAnalytics.ts` + `src/lib/analyticsApi.ts`** (whole
   file, corrected from the initial 3-of-4-functions finding).
6. **`src/components/NavLink.tsx`** — zero JSX usage anywhere.
7. **21 unused shadcn/ui primitives** in `src/components/ui/` — same
   bulk-scaffolding pattern as Admin's frontend, each individually
   re-verified via component-name JSX grep, not just import-count.
   `src/hooks/use-mobile.tsx` removed with them (was `sidebar.tsx`'s only
   consumer).
8. Checked but **not removed**: Student's own toast/`use-toast`/
   `toaster` chain — unlike Admin's, `<Toaster />` is actually mounted in
   `App.tsx`. Confirmed live before assuming the same pattern applied.

### Staging DB
`source_documents`, `indexed_items`, `questions`, `content_chunks`,
`replication_replicationevent`, `replication_synccheckpoint` all
confirmed empty before touching anything. `sources`/`indexing` reverse-
migrated (`migrate indexing zero`, `migrate sources zero`) against the
then-running old container — the only point at which this is possible,
since it requires the app still registered in `INSTALLED_APPS`.

### Verification
- Full Student backend suite (throwaway Postgres + Redis): 784/789
  passing, 5 pre-existing failures confirmed via `git stash` to reproduce
  identically on unmodified code (a `replay_dropped_messages` management
  command test, unrelated `ContentStreamConsumer` mock-patch target
  issue). `manage.py check` clean, migrations apply with no reference to
  removed apps, `ruff check` clean on touched files.
- Full Student frontend suite: 1254/1265 passing, the 11 failures being
  the same pre-existing `TourManager.test.tsx` `QueryClientProvider` gap
  already documented in this session's family-plans work (dated
  2026-09-19, unrelated). `tsc -b --noEmit` clean.
- Staging: migrations reverse-applied and confirmed, all four backend
  services rebuilt and redeployed, confirmed healthy, removed routes
  return 404, live routes (`exam-mode` 403 permission-gated correctly,
  `ai/conversations/` 402 subscription-gated correctly) unaffected.

## Prevention
- [x] Code changes required — done
- [x] Documentation to update — this entry
- [x] Configuration changes needed — staging DB schema updated
- [ ] Monitoring/alerts to add — n/a

## Related Issues
- `Architecture_and_Design/HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`
  (same methodology, Admin side, the two false-positive lessons this audit
  built on)

## References
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

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — initial flag, cross-service/DB
verification (2 additional rounds beyond the first pass), and
staging-verified removal.
