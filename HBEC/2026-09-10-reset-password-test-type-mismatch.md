# Admin Frontend Typecheck Is Red on a Committed Commit — `resetPassword` Test Uses Fields the Type Doesn't Have

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
Found incidentally while typechecking an unrelated dashboard change:
`npm run typecheck` on Admin Frontend fails with `TS2353` in
`authApi.test.ts`, on a commit that was already merged (`3b9ecbdd`, "repair
failing auth test suite"). This contradicts the project's own CLAUDE.md rule
that Admin/Student Frontend must be at zero typecheck errors.

## Symptoms
```
src/features/auth/api/authApi.test.ts(74,7): error TS2353: Object literal
may only specify known properties, and 'password' does not exist in type
'ResetPasswordRequest'.
```

## Environment Details
- **Server/Host:** Local dev checkout
- **Services Affected:** Admin Frontend (`ADMIN/adminFrontend`)
- **Related Components:** `features/auth/api/authApi.ts`, `features/auth/types/index.ts`
- **Time First Observed:** 2026-09-10, while typechecking the new dashboard content-coverage feature

## Investigation Steps

### 1. Initial Diagnosis
`npm run typecheck` (build-mode `tsc -b`) reported one error, isolated to
`authApi.test.ts`, unrelated to any file touched this session. Confirmed via
`git status`/`git log` that the file is untouched and the error predates this
session (introduced in commit `3b9ecbdd`).

### 2. Root Cause Analysis
`ResetPasswordRequest` (`features/auth/types/index.ts`) requires
`{ uid, token, new_password }` — its own comment says the fields "match the
backend's `PasswordResetConfirmSerializer`". The test in `authApi.test.ts`
calls `resetPassword({ token, password, confirmPassword })` — none of
`password`/`confirmPassword` exist on the type, and `uid` is missing
entirely.

### 3. Key Findings
- The test was written against an older (or assumed) shape of the reset
  flow — `password`/`confirmPassword` — that the type was later changed
  away from without updating this test.
- This is a real, unrelated type error, not a false positive: the test as
  written could never have compiled correctly against the current type, so
  it was either never running through the full build-mode typecheck in CI,
  or CI was green by coincidence of test-runner config not enforcing types
  the same way `tsc -b` does.

## Root Cause
Test/type drift: `ResetPasswordRequest` changed shape after the test was
written, and nothing caught the mismatch before merge.

## Solution

### Immediate Fix
Corrected the test to construct a request matching the real
`ResetPasswordRequest` shape (`uid`, `token`, `new_password`) and to assert
against the actual request body the real implementation sends.

### Long-term Fix
None needed beyond the test fix — the production type and implementation
were already correct; only the test was stale.

## Prevention
- [x] Test corrected to match the real type
- [ ] Consider adding `typecheck` as a required, separate CI gate step (not
      just implied by `vitest`/babel transpilation) if it isn't already,
      since a test file can pass its test runner while still failing `tsc -b`

## Related Issues
- None — unrelated to the dashboard content-coverage work in progress this
  session, found only because a full project typecheck was run to verify
  that work

## References
- `ADMIN/adminFrontend/src/features/auth/api/authApi.test.ts`
- `ADMIN/adminFrontend/src/features/auth/types/index.ts`
- Commit `3b9ecbdd` (where the drift was introduced)

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
