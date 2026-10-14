# AuthCubit Emits After Close When Login Completes After Signup Page Disposal

**Date:** 2026-10-14
**Project:** MARITCHO
**Environment:** Development (physical device SM S906U1, wireless debug, `flutter run -d 192.168.60.126:36943`)
**Severity:** Medium
**Status:** Investigating

## Summary
During a wireless-debug run of the mobile app on a physical Galaxy S22, navigating away from the signup page while `AuthCubit.login()` was still awaiting `AuthRepository.login()` produced an unhandled `Bad state: Cannot emit new states after calling close`, crashing the Dart compiler session (`Lost connection to device`). The cubit emits `AuthSuccess`/`AuthFailure` unconditionally after the await, with no `isClosed` guard — the standard Bloc async-gap hazard.

## Symptoms
- Red-screen / console error on device:
  `E/flutter: [ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: Bad state: Cannot emit new states after calling close`
- Stack:
  `#0 BlocBase.emit (package:bloc/src/bloc_base.dart:100:9)`
  `#1 AuthCubit.login.<anonymous closure> (package:mobile/features/accounts/presentation/cubit/auth_cubit.dart:18:29)`
  `#2 Result.fold (package:mobile/core/error/result.dart:41:21)`
  `#3 AuthCubit.login (package:mobile/features/accounts/presentation/cubit/auth_cubit.dart:16:12)`
- `flutter run` session terminated (`The Dart compiler exited unexpectedly. Lost connection to device.`); installed debug APK remained on device.

## Environment Details
- **Server/Host:** host 192.168.60.227, device 192.168.60.126:36943 (wireless ADB, paired via 33155); backend NOT running (`:8000` refused) so `login()` awaited a failing network call — widening the window for the page to be disposed first.
- **Services Affected:** `mobile/lib/features/accounts/presentation/cubit/auth_cubit.dart`
- **Related Components:** `signup_page.dart` (provides/disposes the cubit on navigation), `auth_repository.dart` (network-bound await)
- **Time First Observed:** 2026-10-14, during first wireless-debug install run.

## Investigation Steps

### 1. Initial Diagnosis
Read `auth_cubit.dart` (21 lines): `login()` emits `AuthLoading()`, awaits the repository, then calls `result.fold(onOk: emit(AuthSuccess), onError: emit(AuthFailure))` with no closed-check. Log timestamps show keyboard/show-hide churn consistent with the user submitting then navigating before the future completed.

### 2. Root Cause Analysis
`flutter_bloc`'s `emit` throws `StateError` once `close()` has run. Any `await` between `emit(AuthLoading())` and the terminal emit creates an async gap during which the providing widget (signup page) can be popped, closing the cubit. Same hazard class as the project's own AGENTS.md "Async Gap Safety" rule — but that rule only mandates `if (!mounted) return;` for `BuildContext` use, not `if (isClosed) return;` / `if (!isClosed) emit(...)` inside cubits, so this path is uncovered.

### 3. Key Findings
- Other cubits in `features/jobs` and `features/workers` share the identical post-await unconditional-`emit` shape — likely the same latent bug in 7+ cubits, not just `AuthCubit`.
- Backend being down lengthened the await and made the race easy to hit; on a fast local backend it would be rare but still real (slow network / timeout path).

## Root Cause
`AuthCubit.login()` emits after an `await` without checking `isClosed`, so a navigation-dispose racing the login future turns a normal auth result into an unhandled `StateError`.

## Prevention / Rule
**Guardrail:** every cubit method that emits after an `await` must guard with `if (isClosed) return;` before the post-await emit (or use `emit` only via an `if (!isClosed)` check) — and `flutter_lints` / code review must flag any `emit(` appearing after an `await` in a `Cubit` subclass without a preceding `isClosed` check.

This closes the gap because the crash is precisely "emit on a closed cubit after an async gap" — a syntactic check for emit-after-await-without-isClosed-guard catches the whole class, the same way the existing `!mounted` rule covers the widget side.

## Solution

### Immediate Fix
Not yet applied (run session only; no code changed). App remains installed on device; debug session detached.

```bash
# Reproduce / re-verify after fix:
# flutter run -d 192.168.60.126:36943 --dart-define API_BASE_URL=http://192.168.60.227:8000
```

### Long-term Fix
- Add `if (isClosed) return;` after the `await` in `AuthCubit.login()` and audit all other cubits (`worker_home`, `employer_home`, `post_job`, `job_detail`, `applicants`, `job_tracking`, `job_execution`, `worker_skills`, `my_work`) for the same pattern.
- Extend AGENTS.md "Async Gap Safety" bullet to cover the cubit side (`isClosed`), not just the widget side (`mounted`).
- Add a cubit test that closes the cubit mid-login-future and asserts no throw.

## Prevention
- [ ] Code changes required (isClosed guards in all cubits emitting after await)
- [ ] Documentation to update (AGENTS.md async-gap rule)
- [ ] Monitoring/alerts to add (none — dev-time crash)
- [ ] Configuration changes needed (none)

## Related Issues
- None yet in this repo for the cubit-side async gap (widget-side `mounted` rule exists in AGENTS.md).

## References
- `mobile/lib/features/accounts/presentation/cubit/auth_cubit.dart:11-20`
- `package:bloc` `BlocBase.emit` — throws `StateError` after `close()`
- AGENTS.md "Async Gap Safety" rule (widget side only)

---

**Resolved By:** (open)
**Time to Resolution:** (open)
