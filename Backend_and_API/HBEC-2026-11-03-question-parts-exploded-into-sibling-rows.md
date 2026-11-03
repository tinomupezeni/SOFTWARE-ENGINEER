# Structured questions' parts exploded into sibling rows instead of nesting in one question

**Date:** 2026-11-03
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
An admin (Mutsa) reported on 2026-10-29, with screenshots: "the questions are displaying in two ways" — some questions in a paper showed correctly as one card with nested parts ("Q2" with (a), (b), (b)(i), (b)(ii)), while others showed as separate independently-reviewable top-level cards ("Q1a", "Q1b") that should have been one question's two parts. Root cause: `_flatten_harness_questions()` in `apps/exam_papers/tasks.py`, used by both the PDF-extraction and AI-generation pipelines, emitted one `ExamPaperQuestion` row per tree node (every part and sub-part got its own flattened `question_number` like "1a"), rather than one row per top-level question with its parts nested in the model's own `sub_questions` JSON field. The model and review UI (`QuestionPreview.tsx`) already fully supported the correct nested shape — it was only ever produced by an admin manually re-merging a split question via PartsEditor after the fact.

## Symptoms
- The same paper showed some structured questions correctly nested (admin had manually fixed them) and others split into fake independent siblings (freshly extracted/generated, never touched).
- A split question's "parts" (e.g. "Q1a", "Q1b") could be independently approved/reviewed/deleted as if they were unrelated questions, with no way to tell from the UI that they shared one stem.

## Environment Details
- **Server/Host:** HBEC ADMIN backend
- **Services Affected:** `ADMIN/adminBackend` (`apps/exam_papers`)
- **Related Components:** `tasks.py` (`_flatten_harness_questions`, `extract_questions_via_harness`, `generate_ai_paper_via_harness`), `models.py` (`ExamPaperQuestion.sub_questions`/`shared_context`), `question_quality.py`, frontend `QuestionList.tsx`/`QuestionPreview.tsx` (unchanged — already correct)
- **Time First Observed:** 2026-10-29 (reported, with screenshots)

## Investigation Steps

### 1. Initial Diagnosis
Compared the two screenshots against the admin frontend's rendering code (`QuestionList.tsx`, `QuestionPreview.tsx`) and confirmed the frontend has exactly one rendering path — nesting vs. splitting is purely a function of what shape of data arrives from the backend, not a frontend bug.

### 2. Root Cause Analysis
```bash
grep -n "_flatten_harness_questions" apps/exam_papers/tasks.py
grep -n "sub_questions\|shared_context" apps/exam_papers/models.py
```
`ExamPaperQuestion` has `sub_questions` (JSONField, documented shape `{label, content, marks, marking_points, options, correct_answer}`) and `shared_context` specifically so a compound question's parts live in ONE row — the model's own doc comment already stated this design intent ("exploding them into sibling rows loses the stem they share"). `question_quality.question_problems()` already validated `sub_questions` (duplicate labels, marks summing correctly, per-part figure checks) — fully built and waiting for a producer that never populated it.

### 3. Key Findings
- `_flatten_harness_questions` walked the harness's tree and emitted a flat row for every "answerable" node (leaf, or a stem with its own marks), using `_part_label()` to build a fully-qualified flattened number like "1(b)(i)" — by construction, this could never populate `sub_questions`.
- The admin's manual "Add sub-part" flow (`PartsEditor.tsx` → `QuestionWriteSerializer`) was the *only* path that ever wrote `sub_questions`, so a paper looked "fixed" only where an admin had manually intervened after the fact.
- The harness's real `sub_part` field is already fully compound relative to the top-level question at any depth ("b(i)" for a grandchild under "b", not "i" relative to its immediate parent) — confirmed via the existing pinned fixture in `test_harness_response_shape.py`.

## Root Cause
The ingestion pipeline (shared by PDF extraction and AI generation) flattened a question's entire part tree into sibling database rows, never using the `sub_questions`/`shared_context` nesting the data model and review UI were already built to support.

## Prevention / Rule
**Guardrail:** Any code that creates `ExamPaperQuestion` rows from a tree-shaped source must produce at most one row per top-level question, with everything beneath it populating `sub_questions` — enforced going forward by the rewritten `test_harness_response_shape.py` fixtures, which now assert one row per top-level number and inspect `sub_questions` for part-level data instead of asserting flattened sibling `question_number`s.

This directly prevents a new ingestion path (another import format, say) from reintroducing the same flattening-into-siblings mistake, since any PR changing question creation must pass tests that explicitly check for one-row-per-question nesting.

## Solution

### Immediate Fix
N/A — no data was deleted; this was a structural/display defect in how new rows were shaped, not a loss.

### Long-term Fix
- Rewrote `_flatten_harness_questions` (`apps/exam_papers/tasks.py`): now walks from each top-level node and recursively collects every descendant into that node's own `sub_questions` list (via new helpers `_compound_part_label`, `_node_answer_fields`, `_collect_parts`), with one documented edge case (a stem independently marked on top of its own lettered parts) logged and folded rather than silently mis-totaled, to preserve the existing `question_problems` invariant that a compound row's `marks` equals the sum of its parts.
- A single un-lettered child under a stem (no `sub_part` at all) is kept as the old simple flat shape rather than wrapped in an awkward one-entry `sub_questions` list with an empty label — preserves a pre-existing, still-valid test (`test_child_listed_first_keeps_context_and_options`).
- Both `bulk_create` call sites (extraction and AI generation) now pass `sub_questions=q_data.get("sub_questions") or []` through to the new rows.
- Root-level de-duplication (`seen_roots`) restored, since the rewritten `_emit_root` no longer shares a single mutable `seen` set across every node the way the old single-`_walk` closure did.
- Rewrote the affected tests in `test_harness_response_shape.py` (6 tests updated, all now asserting one row per top-level question with `sub_questions` populated, rather than flattened sibling `question_number`s) plus the duplicate-handling test. All 48 tests in that file plus `test_seed_repairs.py` pass; full `exam_papers` suite: 446 passed, 1 pre-existing unrelated failure (a diagram-test fixture typo in someone else's in-progress, uncommitted work).

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- `ProjectFlow-2026-11-03-...` — same admin report thread also flagged a separate "Create Paper missing AI options" and "can't add part d after sub-parts" issue, not yet investigated.

## References
- `ADMIN/adminBackend/apps/exam_papers/tasks.py` (`_flatten_harness_questions`, `_collect_parts`, `_compound_part_label`)
- `ADMIN/adminBackend/apps/exam_papers/models.py` (`ExamPaperQuestion.sub_questions`)
- `ADMIN/adminBackend/apps/exam_papers/question_quality.py`
- `ADMIN/adminBackend/apps/exam_papers/tests/test_harness_response_shape.py`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/QuestionPreview.tsx` (unchanged — confirmed already correct)

---

**Resolved By:** Claude (session with Tinotenda Mupezeni)
**Time to Resolution:** Same session as investigation
