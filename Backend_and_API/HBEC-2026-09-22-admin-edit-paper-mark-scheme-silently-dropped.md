# Editing an Existing Exam Paper Silently Drops a New Mark Scheme File

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Discovered during a dead-code audit of admin backend/frontend
(verifying `AttachMarkSchemeView` was actually unused before proposing its
removal)
**Severity:** Medium — a real admin action fails with no error and no
feedback to the user
**Status:** Investigating (found, not yet fixed — logged per the
found-or-fixed rule; fix is follow-up work, not part of this session's scope)

## Summary
`AttachMarkSchemeView` (`/exam-practice/papers/<pk>/attach-mark-scheme/`)
looked like dead code — no frontend caller — during the dead-code audit. It
isn't. `PaperForm.tsx` shows a mark-scheme upload field in **both** create
and edit mode and always packs a selected `File` into its `onSubmit` payload
(`handleFormSubmit`, `PaperForm.tsx:133-147`). In create mode that reaches
`createPaper()`, which correctly switches to `FormData` when a file is
present. In edit mode (`PaperFormPage.tsx`), the same payload reaches
`updatePaper()` (`examPracticeApi.ts:95-103`), which is **JSON-only**
(`PATCH`, `JSON.stringify(data)`) — a `File` object does not survive that
serialization. The file is silently discarded; no request is ever sent for
it, and the form otherwise reports success.

## Symptoms
Not yet reproduced against a live UI action — found by tracing the two
`onSubmit` paths, not from a user report. Expected symptom: an admin editing
an existing paper, replacing its mark scheme PDF, and saving sees the update
succeed with no error — but the paper's mark scheme is never updated on the
backend.

## Investigation Steps

### 1. Initial Diagnosis
The dead-code audit initially flagged `AttachMarkSchemeView` as superseded by
`PaperForm.tsx`'s inline upload at paper-creation time (`createPaper()`
switches to `FormData`/multipart when `markSchemeFile` is set). Before
removing it, checked whether that "superseded" story held for the *edit*
path too.

### 2. Root Cause Analysis
```ts
// examPracticeApi.ts:95-103 — used by PaperFormPage.tsx's edit flow
export async function updatePaper(id: string, data: Partial<PaperFormData>) {
  return apiFetch<ExamPaper>(`/exam-practice/papers/${id}/`, {
    method: 'PATCH',
    body: JSON.stringify(data),   // a File in `data` serializes to "{}"
  });
}
```
`PaperForm.tsx` does not branch its submit payload on create-vs-edit mode —
`handleFormSubmit` always includes `markSchemeFile`. Only `createPaper()`
inspects the payload for a file and switches transport; `updatePaper()` does
not, because it was written assuming edits are metadata-only.

### 3. Key Findings
- The backend capability this needs already exists and is fully wired
  (`AttachMarkSchemeView` → `attach_marking_scheme_via_harness` →
  `finalise_paper_ingestion`, a real Celery chain) — it was never dead, it
  was simply never called from the edit flow.

## Root Cause
`PaperForm.tsx` is shared between create and edit mode and presents the same
mark-scheme upload UI in both, but the two modes' submit handlers diverge in
file-handling capability without the form itself knowing or warning about it.

## Prevention / Rule
**Guardrail:** none proposed yet — the fix itself (wire the edit path to
`AttachMarkSchemeView`, or teach `updatePaper()` to switch to `FormData`
like `createPaper()` does) will determine the right one. A reasonable
candidate once fixed: a test that edits a paper with a new mark-scheme file
and asserts the file actually reaches the backend, not just that the PATCH
returns 200.

## Solution

### Immediate Fix
None yet — out of scope for the dead-code cleanup session that surfaced this.
`AttachMarkSchemeView` was deliberately left in place, unremoved, because of
this finding.

### Long-term Fix
Needs: either (1) `updatePaper()` gains the same file-detection branch
`createPaper()` already has and calls `AttachMarkSchemeView` (or an
equivalent update-with-file endpoint) when a new mark scheme is present, or
(2) the edit form is changed to route mark-scheme replacement through its own
explicit action rather than bundling it into the general metadata PATCH.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [ ] Code changes required — pending

## Related Issues
Surfaced by `Architecture_and_Design/HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`.

## References
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.tsx:133-147`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/pages/PaperFormPage.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/api/examPracticeApi.ts:62-103`
- `ADMIN/adminBackend/apps/exam_papers/views.py:692` (`AttachMarkSchemeView`, kept)
- `ADMIN/adminBackend/apps/exam_papers/tasks.py:406` (`attach_marking_scheme_via_harness`)

---

**Resolved By:** Not yet resolved
**Time to Resolution:** N/A
