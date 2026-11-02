# Flutter login error mapping rendered DRF's non_field_errors as a raw Dart list string

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
While writing the Phase 1 "wrong credentials" test for the new Flutter
mobile app's `AuthRepositoryImpl`, a login failure would have shown the user
`[Invalid email or password.]` (Dart's raw `List.toString()` output,
brackets included) instead of `Invalid email or password.`. Caught before
ever running against a real build — found by a test written to the
Phase 1 test gate, not by a user report.

## Symptoms
- A failed login (DRF validation error) would render the error message with
  literal `[` `]` characters around it in the login screen's snackbar.

## Environment Details
- **Server/Host:** N/A — client-side bug, development only.
- **Services Affected:** `mobile_flutter` app, login screen error display.
- **Related Components:** `AuthRepositoryImpl._mapDioError` (Dio error →
  `Failure` mapping).
- **Time First Observed:** During Phase 1 test authoring, 2026-11-02.

## Investigation Steps

### 1. Initial Diagnosis
Writing a test asserting the exact error message shown to the user for a
400 response from `POST /api/v1/accounts/login/`.

### 2. Root Cause Analysis
Checked the Django backend's `LoginSerializer.validate()`
(`backend/apps/accounts/serializers.py`): it raises
`serializers.ValidationError("Invalid email or password.")` with a plain
string. DRF's default behavior wraps a non-field `ValidationError` raised
with a bare string into `{"non_field_errors": ["Invalid email or
password."]}` — a JSON **list**, not a string.

### 3. Key Findings
- The Flutter client's error mapper read `data['non_field_errors']` and
  called `.toString()` directly on whatever it got back.
- For a `List<String>`, Dart's `.toString()` produces
  `[Invalid email or password.]` — valid Dart, wrong user-facing text.
- `data['detail']` (used for other error shapes) is a plain string and was
  unaffected; only the `non_field_errors` path had this bug.

## Root Cause
The client assumed every DRF error-detail field it might encounter was a
string, when DRF's non-field validation errors are always wrapped in a
list, even for a single message.

## Prevention / Rule
**Guardrail:** Any DRF error-response field accessed by a client must be
unwrapped by type (`is List` → take an element; otherwise `.toString()`)
rather than assumed to be a string, enforced by a dedicated helper
(`_extractDetail` in `AuthRepositoryImpl`) that every future endpoint's
error mapping should reuse or mirror, rather than each call site
re-implementing its own ad hoc `.toString()`.

This closes the gap because the root cause was exactly this — a single
untyped `.toString()` call standing in for proper response-shape handling.

## Solution

### Immediate Fix
Added `AuthRepositoryImpl._extractDetail()`: checks `data['detail']` first,
falls back to `data['non_field_errors']`, and if the resolved value is a
`List`, takes its first element before converting to a string.

### Long-term Fix
No further action needed for this endpoint. As new feature modules add
their own repositories/error mappers against the same Django backend, they
should reuse this same list-aware unwrapping pattern rather than a bare
`.toString()`.

## Prevention
- [x] Code changes required (done — see Solution)
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a (client-side, pre-release)
- [ ] Documentation to update — n/a

## Related Issues
- None.

## References
- `backend/apps/accounts/serializers.py` (`LoginSerializer.validate`)
- `mobile_flutter/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `mobile_flutter/test/features/auth/auth_repository_impl_test.dart`
- `reports/CRM-2026-11-02-flutter-mobile-rebuild-phase1-auth-and-shell.md`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Found and fixed within the same session, before merge.
