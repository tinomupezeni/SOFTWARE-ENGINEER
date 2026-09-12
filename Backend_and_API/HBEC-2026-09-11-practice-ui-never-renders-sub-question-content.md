# Live Practice UI Never Renders `sharedContext`/`subQuestions` — Structured Questions Showed Blank Bodies

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Fixed (frontend), deployed to staging

## Summary
Found immediately after verifying PR #42 (content ingestion pipeline fix —
one payload entry per top-level question, sub-parts nested in
`shared_context`/`sub_questions` instead of flattened into duplicate leaf
rows) via a user spot-check of a real O-Level paper
(`Biology Paper 1 June 2024`,
`https://staging-student.hbca.tech/practice/01a05201-0181-7ffb-b5be-fc1560cb3f65`).
User report: "the paper has no questions in it, like no questions at all,
all just question numbers."

The backend response was correct — `questionText` (`PaperQuestion.content`)
is legitimately empty for a question whose real text lives entirely under
`sharedContext`/`subQuestions[].content` (this is expected: PR #42
deliberately stopped copying the stem into every leaf). But the student
frontend's **live practice page never reads those two fields at all.**
`PracticeModePage` → `QuestionPaper` → `QuestionDisplay` only ever renders
`question.questionText`, so any question with real content nested under
`sharedContext`/`subQuestions` rendered as a bare question number with an
empty body and an empty answer box — exactly what the user saw.

A second component, `PracticeQuestion.tsx`, already had correct rendering
logic for `sharedContext`/`subQuestions` — but grepping usages showed it is
not the component actually mounted by the live `/practice/:paperId` route;
`QuestionPaper`/`QuestionDisplay` is.

## Scale
On staging's current data (after PR #42 merge + the 582-paper bulk resync
+ orphan cleanup):
- **1,759 of 17,814 `PaperQuestion` rows (≈10%)** have `content == ''` with
  a non-empty `sub_questions`.
- **188 of 694 papers (≈27%)** have at least one such question.

This is not a small edge case — it is the *normal* case for any real past
paper whose questions have sub-parts (the majority of structured papers),
since PR #42's whole point was to stop flattening those into the top-level
`content` field. The bug would have surfaced for a large fraction of
students opening a structured paper, not just the one flagged.

## Root Cause
`STUDENT/Frontend/src/features/exam-practice/types/index.ts`'s `Question`
type already declared `sharedContext?`/`subQuestions?`, and
`examApi.ts::fetchQuestions` already mapped both fields through from the
API response — the data reaches the frontend correctly. But nothing in the
live render path (`QuestionPaper.tsx` → `QuestionDisplay.tsx`) ever reads
them; `QuestionDisplay` renders only its `questionText` prop. This looks
like exactly the shape of gap PR #42 itself would produce: the backend
change (stop flattening, nest sub-parts) shipped without a matching
frontend change to actually display the new shape, because the one
component that *did* handle it (`PracticeQuestion.tsx`) isn't the one
mounted on the real route.

## Prevention / Rule
**Guardrail:** Whenever a backend response shape changes (a field
restructured, a new field populated instead of an old one), require a
snapshot/contract test in the same PR that feeds a real captured API
response — not a mock shaped to whatever the frontend already expects —
through the actual route-mounted component (`QuestionPaper`/`QuestionDisplay`
here, not any component that happens to implement the right logic), and
asserts the rendered output is non-empty for every populated field.

This closes the exact gap: the correct rendering logic already existed in
`PracticeQuestion.tsx`, but nothing proved the component actually mounted
on `/practice/:paperId` used it — a contract test against the real route
would have failed immediately instead of shipping to ~27% of papers.

## Solution

### Immediate Fix
`STUDENT/Frontend/src/features/exam-practice/api/examApi.ts` —
added `deriveQuestionText()`, applied at the single mapping point
(`fetchQuestions`) so every consumer downstream (not just the live page)
gets a populated `questionText` without needing its own fallback logic:
- If `questionText` is already non-empty, use it unchanged.
- Otherwise compose from `sharedContext` (if present) plus `subQuestions`:
  a single sub-question's content is used directly (no artificial `(a)`
  label for what is really just one question); two or more are each
  prefixed with their own label (`(a)`, `(b)`, ...).

This fixes display without touching the answer/marking flow — marking is
already done per top-level question (one `StructuredAnswer` box), which
matches a composed multi-part stem being shown as one block of text.

Added two new test cases to `examApi.test.ts` covering the single- and
multi-sub-question fallback paths; full existing suite (13 tests in this
file, 74 across `exam-practice`) still green. Typecheck: the 3 pre-existing
errors on `master` (`response.data possibly undefined`,
`PracticeModePage`'s `onRemix`/`diff` mismatch — confirmed pre-existing via
`git stash` + re-run, unrelated to this change) are unchanged; my edit
introduced zero new errors.

### Long-term Fix
Not done here, flagged for follow-up: `PracticeQuestion.tsx` appears to be
dead or parallel code that already solved this correctly — worth checking
whether it has any live callers, and if not, removing it (matches this
session's broader "duplication/nesting" cleanup theme) rather than leaving
two divergent question-rendering implementations, one correct and one not.

## Prevention
- [ ] Monitoring/alerts to add — none identified; this is a display bug,
      not something a backend health check would catch
- [ ] Documentation to update — note in the ingestion-pipeline docs
      (`logs/tino_look_at_this.md` et al.) that any frontend consuming
      `PaperQuestion` must be updated to read `sharedContext`/
      `subQuestions`, not just `content`, now that the sync is no longer
      flattening
- [ ] Code changes required — done (frontend fallback); the
      `PracticeQuestion.tsx` duplication cleanup is a follow-up, not done
      here

## Related Issues
- Discovered directly while verifying PR #42's content-ingestion fix
  (`2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`
  was the previous finding from the same verification pass).
- Same general pattern as this session's admin-frontend duplication
  findings (two components doing the same job, only one wired to the real
  route) — just found on the student frontend this time.

## References
- `STUDENT/Frontend/src/features/exam-practice/pages/PracticeModePage.tsx`
  (the real `/practice/:paperId` route)
- `STUDENT/Frontend/src/features/exam-practice/components/QuestionPaper.tsx`,
  `QuestionDisplay.tsx` (only ever read `questionText`)
- `STUDENT/Frontend/src/features/exam-practice/components/PracticeQuestion.tsx`
  (unused-on-this-route component that already rendered `sharedContext`/
  `subQuestions` correctly)
- `STUDENT/Frontend/src/features/exam-practice/api/examApi.ts` (fix applied
  here, `fetchQuestions`/`deriveQuestionText`)
- `STUDENT/hbec_backend/apps/practice/views.py:950-983`
  (`PracticeSetDetailView`, confirms backend payload shape is correct)

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery
