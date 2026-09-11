# Admin Paper Question Mapping Was Wrong on Nearly Every Field, on Both Sides

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Resolved

## Summary
Immediately after fixing the missing-function crash on admin paper save,
the very next attempt crashed one line deeper: the code that maps generated
questions into the save-pipeline's schema referenced fields that don't
exist on either side of the mapping — imported from the wrong module,
and built with field names that were never real. This had apparently never
run to completion before either.

## Symptoms
- `ImportError: cannot import name 'LLMQuestion' from 'app.exam_practice.schemas'`
  on the next retry after the previous fix.
- After correcting the import, a `pydantic.ValidationError` on the same
  mapping code — the fields being passed didn't exist on the real schema.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Agentic Harness (`app/admin/router.py`)
- **Related Components:** `app/admin/schemas.py` (`LLMQuestion`, `LLMSubPart`, `LLMMarkingPoint`)
- **Time First Observed:** 2026-09-09, immediately after the previous fix in this same debugging session

## Investigation Steps

### 1. Initial Diagnosis
`LLMQuestion`/`LLMMarkingPoint` were being imported from
`app.exam_practice.schemas`, which doesn't define them at all — they live
in `app.admin.schemas`.

### 2. Root Cause Analysis
After fixing the import, the mapping code still didn't work: it built
`LLMQuestion` with `question_text`, `question_type`, `marks`, `sub_part`,
`correct_answer`, and a flat `marking_points` list — none of which are real
`LLMQuestion` fields. The real schema is sub-parts-based
(`LLMQuestion.sub_parts: list[LLMSubPart]`), not flat, and both target
schemas are `extra="forbid"`.

### 3. Key Findings
- Every field on at least one side of this mapping was wrong — this code
  had never actually executed successfully, confirmed by nothing in the
  test suite calling it either.
- The correct real shape: a flat, sub-part-less generated question maps to
  one `LLMQuestion` wrapping exactly one `LLMSubPart` — a pattern
  `upload_pipeline.py` already handles elsewhere (`len(sub_parts) or 1`).

## Root Cause
The question-mapping code referenced a mix of nonexistent fields and a
wrong import; it had never been exercised by generation or by any test.

## Solution

### Immediate Fix
None separate from the long-term fix.

### Long-term Fix
Rewrote the mapping against both schemas' real definitions, running
`question_type`/`mark_type` through the existing `_coerce_question_type`/
`_coerce_mark_type` helpers rather than passing raw LLM output into
strict, enum-constrained fields. Pulled the whole mapping into its own
function (`_generated_questions_to_llm_questions`) with real unit test
coverage, since the inline version had zero test coverage and two
consecutive rounds of live bugs.

## Prevention
- [x] Unit tests for the mapping function itself (no DB needed), covering:
      one sub-part per flat question, MCQ options carrying through, empty
      options mapping to `None` not `[]`, unrecognised question type
      falling back instead of raising
- [ ] Consider a schema-level contract test that fails if either side of
      this mapping's field names drift again

## Related Issues
- Companion: nonexistent `_save_extracted_paper` function (immediately preceding bug)
- Companion: `process_manual_entry` `MissingGreenlet` crash (immediately following bug)

## References
- `AGENTIC_HARNESS/app/admin/router.py`
- `AGENTIC_HARNESS/tests/admin/test_router.py`
- Commit `18b33219`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
