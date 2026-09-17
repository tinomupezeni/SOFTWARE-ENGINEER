# Paper Review Queue Crashed With React Error #31 — QuestionEditor Rendered AI-Extracted Marking-Point Objects Directly as JSX Children

**Date:** 2026-09-17
**Project:** HBEC
**Environment:** Production
**Severity:** High (whole-page crash on the admin paper review queue — blocks reviewing/approving any AI-extracted question with marking points)
**Status:** Resolved

## Summary
User reported a crash on the admin paper review queue:
`Error: Minified React error #31 ... object with keys {keywords, mark_type,
qualifier, depends_on, mark_value, description, point_label,
acceptable_answers}`. React error #31 means a plain JS object was rendered
directly as a JSX child. Root cause: `QuestionEditor.tsx` (opened from the
review queue to inspect/edit/approve an AI-extracted question) rendered
each of a question's marking points with `<span>{point}</span>`, assuming
every entry was a plain string. For AI-extracted questions, marking points
are actually rich per-criterion objects produced by the harness's marking
orchestrator (`_serialize_mp`) — `{point_label, mark_type, mark_value,
description, keywords, acceptable_answers, depends_on, qualifier}` — not
strings. The frontend's own `Question`/`QuestionFormData` TypeScript types
declared `markingPoints: string[]`, which was simply wrong for this data
and hid the mismatch at compile time; nothing caught it until a real
extracted question with marking points was opened for review in production.

## Symptoms
- Browser console: `Error: Minified React error #31; ... object with keys
  {keywords, mark_type, qualifier, depends_on, mark_value, description,
  point_label, acceptable_answers}`, caught by a React error boundary.
- Reported directly by the user from the actual admin paper review queue.

## Environment Details
- **Server/Host:** Production (`admin.hbca.tech`)
- **Services Affected:** `ADMIN/adminFrontend`
  (`src/features/exam-practice-admin/components/QuestionEditor.tsx`,
  `src/features/exam-practice-admin/types/index.ts`); root data produced by
  `AGENTIC_HARNESS/app/exam_practice/marking/orchestrator.py::_serialize_mp`,
  passed through unvalidated via
  `ADMIN/adminBackend/apps/exam_papers/models.py::ExamPaperQuestion.marking_points`
  (a plain `JSONField`) and its serializer (pure passthrough, no shape
  validation on read or write)
- **Time First Observed:** 2026-09-17, reported by the user directly from
  the paper review queue

## Investigation Steps

### 1. Initial Diagnosis
The error's own message named the exact object shape being rendered —
`{keywords, mark_type, qualifier, depends_on, mark_value, description,
point_label, acceptable_answers}` — which matched a marking-scheme
criterion, not any other domain object in the app. That immediately
pointed at wherever marking points are displayed for a question.

### 2. Root Cause Analysis
Found the exact render site,
`QuestionEditor.tsx` (marking-points list block):
```tsx
{formData.markingPoints.map((point, idx) => (
  <li key={idx} ...>
    <span>{point}</span>   {/* point can be an object, not just a string */}
    ...
  </li>
))}
```
`formData.markingPoints` is seeded straight from `question.markingPoints`
at mount and on question change. Traced the data's real origin:
`AGENTIC_HARNESS/app/exam_practice/marking/orchestrator.py`'s `_serialize_mp`
builds exactly this object shape per marking point for any AI-extracted
question. `ExamPaperQuestion.marking_points` is an unstructured
`JSONField(default=list)` on the admin backend, and its DRF serializer is a
pure passthrough (`serializers.JSONField(source="marking_points")`, both
read and write) — nothing anywhere in the pipeline validates or normalizes
its shape.

### 3. Key Findings
- The frontend's own `Question.markingPoints`/`QuestionFormData.markingPoints`
  types were both declared `string[]` — flatly wrong for extracted
  questions, and the reason TypeScript never flagged `<span>{point}</span>`
  as an error: the type system believed `point: string`, so nothing in the
  toolchain could have caught this short of a runtime check.
  QuestionEditor.tsx doesn't use `any`/`unknown` for this field anywhere —
  the bug was an incorrect (too-narrow) declared type, not a bypassed one.
