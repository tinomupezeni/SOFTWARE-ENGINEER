# Parent Signup 500s Whenever a Non-First Child Fails Per-Field Validation

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Development (found running the existing test suite; not
specifically verified against staging/production, but the code path is
identical there)
**Severity:** Medium (parent signup is a real, user-facing account-creation
flow; this turns a normal validation error into a 500 for the parent)
**Status:** Found, not fixed — discovered incidentally while verifying an
unrelated internal-endpoint change to the student backend
(`apps/internal/`); explicitly out of scope for that task, so left for a
dedicated fix.

## Summary
Found by running the pre-existing test suite (`apps/accounts/tests/`) as
part of the documented pre-merge check for an unrelated feature. One test,
`ParentSignupTests::test_parent_signup_reports_which_child_failed`, already
existed and already failed before any of this session's changes —
`POST /api/auth/signup/parent/` throws an unhandled `KeyError` (500) instead
of returning the expected 400 whenever a child *other than index 0* fails a
per-field validation (e.g. an invalid `dateOfBirth`) while an earlier child
is valid.

## Symptoms
- `KeyError: 0` inside `_flatten_signup_errors` (`apps/accounts/views.py`),
  surfaced as an uncaught `django.core.exceptions` → 500 response instead
  of the intended `{"success": false, "message": ..., "errors": ...}` 400.
- Only reproduces when the *first* child in the payload is valid and a
  *later* child fails a field-level check inside `ChildInputSerializer`
  (e.g. `validate_dateOfBirth`'s "Child must be at least 3 years old"). A
  failure on child index 0 does not crash, which is presumably why this has
  gone unnoticed — signup UIs commonly validate/fill the first child first.

## Environment Details
- **Server/Host:** `STUDENT/hbec_backend`
- **Services Affected:** `apps/accounts/views.py` — `_flatten_signup_errors`
  (used by `ParentSignupView.post`)
- **Related Components:** `apps/accounts/serializers.py` —
  `ParentSignupSerializer.children` (`ChildInputSerializer(many=True, ...)`)
- **Time First Observed:** 2026-09-14, running
  `pytest apps/internal apps/accounts` as the documented verification step
  for an unrelated student-backend endpoint change.

## Investigation Steps

### 1. Initial Diagnosis
`pytest apps/accounts -q` (Postgres via `POSTGRES_HOST=127.0.0.1`, per this
repo's own documented test setup) reported one pre-existing failure,
unrelated to any file touched this session:
```
FAILED apps/accounts/tests/test_parent_auth.py::ParentSignupTests::test_parent_signup_reports_which_child_failed
apps/accounts/views.py:188: in _flatten_signup_errors
    message = str(error_list[0])
KeyError: 0
```

### 2. Root Cause Analysis
`_flatten_signup_errors` (`apps/accounts/views.py`) special-cases the
`children` field, expecting `errors["children"]` to be a **list** — one
entry per child, with an empty dict for a valid child — and only takes the
per-child branch `if field == "children" and isinstance(error_list, list)`.
Reproduced directly against the installed DRF version:
```python
s = ParentSignupSerializer(data={
    "name": "Parent User", "email": "childerror@test.com",
    "password": "SecurePass123!",
    "children": [
        {"firstName": "Valid Child", "dateOfBirth": "2015-03-15"},
        {"firstName": "Too Young", "dateOfBirth": "2025-01-01"},
    ],
})
s.is_valid()
s.errors["children"]
# => {1: {'dateOfBirth': [ErrorDetail(string='Child must be at least 3 years old', ...)]}}
```
`errors["children"]` is a **dict keyed by the failing child's index**, not
a list — DRF's `ListSerializer.to_internal_value` only includes indices
that actually errored, as a dict, rather than a full-length list padded
with `{}` for valid entries. `isinstance(error_list, list)` is therefore
`False`, so execution falls into the generic `else` branch,
`message = str(error_list[0])` — which does `dict[0]`, and raises
`KeyError` whenever the failing child's index isn't literally `0`.

### 3. Key Findings
- The bug is specifically an index mismatch: `error_list[0]` assumes
  "first item in a list", but the real value is "a dict keyed by original
  index," so it only works by coincidence when child index 0 is the one
  that fails.
- The distinction between this per-field case and the sibling-duplicate
  case (`validate_children()` raising a single flat `ValidationError`,
  which *is* a list) is the reason the existing
  `test_parent_signup_rejects_duplicate_child_names`-style test passes
  while this one doesn't — they exercise two different DRF error shapes
  that the same code treats identically.

## Root Cause
`_flatten_signup_errors` assumes a specific (list) shape for
`errors["children"]` that only holds for one of the two ways a
`ParentSignupSerializer` can report a child error (a serializer-level
`validate_children()` failure); the far more common case — a per-child
field failing inside `ChildInputSerializer` — produces a dict keyed by
index instead, which the code doesn't handle, causing an unguarded
`dict[0]` lookup to crash with `KeyError` unless the failing index happens
to be exactly `0`.

## Prevention / Rule
**Guardrail:** none applied — not fixed in this session, since it was
found while verifying unrelated work in a different Django app
(`apps/internal/`) and the instruction for that task was explicitly to
report, not fix, any unrelated pre-existing issue.

For whoever picks this up: the fix should branch on
`isinstance(error_list, dict)` as well as `list` for the `children` field
(covering both "dict keyed by index" and "list padded with `{}`" DRF error
shapes), plus a regression test with the failing child at index 0 *and* at
a later index, so a future DRF version change can't silently flip which
shape is used without a test catching it.

## Solution

### Immediate Fix
None — left unfixed per this session's task scope. The test that already
exercises this
(`apps/accounts/tests/test_parent_auth.py::ParentSignupTests::test_parent_signup_reports_which_child_failed`)
is a pre-existing, currently-failing test in the repo (not written this
session) and continues to fail; it was not modified.

### Long-term Fix
Rewrite the `children` branch of `_flatten_signup_errors` to iterate
`error_list.items()` when it's a dict (using the real index as the label,
e.g. `f"Child {index + 1}: ..."`) and fall back to enumerating when it's a
list, so both DRF error shapes for a nested `many=True` child serializer
are handled without relying on which one happens to be current.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — an error-rate alert on
      `POST /api/auth/signup/parent/` 500s would catch this in production
      traffic even without the test
- [ ] Documentation to update — none
- [ ] Code changes required — yes, see Long-term Fix; not done here

## Related Issues
None known.

## References
- `STUDENT/hbec_backend/apps/accounts/views.py` — `_flatten_signup_errors`,
  `ParentSignupView.post`
- `STUDENT/hbec_backend/apps/accounts/serializers.py` —
  `ParentSignupSerializer`, `ChildInputSerializer`
- `STUDENT/hbec_backend/apps/accounts/tests/test_parent_auth.py` —
  `ParentSignupTests::test_parent_signup_reports_which_child_failed`
  (pre-existing test that already encodes the expected fix)

---

**Resolved By:** Not resolved — reported by Claude Sonnet 5
**Time to Resolution:** N/A (out of scope; found during verification of an
unrelated change)
