# "Add New Paper" Still Made an Admin Re-Pick Exam Board and Subject They Were Already On

**Date:** 2026-09-17
**Project:** HBEC
**Environment:** Production
**Severity:** Low (UX friction, not a crash — but the code's own comment already claimed this was fixed)
**Status:** Resolved

## Summary
User reported that clicking "Add Paper" from inside a specific subject's own
admin page still required manually re-selecting Exam Board and Subject in
the resulting form, even though both were already fully determined by the
page the user was already on. Root cause: `SubjectPage.tsx`'s call to
`ExamPaperForm` (`PaperForm.tsx`) passed `defaultExamBoardId`/
`defaultSubjectId` (and even carries a comment saying "pre-filled to this
subject so there is nothing to re-pick"), but never passed the
`examBoards`/`subjects` option arrays those two `Select` components render
their choices from. With no options array, the pre-filled id had nothing to
display against, so the field looked unset/blank — and worse, nothing
disabled the field either, so the user could (and evidently did) still
freely re-pick it.

## Symptoms
- Opening "Add Paper" from a subject's detail page shows Exam Board/Subject
  fields that look unselected, and both remain fully editable dropdowns
  requiring the user to search/re-pick values that were already known.

## Environment Details
- **Server/Host:** Production (`admin.hbca.tech`)
- **Services Affected:** `ADMIN/adminFrontend`
  (`src/features/curriculum/pages/SubjectPage.tsx`,
  `src/features/exam-practice-admin/components/PaperForm.tsx`)
- **Time First Observed:** 2026-09-17, reported by the user directly

## Investigation Steps

### 1. Initial Diagnosis
Found the `PaperForm` component behind the "Add New Paper" dialog (title
and description text matched the user's report exactly). Its props already
included `defaultExamBoardId`/`defaultSubjectId`, with an inline comment
explaining their exact purpose — meaning this had already been *intended*
to work, not merely never attempted.

### 2. Root Cause Analysis
`PaperForm`'s two `Select`s render their choices from `examBoards`/
`subjects` prop arrays (`board.name` per `examBoards.map(...)`,
`subject.name`/`code` per `subjects.map(...)`) — `defaultExamBoardId`/
`defaultSubjectId` only seed `useForm`'s `defaultValues`, nothing more.
`SubjectPage.tsx`'s call site passed the two default-id props but not the
option arrays:
```tsx
<ExamPaperForm
  ...
  defaultExamBoardId={subject.examBoardId}
  defaultSubjectId={subject.id}
/>
```
The very next dialog in the same file, `BulkImportDialog`, does it
correctly — same subject/board data, same page:
```tsx
<BulkImportDialog
  ...
  examBoards={[{ id: subject.examBoardId, name: board?.name ?? '' }]}
  subjects={[{ id: subject.id, name: subject.name, code: subject.code }]}
  defaultExamBoardId={subject.examBoardId}
  defaultSubjectId={subject.id}
/>
```
`board`/`subject` were already loaded on the page (`useExamBoard`/
`useSubject`), so the fix was purely "pass what's already in scope,
matching the working sibling call three lines down."

### 3. Key Findings
- `PaperForm` had no notion of "locked" at all — even with a correctly
  supplied default and matching option array, the field would have stayed
  a live, searchable dropdown rather than reflecting that the context
  already fully determined the value.
- The context-less "Papers" list page (`ExamPracticeAdminPage.tsx`) and the
  edit-only `PaperFormPage.tsx` both correctly never pass the two default
  props at all — so a fix scoped to "lock only when both defaults are
  supplied" doesn't touch either of them.

## Root Cause
An incomplete implementation: the plumbing for "pre-fill from context" was
built (`defaultExamBoardId`/`defaultSubjectId`, `useForm` defaults) but the
one thing that actually makes a `Select` show a value — its option list —
was never passed at the one call site (`SubjectPage.tsx`) meant to use it,
and nothing in the component enforced that a supplied default should also
disable the field.

## Prevention / Rule
**Guardrail:** When a form component accepts a "default value" prop for a
`Select`/similar picker, treat "default supplied" and "the field is locked"
as one property to keep in sync programmatically (e.g. `disabled={Boolean(defaultValue)}`
derived inside the component), not left to every call site to remember
independently — this is exactly what let a correct sibling call
(`BulkImportDialog`) coexist right next to an incomplete one
(`ExamPaperForm`) in the same file without either being obviously wrong at
a glance.

## Solution

### Immediate Fix
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectPage.tsx` —
  `ExamPaperForm` call now also passes `examBoards`/`subjects` single-item
  arrays, mirroring `BulkImportDialog`'s existing correct call.
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.tsx` —
  new `contextLocked = Boolean(defaultExamBoardId && defaultSubjectId)`;
  both the Exam Board and Subject `Select`s are now `disabled={contextLocked}`
  (Subject also keeps its existing `!examBoardId` disable condition). Only
  locks when *both* defaults are supplied — the context-less Papers list
  page (which supplies neither) stays fully editable.
- Tests: `PaperForm.test.tsx` (new) — asserts both fields stay editable
  with no context, both lock when both defaults are supplied, and neither
  locks when only one default is supplied.

### Long-term Fix
None needed beyond the above.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — none beyond the inline comments added
- [x] Code changes required — done (see Solution)

## Related Issues
- Found and fixed in the same session as
  `HBEC-2026-09-17-question-editor-crashed-on-ai-extracted-marking-points.md`
  (a separate, unrelated crash reported at the same time from the paper
  review queue).

## References
- `ADMIN/adminFrontend/src/features/curriculum/pages/SubjectPage.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperForm.test.tsx`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — diagnosed, fixed, tested, and
deployed to staging and production within the hour
