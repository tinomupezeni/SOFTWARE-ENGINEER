# Picture-swap MCQ-key safety check was asymmetric (pre-swap only)

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in /code-review of PR #157, before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`_swap_question` (the stored-picture repair path) only refused an MCQ
picture swap when the *pre*-swap answer key was resolvable and the swap would
break it. When the key was already unresolvable before the swap, the
function applied the swap unconditionally with no check on what the key
resolves to *afterward* — contradicting its own module docstring's claim
that "An MCQ whose key no longer names an option after the swap is not
changed."

## Symptoms
Not yet observed in production — caught in code review before merge. Would
have surfaced as a repaired AI paper question marked "repaired" and pushed to
the student backend with an answer key that resolves to nothing or to the
wrong option, with no record that the swap was ever unverified.

## Environment Details
- **Server/Host:** AGENTIC_HARNESS (exam practice, stored-picture repair)
- **Services Affected:**
  `app/exam_practice/services/picture_repair.py` (`_swap_question`)
- **Related Components:** `app/exam_practice/marking/mcq.py`
  (`correct_index`), `app/exam_practice/services/generation/pictures.py`
  (the generation-time version of this same safety check)
- **Time First Observed:** N/A — code review

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` on PR #157 traced the guard:
```python
if before is not None and after != before:
    return False
```
and noted it is a no-op whenever `before is None` — exactly the case of an
already-broken key, which is the case most in need of a check, not least.

### 2. Root Cause Analysis
The check was written to catch *regression* (a working key breaking), not to
independently verify the *post-swap* state. The two are different claims;
the docstring promises the latter, the code only did the former.

### 3. Key Findings
- `correct_index` can return `None` for a key that already names no option
  (e.g. options literally `["A","B","C","D"]` with no scheme-level match).
- There is a second, independently-written copy of this same invariant in
  `generation/pictures.py`'s `judge_picture`/swap path, which relies on the
  later `exam_grade()` gate rather than an explicit before/after comparison
  — flagged separately (see Related Issues) as worth consolidating, since the
  two paths enforcing one invariant two different ways is itself a risk.

## Root Cause
The guard compared `after != before` but never checked `after is None` on
its own — so an unresolvable key, before or after, was never itself a reason
to refuse.

## Prevention / Rule
**Guardrail:** A property-based or table-driven test for `_swap_question`
covering all four combinations of {key resolvable, key unresolvable} ×
{before swap, after swap} — in particular "unresolvable before, unresolvable
after" and "unresolvable before, resolvable after" — asserting the function's
behavior against the docstring's literal claim in each case.

This closes the gap because the bug was exactly an under-tested combination
(pre-swap already broken) that a symmetric before/after comparison, once
written, makes impossible to miss.

## Solution

### Immediate Fix
```python
if question.question_type.value == "mcq":
    before = correct_index(question.options or [], list(question.marking_points))
    after = correct_index(
        options,
        [{"description": d, "acceptable_answers": a} for d, a in points],
    )
    # The key must still name an option after the swap, whether or not it
    # did before: an already-unresolvable key is not licence to apply an
    # unverified one (the docstring's actual claim, both ways).
    if after is None or (before is not None and after != before):
        return False
```

### Long-term Fix
Consolidate this check with the generation-time equivalent in
`generation/pictures.py` so the invariant is enforced in one place instead of
two independently-written ones.

## Prevention
- [x] Code changes required (done)
- [ ] Consolidate the two MCQ-key-safety implementations (generation-time vs.
  repair-time) — tracked as a separate architectural follow-up, not fixed in
  this pass.

## Related Issues
- `HBEC-2026-11-18-whiteboard-tickitem-dangling-reference.md`,
  `HBEC-2026-11-18-whiteboard-check-why-text-unaudited.md` — found in the
  same review pass.
- The duplicate-implementation concern was also flagged in PR #149's review
  and left as an architectural PR comment there.

## References
- `AGENTIC_HARNESS/app/exam_practice/services/picture_repair.py`
- `AGENTIC_HARNESS/app/exam_practice/services/generation/pictures.py`

---

**Resolved By:** Claude Sonnet 5 (fork agent)
**Time to Resolution:** Same session as discovery
