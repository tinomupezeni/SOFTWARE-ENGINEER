# Question-repair endpoint accepted correct_answer=0 against an empty options list

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in code review of PR #149, `experimental` branch, before merge to `master`)
**Severity:** Medium
**Status:** Resolved

## Summary
The student backend's internal question-repair endpoint
(`apps/internal/views.py`, harness-to-student picture/question repair path)
validated an incoming repair item's `correct_answer` index with
`0 <= answer < max(len(options), 1)`. When `options` is an empty list,
`max(len(options), 1)` evaluates to `1`, so `correct_answer: 0` passes
validation even though there are no options for index 0 to refer to — the
exact "index resolves to nothing" class of bug this endpoint exists to
prevent. A second, related gap: `isinstance(answer, int)` also accepts
Python `bool` (a subclass of `int`), so `true`/`false` could slip through as
index 1/0.

## Symptoms
None observed live yet — currently unreachable because the only producer of
these repair payloads (`generation/store.py:question_payload()`) only sets
`correct_answer` for `question_type == "mcq"`, which the exam-grade gate
guarantees has 4 options. This is a latent gap in the endpoint's own
validation, not (yet) an active incident.

## Environment Details
- **Server/Host:** Student Backend (`STUDENT/hbec_backend`)
- **Services Affected:** `apps/internal/views.py` — the HMAC-authenticated
  internal endpoint the harness calls to push picture/question repairs.
- **Related Components:** Harness `picture_repair.py` and
  `generation/pictures.py`'s `check_picture`, the only current callers.
- **Time First Observed:** Found during code review, not yet reported live.

## Investigation Steps

### 1. Initial Diagnosis
Code review of PR #149 traced the validation guard around
`PaperQuestion.objects.filter(...).update(correct_answer=answer, ...)` and
found the bound used `max(len(options), 1)` instead of `len(options)`.

### 2. Root Cause Analysis
```python
or not (
    answer is None
    or (isinstance(answer, int) and 0 <= answer < max(len(options), 1))
)
```
`max(len(options), 1)` was presumably written to avoid a `range(0, 0)` always
failing — but that is exactly the correct behavior for an empty-options item:
no index should ever be considered valid against zero options. The `max()`
call defeats its own purpose by substituting `1` as the bound whenever
`options` is empty, which makes `answer == 0` pass.

### 3. Key Findings
- Every other type-mismatch path in this same validation block (non-string
  content, non-list options, non-string option items) is correctly rejected;
  this was the one case where an edge value slipped through the bound
  arithmetic instead of being rejected.
- `isinstance(answer, int)` matching `bool` is a second, related latent gap
  in the same guard.

## Root Cause
A defensive `max(x, 1)` guard, intended to avoid some other failure mode, was
applied to a bound check where the correct behavior for the degenerate input
(`len(options) == 0`) is to reject every index, not to substitute a
placeholder bound of 1.

## Prevention / Rule
**Guardrail:** Any bounds check of the form `0 <= i < N` where `N` can be
legitimately zero must treat `N == 0` as "reject every index," never paper
over it with `max(N, 1)`. Add a unit/integration test for this endpoint that
posts a repair item with `options: [], correct_answer: 0` and asserts it is
rejected (silently skipped, per this endpoint's existing behavior for
malformed items), to catch a regression here even though the current call
path can't yet produce this input.

This closes the gap because the root cause was specifically substituting a
placeholder bound for a legitimately-empty collection, rather than treating
emptiness as "no valid index."

## Solution

### Immediate Fix
```python
or not (
    answer is None
    or (
        isinstance(answer, int)
        and not isinstance(answer, bool)
        and options
        and 0 <= answer < len(options)
    )
)
```
Also explicitly excludes `bool` (a subclass of `int`) from being accepted as
a valid index.

### Long-term Fix
Add the regression test described above.

## Prevention
- [x] Code changes required (done — see Solution)
- [ ] Add the regression test named above
- [ ] Documentation to update
- [ ] Monitoring/alerts to add

## Related Issues
- Found alongside two other PR #149 review findings: a picture-swap
  deduplication bug in `AGENTIC_HARNESS/app/exam_practice/services/generation/pictures.py`,
  and a parental-gate route misconfiguration in
  `STUDENT/Frontend/src/App.tsx`.

## References
- `STUDENT/hbec_backend/apps/internal/views.py`
- HBEC `experimental` branch, commit `5532043e3`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session (pre-merge)
