# "Create Paper" had no AI-generation option — two disconnected paper-creation flows

**Date:** 2026-11-03
**Project:** HBEC
**Environment:** Production
**Severity:** Low
**Status:** Resolved

## Summary
An admin (Mutsa) reported on 2026-10-29: "the interfaces are different, when you do Create Paper you don't get the ai options." The admin paper-management page had two entirely separate paper-creation entry points built at different times: "Upload Paper" (`PaperForm.tsx`, upload-first, with its own exam board/subject pickers) and a "Generate AI Paper" button (`AIGenerationModal.tsx`, AI-first) — and the two were never connected. Worse, the AI button only appears once a subject and exam board are already selected in the page's filter bar, because `AIGenerationModal` has no subject/board pickers of its own and relies entirely on the page's current filters.

## Symptoms
- Clicking "Upload Paper" / "Create Paper" never offered any way to generate with AI instead.
- The separate "Generate AI Paper" button only appeared after pre-filtering the page to a specific subject and exam board — unlike "Upload Paper", which is always visible — making the two paths feel inconsistent ("the interfaces are different").

## Environment Details
- **Server/Host:** HBEC ADMIN frontend
- **Services Affected:** `ADMIN/adminFrontend` (`exam-practice-admin` feature)
- **Related Components:** `components/PaperForm.tsx`, `components/AIGenerationModal.tsx`, `pages/ExamPracticeAdminPage.tsx`
- **Time First Observed:** 2026-10-29

## Investigation Steps

### 1. Initial Diagnosis
Read `PaperForm.tsx` (upload/manual-entry fields, two PDF dropzones, zero AI-related code) and `AIGenerationModal.tsx` (AI-specific fields: year, paper number, paper count, question count, paper type — but no exam board/subject selectors of its own).

### 2. Root Cause Analysis
`ExamPracticeAdminPage.tsx` renders both as independent dialogs, triggered by two differently-labeled buttons ("Upload Paper" vs "Generate AI Paper"), submitting to two different mutations (`createMutation` vs `generateAIMutation`). Confirmed `AIGenerationModal`'s `examBoardId`/`subjectId` are props sourced from the page's own filter state, not from any field inside the modal — explaining why its trigger button is gated behind `filters.subjectId && filters.examBoardId` both being set.

### 3. Key Findings
- These were two independently-built features bolted onto the same page rather than one form with a source choice: `PaperForm` (upload) predates AI generation; `AIGenerationModal` was added later as its own button + dialog.
- `PaperForm` already has its own exam board/subject selectors, independent of the page's filters — meaning it was actually the *better* place to host AI generation, since doing so would also remove the AI path's dependency on pre-selected page filters.

## Root Cause
AI paper generation was added as a second, disconnected creation flow instead of as an option within the existing "Create Paper" form, and that second flow was never given its own subject/board pickers.

## Prevention / Rule
**Guardrail:** When a new "source" or "mode" for creating the same kind of record is added (upload vs. generate, manual vs. import, etc.), it should be a mode choice inside the existing creation form rather than a second independent dialog/button, unless there's a specific reason they must stay separate — reviewers should ask "could this be a toggle in the existing form?" before approving a parallel entry point.

## Solution

### Immediate Fix
N/A — no incident, a missing capability.

### Long-term Fix
Added an "Upload PDF" / "Generate with AI" mode toggle directly inside `PaperForm.tsx` (create mode only, shown only when the caller wires up the new `onGenerateAI` prop):
- Reuses the form's own existing exam board/subject selectors for both modes.
- In AI mode, swaps the upload-specific fields (title, code, duration, total marks, variant, session, PDF dropzones) for the AI-specific ones (year, paper number, number of papers, questions per paper, paper type) — mirroring `AIGenerationModal`'s own field set.
- Submission branches client-side: AI mode bypasses the upload form's zod validation entirely and calls the new `onGenerateAI` callback instead of `onSubmit`.
- `ExamPracticeAdminPage.tsx` wires `onGenerateAI` to the same `generateAIMutation` the standalone `AIGenerationModal` already used — no backend change, no new endpoint.
- The original standalone "Generate AI Paper" button/modal was left in place (still useful once a subject is already selected via the page filters); this adds a second, always-available path to the same capability rather than replacing the first.
- Added tests to `PaperForm.test.tsx` (3 new tests: toggle hidden without `onGenerateAI`, hidden in edit mode, switching modes shows the right fields and calls `onGenerateAI` not `onSubmit`). Full `exam-practice-admin` vitest suite (93 tests) and `tsc --noEmit` both clean.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `HBEC-2026-11-03-question-parts-exploded-into-sibling-rows.md`
- `HBEC-2026-11-03-add-part-breaks-after-sub-part-added.md`
- (same admin feedback thread, three separate issues from one message)

## References
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/AIGenerationModal.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/pages/ExamPracticeAdminPage.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.test.tsx`

---

**Resolved By:** Claude (session with Tinotenda Mupezeni)
**Time to Resolution:** Same session as investigation
