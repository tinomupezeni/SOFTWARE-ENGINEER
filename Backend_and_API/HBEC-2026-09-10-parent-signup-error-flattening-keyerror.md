# Parent Signup Error Reporting Crashes Instead of Reporting the Actual Validation Error

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Development (Student Backend test suite)
**Severity:** Medium
**Status:** Investigating

## Summary
Found incidentally while verifying an unrelated `last_login` fix — running
the full `apps/accounts/tests/` suite surfaced a pre-existing failure:
`ParentSignupTests::test_parent_signup_reports_which_child_failed` crashes
with `KeyError: 0` instead of returning the validation error it's supposed
to report. Confirmed pre-existing (fails identically with today's unrelated
changes stashed out) — not something introduced this session.

## Symptoms
```
File "apps/accounts/views.py", line 187, in _flatten_signup_errors
    message = str(error_list[0])
              ~~~~~~~~~~^^^
KeyError: 0
```
So a parent signup that actually fails validation for a specific field (not
the special-cased `children` list) 500s instead of returning a 400 with the
real error message.

## Environment Details
- **Server/Host:** local dev checkout
- **Services Affected:** Student Backend (`apps/accounts/views.py`,
  `ParentSignupView`, `_flatten_signup_errors`)
- **Time First Observed:** 2026-09-10, while running the full accounts test
  suite to confirm an unrelated change didn't break anything

## Investigation Steps

### 1. Initial Diagnosis
`pytest apps/accounts/tests/ -q` shows this one test failing; isolated run
(`pytest apps/accounts/tests/test_parent_auth.py::ParentSignupTests::test_parent_signup_reports_which_child_failed`)
reproduces it standalone.

### 2. Root Cause Analysis
`_flatten_signup_errors` assumes every non-`children` field's error value is
a list (`error_list[0]`), which is true for simple field errors but not
always — DRF can return a `dict` for a field's errors (e.g. a nested
serializer error), and indexing a dict with `[0]` raises `KeyError`, not the
`IndexError` the surrounding logic seems to assume it might guard against.

## Root Cause
Type assumption bug: `_flatten_signup_errors` doesn't handle the case where
a field's `serializer.errors[field]` value is a `dict` rather than a `list`.

## Solution

### Immediate Fix
None — out of scope for the session this was found in, left for a dedicated
pass. Documented here so it isn't lost.

### Long-term Fix
`_flatten_signup_errors` needs an `isinstance(error_list, dict)` branch
(mirroring the existing `children`-specific handling already in the
function) before falling through to `error_list[0]`.

## Prevention
- [ ] Fix `_flatten_signup_errors` to handle dict-shaped field errors
- [ ] This test was apparently already failing before this session started —
      worth checking whether the accounts test suite runs in CI and, if so,
      why a failing test didn't block anything

## Related Issues
- Found while verifying `2026-09-10-student-last-login-never-recorded.md`
  (unrelated fix, same test run)

## References
- `STUDENT/hbec_backend/apps/accounts/views.py` (`_flatten_signup_errors`, `ParentSignupView`)
- `STUDENT/hbec_backend/apps/accounts/tests/test_parent_auth.py`

---

**Resolved By:** Not yet — documented, fix pending
**Time to Resolution:** N/A