- A sibling field, `markScheme`, already had a defensive check for exactly
  this same "AI output might be an object, not a string" shape mismatch
  (`typeof question.markScheme === 'object' ? JSON.stringify(...) : ...`) —
  confirming this class of mismatch between AI-extraction output shape and
  the admin editor's string-only assumptions had already bitten this
  component once before, just not for `markingPoints` specifically.
- Both admin-added marking points (via this editor's own free-text "Add"
  input, which only ever appends plain strings) and AI-extracted rich
  objects can coexist in the same array — a fix had to handle both, and
  had to do so without discarding or flattening the rich object's real
  structure, since that's the same data the marking engine depends on to
  actually grade student answers (method marks, keyword matching, ECF via
  `depends_on`).

## Root Cause
`markingPoints` was typed and coded as if every entry were always a plain,
admin-authored string, but the real production data source (AI extraction)
has produced rich per-criterion objects in this field all along. Nothing in
the type system, the API layer, or the component caught the mismatch before
a real extracted question with marking points was opened in the review
queue.

## Prevention / Rule
**Guardrail:** A frontend type for a field backed by an unvalidated,
passthrough backend `JSONField` must model every shape that field's real
producers can generate — not just the shape the one editor UI happens to
write. Applied here via a new `MarkingPoint` interface and widening
`markingPoints` to `Array<string | MarkingPoint>`; any code rendering such
a field must handle every declared variant explicitly (a `typeof` check
here), which the type system can now actually enforce since the type
finally matches reality.

This closes the gap because the display fix is purely presentational — the
underlying array is never rewritten or flattened just by opening the
editor, so a question can be reviewed/approved without touching its
marking points and the marking engine's real structured data (keywords,
mark_type, depends_on, etc.) survives untouched.

## Solution

### Immediate Fix
- `ADMIN/adminFrontend/src/features/exam-practice-admin/types/index.ts` —
  new `MarkingPoint` interface (mirrors `_serialize_mp`'s output shape);
  both `Question.markingPoints` and `QuestionFormData.markingPoints`
  widened from `string[]` to `Array<string | MarkingPoint>`.
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/QuestionEditor.tsx` —
  new `markingPointLabel(point)` helper renders `point` directly if it's a
  string, else `point.description || point.point_label || 'Untitled
  marking point'`; the rendered `<span>` also carries a `title` tooltip
  with the full JSON for an object point, so an admin reviewing extracted
  content can still inspect the real structured data on hover.
  `addMarkingPoint`/`removeMarkingPoint` were left untouched — they already
  work correctly regardless of an entry's shape (`splice`/spread don't
  inspect content), so the array's real per-item structure is preserved
  end-to-end unless an admin explicitly removes an entry.
- Tests: `QuestionEditor.test.tsx` (new) — renders a plain-string point, an
  AI-extracted object point (the exact regression case), an object point
  with no `description` (falls back to `point_label`), and confirms
  removing one marking point by index doesn't disturb a differently-shaped
  neighbor.

### Long-term Fix
None needed beyond the above — the fix is structural (the type now matches
reality; the renderer handles every variant the type declares).

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — none beyond the inline comments added
- [x] Code changes required — done (see Solution)

## Related Issues
- Found and fixed in the same session as
  `HBEC-2026-09-17-add-paper-form-ignored-subject-context.md` (a separate,
  unrelated UX bug reported at the same time).
- Same general shape as `markScheme`'s existing `typeof === 'object'` guard
  in the same component — that one was already defensive; this one wasn't.

## References
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/QuestionEditor.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/types/index.ts`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/QuestionEditor.test.tsx`
- `AGENTIC_HARNESS/app/exam_practice/marking/orchestrator.py::_serialize_mp`
- `ADMIN/adminBackend/apps/exam_papers/models.py::ExamPaperQuestion.marking_points`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — diagnosed, fixed, tested, and
deployed to staging and production within the hour
