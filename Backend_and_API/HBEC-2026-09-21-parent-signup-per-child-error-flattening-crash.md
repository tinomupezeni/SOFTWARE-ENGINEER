# Parent Signup 500s When a Non-First Child Fails Field Validation

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Development (found via local test run; not yet confirmed against production traffic)
**Severity:** Medium (turns a normal 400 validation response into an unhandled 500 on signup)
**Status:** Resolved (2026-09-21, same day — fixed on request shortly after being flagged)

## Summary
Found while writing and regression-testing the family-plan resize change in
`STUDENT/hbec_backend/apps/accounts/parent_views.py`
(`STUDENT-2026-09-xx`-series family-plan work). Running the existing
`apps.accounts.tests.test_parent_auth` suite surfaced a pre-existing, unrelated
failure: `test_parent_signup_reports_which_child_failed` crashes with
`KeyError: 0` instead of returning the expected 400. Confirmed via `git stash`
(reverting only my change) that the failure is identical with and without my
edit — this bug predates this session's work and is not something I
introduced.

## Symptoms
- `POST /api/auth/signup/parent/` with two children, where only the
  **second** child fails a field-level validator (e.g. `dateOfBirth` implying
  under 3 years old), returns an unhandled server error instead of
  `400 {"success": false, "message": "..."}`.
- Traceback: `apps/accounts/views.py:188` in `_flatten_signup_errors`,
  `message = str(error_list[0])` → `KeyError: 0`.

## Environment Details
- **Server/Host:** local dev, throwaway Postgres/Redis containers spun up
  for this test run (no persistent env affected)
- **Services Affected:** Student Backend (`apps/accounts`)
- **Related Components:** `ParentSignupSerializer` (`apps/accounts/serializers.py`),
  `ParentSignupView.post` + `_flatten_signup_errors`
  (`apps/accounts/views.py`)
- **Time First Observed:** 2026-09-21, while regression-testing an unrelated
  change to the same test file's suite

## Investigation Steps

### 1. Initial Diagnosis
Ran `apps.accounts.tests.test_parent_auth` after editing
`parent_views.py`. 25/26 passed; `test_parent_signup_reports_which_child_failed`
errored with `KeyError: 0` inside `_flatten_signup_errors`, a function my
change never touches.

### 2. Root Cause Analysis
Reverted my change via `git stash` and re-ran just that one test — identical
`KeyError: 0`, confirming it's pre-existing. Reproduced directly against the
serializer in a Django shell to see the actual error shape DRF returns:

```python
from apps.accounts.serializers import ParentSignupSerializer
data = {
    "name": "Parent User", "email": "x@test.com", "password": "SecurePass123!",
    "children": [
        {"firstName": "Valid Child", "dateOfBirth": "2015-03-15"},
        {"firstName": "Too Young", "dateOfBirth": "2025-01-01"},
    ],
}
s = ParentSignupSerializer(data=data)
s.is_valid()
print(s.errors)
# {'children': {1: {'dateOfBirth': [ErrorDetail('Child must be at least 3 years old')]}}}
```

### 3. Key Findings
- `children = ChildInputSerializer(many=True, ...)` on `ParentSignupSerializer`
  is a DRF `ListSerializer`. When only *some* items in the list fail
  validation, DRF's `ListSerializer.run_validation` raises `ValidationError`
  keyed by **item index as a dict** (`{1: {...}}`), not a positional list —
  contrary to what `_flatten_signup_errors`'s `"children"` branch assumes
  (`isinstance(error_list, list)`, then `enumerate(error_list)`).
- Because the dict guard (`isinstance(error_list, list)`) fails for this
  shape, the code falls through to the generic `else` branch at line 188,
  which does `error_list[0]` — a `KeyError` on a dict whose only key is `1`
  (or whatever index actually failed).
- The bug only reproduces when the **first** child is valid and a **later**
  child fails a field-level validator — that's exactly the case DRF encodes
  as a sparse `{index: errors}` dict rather than a list. A first-child
  failure, or a serializer-level `validate_children()` failure (duplicate
  names), both happen to still be lists and are unaffected — which is why
  `test_parent_signup_duplicate_child_names_fails` passes while this one
  doesn't.

## Root Cause
`_flatten_signup_errors` (`apps/accounts/views.py`) assumes DRF always
reports per-item errors for a `many=True` nested serializer field as a
`list` aligned to item position. DRF actually reports them as a `dict` keyed
by the failing index once any item is *valid* (a full list only appears when
every index up to the last failure has an entry). The `"children"` branch's
`isinstance(error_list, list)` guard silently rejects the dict shape instead
of handling it, and the fallback `else` branch is not a safe default for a
field whose known possible shapes were only partially handled.

## Prevention / Rule
**Guardrail:** `_flatten_signup_errors`'s `"children"` branch now accepts
both `list` and `dict` (iterating `.items()` for the dict case instead of
`enumerate()`), so both shapes DRF can emit for a `many=True` field are
handled the same way rather than one of them falling through to an unsafe
default. `test_parent_signup_reports_which_child_failed` — already present
and already correctly written, previously failing — is the permanent
regression guard; no new test was needed.

## Solution

### Immediate Fix
Applied 2026-09-21 (same day, on request): widened the `isinstance` guard to
`(list, dict)`, built the iterator as `enumerate(error_list)` or
`error_list.items()` depending on which shape arrived, and cast the dict
case's key to `int()` before using it in the `Child {index + 1}: ...`
message (dict keys from DRF here are already `int`, but the list branch's
`enumerate()` also yields `int`, so this keeps the message-formatting code
identical regardless of which shape produced it). Full
`apps.accounts.tests.test_parent_auth` suite: 26/26 passing, including the
previously-failing test.

### Long-term Fix
None needed beyond the above — this is the complete fix.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — consider alerting on 500s from
      `/api/auth/signup/parent/` specifically, since this turns a routine
      validation failure into a server error a real parent could hit
- [ ] Documentation to update — n/a
- [x] Code changes required — done (see Solution)

## Related Issues
- None found in this repo for DRF `ListSerializer` error-shape assumptions.

## References
- `STUDENT/hbec_backend/apps/accounts/views.py` (`_flatten_signup_errors`,
  `ParentSignupView.post`)
- `STUDENT/hbec_backend/apps/accounts/serializers.py`
  (`ParentSignupSerializer.children`, `ChildInputSerializer`)
- `STUDENT/hbec_backend/apps/accounts/tests/test_parent_auth.py::ParentSignupTests::test_parent_signup_reports_which_child_failed`
  (already exists, already correctly written, currently failing — this is
  the regression guard for the fix once applied)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same day, 2026-09-21
