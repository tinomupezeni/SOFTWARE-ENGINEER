# "Upload New Paper" Was Fully Built End-to-End But Had No Button or Route Anywhere in the Admin UI

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Fixed, deployed to staging

## Summary
Asked directly by the user for "the page to do the upload" so they could
click through the PDF → harness ingestion → student sync pipeline
themselves (the pipeline just verified/fixed via PR #42 earlier this
session). Went looking for it and found there wasn't one: every piece of
the create-with-PDF path exists and is correctly wired to each other —
`PaperForm.tsx` (drag-drop zones for Paper PDF and Mark Scheme PDF,
supports an optional `paper` prop specifically so it can run in create
mode), `createPaper()` in `examPracticeApi.ts` (posts multipart
`FormData` to admin backend, which stores the file and forwards it to the
harness's `/papers/upload` on "Start Extraction"), and the `useCreatePaper`
hook wrapping it — but nothing in the actual page tree ever renders
`PaperForm` without a `paper` already loaded, and nothing calls
`useCreatePaper` at all.

`PaperFormPage.tsx` (the only route that mounts `PaperForm`,
`/exam-practice-admin/:id/edit`) is edit-only: it calls `usePaper(id)` and
renders "Paper not found" if there's no existing paper. There is no `/new`
route, and `ExamPracticeAdminPage.tsx` (the list page) only has buttons
for "Bulk Import" (CSV/JSON) and "Generate AI Paper" — no button opens
`PaperForm` in create mode. `useCreatePaper` had zero callers anywhere in
the codebase (confirmed via `grep -rln`).

Net effect: there was no way, through the admin UI, to upload a new past
paper for harness extraction — a fully-built feature was completely
unreachable.

## Investigation Steps
1. Traced the real harness ingestion entry point:
   `AGENTIC_HARNESS/app/admin/router.py`'s `POST /papers/upload` →
   `upload_pipeline.py::_process_upload_from_path`, which automatically
   calls the (now-fixed) `sync_paper_to_student` on success, gated by
   `meets_publish_quality_bar`.
2. Traced how the admin frontend reaches that endpoint: not directly —
   `ADMIN/adminBackend/apps/exam_papers/services/harness_client.py` POSTs
   to `/api/v1/admin/papers/upload` on the admin backend's behalf, invoked
   from `ExtractQuestionsView` (`extract_questions_via_harness` Celery
   task), which reads the PDF the paper already has stored.
3. So a paper must exist (with its file attached) *before* extraction can
   be triggered — traced how a paper is created:
   `examPracticeApi.ts::createPaper` already builds the right multipart
   `FormData` (`paperFile`, `markSchemeFile`, exam board/subject/etc.) and
   posts to `/exam-practice/papers/`.
4. Traced which page calls `createPaper`/`useCreatePaper`: none.
   `ADMIN/adminFrontend/src/features/exam-practice-admin/index.ts` exports
   `useCreatePaper`, `hooks/index.ts` defines it, but `grep -rln
   "useCreatePaper" ADMIN/adminFrontend/src` returned only those two
   definition/export files — no consumer.
5. Confirmed `PaperForm`'s `paper?: ExamPaper` prop is already optional
   and its dialog title/description already branch on `paper` being
   undefined ("Add New Paper" / "Upload exam papers with mark schemes for
   question extraction and practice.") — the component was written to
   support create mode, it just was never given anywhere to be mounted
   that way.

## Root Cause
The create-mode UI for `PaperForm` was built (component, API client,
hook) but the page-level wiring to reach it — a route or a button opening
it as a dialog — was never added. Every other admin-side create flow in
this feature area (Bulk Import, Generate AI Paper) has a button on
`ExamPracticeAdminPage`; the plain single-PDF-upload create flow never
got one.

## Solution

### Immediate Fix
`ADMIN/adminFrontend/src/features/exam-practice-admin/pages/ExamPracticeAdminPage.tsx`:
- Added an "Upload Paper" button next to "Bulk Import".
- Wired `useCreatePaper`, a `showCreatePaper` dialog-open state, and a
  `createExamBoardId` state (so the dialog's own exam-board picker can
  drive its own subject list independently of the list page's filters,
  via a second `useSubjectsForPapers(createExamBoardId)` call).
- Renders `<PaperForm>` with no `paper` prop (create mode) when the
  dialog is open; on successful create, closes the dialog and navigates
  straight to the new paper's detail page, where "Start Extraction"
  (already wired, unchanged) is the next real step.

Typecheck clean (admin frontend, `tsc -b --noEmit`), lint clean (only
pre-existing warnings in the touched file, no new ones).

### Long-term Fix
None needed beyond this — the rest of the stack (backend view, harness
client, harness pipeline, sync-to-student) was already correct and
unchanged; this was purely a missing UI entry point.

## Prevention
- [ ] Monitoring/alerts to add — n/a, UI-reachability gap
- [ ] Documentation to update — n/a
- [ ] Code changes required — done

## Related Issues
- Found while manually verifying, at the user's request, that a fresh
  admin upload genuinely reaches the fixed PR #42 sync path end-to-end
  (`2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`,
  `2026-09-11-practice-ui-never-renders-sub-question-content.md` were the
  two earlier findings from the same verification pass).
- Same general "built but never wired" shape as
  `2026-09-10-learning-guide-authored-content-never-consumed-anywhere.md`
  from the previous day's audit — a different feature, same failure mode.

## References
- `ADMIN/adminFrontend/src/features/exam-practice-admin/pages/ExamPracticeAdminPage.tsx`
  (fix applied here)
- `ADMIN/adminFrontend/src/features/exam-practice-admin/pages/PaperFormPage.tsx`
  (edit-only, unchanged)
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.tsx`
  (already create-mode-capable, unchanged)
- `ADMIN/adminFrontend/src/features/exam-practice-admin/api/examPracticeApi.ts::createPaper`
- `ADMIN/adminBackend/apps/exam_papers/views.py::ExtractQuestionsView`,
  `apps/exam_papers/services/harness_client.py`
- `AGENTIC_HARNESS/app/admin/router.py:209` (`POST /papers/upload`),
  `app/admin/services/upload_pipeline.py::_process_upload_from_path`

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery
