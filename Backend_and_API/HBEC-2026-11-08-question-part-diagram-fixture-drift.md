# Question-part diagram test used unsupported triangle fields

**Date:** 2026-11-08
**Project:** HBEC
**Environment:** Development test run
**Severity:** Low
**Status:** Resolved

## Summary
The new Admin question-part diagram test used `base`, `height`, and `hypotenuse` fields, while the diagram validator accepts the corresponding `_label` fields. The nominally valid example failed, obscuring whether the part-level validation worked.

## Symptoms
- `test_each_part_can_carry_a_validated_diagram` failed with `PartsError: unexpected field(s): base, height, hypotenuse`.

## Environment Details
- **Server/Host:** Local disposable PostgreSQL 15 test container
- **Services Affected:** Admin backend test suite
- **Related Components:** `apps/exam_papers/tests/test_question_parts.py`, `apps/exam_papers/diagrams.py`
- **Time First Observed:** 2026-11-08 pre-commit validation

## Investigation Steps

### 1. Initial Diagnosis
Ran the focused question-parts suite and inspected its single failing case.

### 2. Root Cause Analysis
Compared the test's triangle spec with `_triangle` and its allowed field set.

### 3. Key Findings
- Fourteen other tests passed.
- The validator explicitly requires labels such as `base_label`.

## Root Cause
The new test fixture drifted from the diagram schema.

## Prevention / Rule
**Guardrail:** Validate example diagram specs through the shared validator in the focused Admin test suite before accepting a part-level diagram change.

This makes fixture/schema drift fail at the same boundary that saves enforce.

## Solution

### Immediate Fix
Changed the fixture to `base_label`, `height_label`, and `hypotenuse_label`. The focused suite passed: 15 tests on disposable PostgreSQL 15.

### Long-term Fix
Keep the part-level diagram suite in the Admin CI gate.

## Prevention
- [x] Code changes required
- [x] Focused regression suite verified locally
- [ ] Target CI verification

## Related Issues
- Pending Admin question-part diagram change in the HBEC working tree.

## References
- HBEC `ADMIN/adminBackend/apps/exam_papers/diagrams.py` and `tests/test_question_parts.py`

---

**Resolved By:** Local test fixture fix
**Time to Resolution:** 2026-11-08
