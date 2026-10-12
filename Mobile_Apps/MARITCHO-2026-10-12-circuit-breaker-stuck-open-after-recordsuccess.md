# Client Circuit Breaker Could Stay "Open" After a Recorded Success, Because Only the Failure Counter Was Reset

**Date:** 2026-10-12
**Project:** MARITCHO
**Environment:** Development (caught by a unit test before merge — never reached a build)
**Severity:** Low (would have only mattered on the narrow path where a success is recorded while the breaker is already open — not reachable via the actual request flow, but a real latent defect in the public API)
**Status:** Resolved

## Summary
While adding a `ClientCircuitBreaker` to the mobile app's shared Dio client (per the Mobile App Agent-First Development Guide's Stability Engineering section), the first unit test written for it caught a real bug in the implementation: `recordSuccess()` only reset the internal failure counter, not the `_cooldownExpiration` timestamp that `isOpen` actually checks first — so a breaker that had already tripped open would stay reporting `isOpen == true` even after a success was recorded, until the original cooldown window separately expired on its own.

## Symptoms
- Unit test `given an open breaker, when a success is recorded, then closes and resets the failure count` failed: `Expected: false, Actual: <true>`.

## Environment Details
- **Server/Host:** local dev (`flutter test`)
- **Services Affected:** `mobile/lib/core/network/api_client.dart` — `ClientCircuitBreaker`, consumed by `CircuitBreakerInterceptor` in the shared Dio client every repository uses
- **Related Components:** none yet in production — this was caught before the code was ever wired into a running app build
- **Time First Observed:** 2026-10-12, first test run immediately after writing the class

## Investigation Steps

### 1. Initial Diagnosis
The guide's own worked example for `ClientCircuitBreaker` (Stability Engineering section) has the identical shape: `isOpen` checks `_cooldownExpiration` first and only clears it when the cooldown has naturally elapsed; the only place `_failures` is reset to 0 is inside its `execute()` wrapper's success branch, which does not clear `_cooldownExpiration` either. This project's adaptation split `execute()` into two explicit methods (`recordSuccess()`/`recordFailure()`, called from `CircuitBreakerInterceptor.onResponse`/`onError` instead of wrapping the call directly) — but copied the same reset-only-the-counter behavior from the original.

### 2. Root Cause Analysis
`isOpen`'s short-circuit is `if (_cooldownExpiration == null) return false;` — so as long as any non-null cooldown timestamp is set, the method falls through to the "has it elapsed yet" check and ignores the failure counter entirely. Resetting `_failures` without also clearing `_cooldownExpiration` doesn't change what `isOpen` reports.

### 3. Key Findings
- Not reachable via this project's actual request flow today: `CircuitBreakerInterceptor.onRequest` rejects a request immediately (before dispatch) whenever `isOpen` is true, so `onResponse` — the only caller of `recordSuccess()` — can never fire while the breaker is open. The bug is real but currently dormant.
- It would become reachable the moment any future code calls `recordSuccess()` directly (e.g. a manual "retry now" action, or a health-check ping bypassing the interceptor) — worth fixing now rather than leaving a public method with surprising semantics.

## Root Cause
`recordSuccess()` cleared `_failures` but not `_cooldownExpiration`, while `isOpen` is gated on `_cooldownExpiration` being non-null, not on the failure count — so the two methods were reasoning about different pieces of state.

## Prevention / Rule
**Guardrail:** any class exposing both a "report success" and an "is currently degraded" API must have a unit test asserting that a recorded success actually flips the degraded flag back to false — not just that the failure counter goes to zero. This project's new `test/core/network/client_circuit_breaker_test.dart` is exactly that test, and it's what caught this before any code path depended on the broken behavior.

This closes the gap because the bug is a classic "two pieces of state, only one api updates both" defect — a test that checks the *public* predicate (`isOpen`) after the *public* mutator (`recordSuccess()`) catches it regardless of which internal field was the one left stale.

## Solution

### Immediate Fix
`recordSuccess()` now clears both fields:
```dart
void recordSuccess() {
  _failures = 0;
  _cooldownExpiration = null;
}
```

### Long-term Fix
None needed beyond the fix above — this is a two-line change with a passing regression test, not a design that needs revisiting.

## Prevention
- [ ] Configuration changes needed (n/a)
- [ ] Monitoring/alerts to add (n/a — client-side unit-testable logic)
- [ ] Documentation to update (n/a)
- [x] Code changes required (done — `recordSuccess()` fixed, test added)

## Related Issues
- Found while implementing the "network resilience" follow-up from the Mobile App Agent-First Development Guide compliance audit (`reports/MARITCHO-2026-10-12-mobile-app-guide-compliance-audit.md`).

## References
- `Principal_Engineer/engineering-guides/3. Mobile App Agent-First Development Guide.md` (Stability Engineering §, `ClientCircuitBreaker` worked example)
- `mobile/lib/core/network/api_client.dart`
- `mobile/test/core/network/client_circuit_breaker_test.dart`

---

**Resolved By:** Claude Code (mobile guide-compliance follow-up session)
**Time to Resolution:** ~5 minutes (caught by the first test run, fixed immediately)
