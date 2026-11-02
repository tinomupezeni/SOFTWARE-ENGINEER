# Flutter Mobile Rebuild — Phase 1 Auth & App Shell

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Module Scaffolding
**Status:** Completed

## Summary
Completed Phase 1 of the Flutter mobile rebuild: hardened the auth flow's
network-layer test coverage (expired token, wrong credentials, offline
attempt — the exact edge cases named in the agreed Phase 1 test gate) and
built the authenticated app shell (bottom-navigation tabs for Home, Stock,
Sales, More) that the rest of the feature phases will be built into.

## Context / Trigger
Direct continuation of Phase 0
(`CRM-2026-11-02-flutter-mobile-rebuild-phase0-foundation.md`), per the
7-phase plan agreed with the user. The user said "proceed to phase 1."

## Scope
Included: interceptor/repository test coverage for the three auth edge cases
the plan's test gate named, a bug fix to error-message extraction found
while writing those tests, and the bottom-nav app shell with real routes for
Home/More and honest placeholders for Stock/Sales (not yet built).

Excluded: the actual Stock and Sales/POS feature modules (Phases 2–3), a
real dashboard on Home (Phase 5 — needs data from modules that don't exist
yet), and any on-device manual test (still blocked — see Follow-ups).

## Method
Added `http_mock_adapter` to mock Dio at the HTTP-adapter level (distinct
from `mocktail`, which mocks Dart objects) so the `AuthInterceptor`'s actual
request/response logic could be exercised end-to-end rather than only
unit-tested in isolation. Verified each test actually fails before the
corresponding fix/feature existed, to avoid tests that pass vacuously.

## Decisions & Findings
- **Bug found while writing the "wrong creds" test**: `AuthRepositoryImpl`
  unwrapped DRF's `non_field_errors` (a JSON list) with a raw `.toString()`,
  producing a message like `[Invalid email or password.]` instead of
  `Invalid email or password.`. Fixed by extracting the first list element.
  Logged separately per the bug-log rule — see References.
- **Interceptor test strategy**: `http_mock_adapter`'s matcher always
  resolves to the *last* registered handler matching a given route (it does
  not support stateful "first call X, second call Y" sequencing). Worked
  around this by matching on the `Authorization` header value itself (which
  differs between the pre-refresh and post-refresh request), rather than
  trying to sequence responses on an identical request signature.
- **Bottom nav satisfies thumb-zone placement for free**: per the HCI
  guide's Section 19, a standard Material bottom `NavigationBar` already
  sits in the bottom third of the viewport, so tab-switching needs no
  additional placement logic — only each tab's own primary action (e.g. a
  future "new sale" button) needs to independently honor that rule.
- **Logout moved out of the Home app bar into its own "More" tab**, behind a
  confirmation dialog — per HCI guide Section 17 (isolate destructive/rare
  actions from frequently-tapped surfaces).
- **Stock and Sales tabs are honest placeholders** ("Coming in Phase 2/3"),
  not screens built against fabricated sample data.

## Changes Made
- `lib/features/auth/data/repositories/auth_repository_impl.dart` — fixed
  `non_field_errors` list unwrapping (`_extractDetail`).
- `lib/core/shell/app_shell.dart` — new `NavigationBar`-based shell.
- `lib/core/widgets/coming_soon_screen.dart` — reusable honest placeholder.
- `lib/features/stock/presentation/screens/stock_placeholder_screen.dart`,
  `lib/features/pos/presentation/screens/pos_placeholder_screen.dart` — new.
- `lib/features/more/presentation/screens/more_screen.dart` — new (org info
  + confirmed logout).
- `lib/features/home/presentation/screens/home_screen.dart` — simplified
  (logout moved to More).
- `lib/core/routing/app_router.dart` — rebuilt on
  `StatefulShellRoute.indexedStack` with four branches.
- `pubspec.yaml` — added `http_mock_adapter` (dev dependency).
- Tests: `test/features/auth/auth_repository_impl_test.dart` (wrong creds,
  offline attempt, successful token persistence),
  `test/core/network/auth_interceptor_test.dart` (expired-token refresh +
  retry, rejected-refresh session expiry, missing-refresh-token session
  expiry), `test/core/shell/app_shell_navigation_test.dart` (tab switching,
  logout confirmation flow).

## Verification
- `flutter analyze` — 0 errors/warnings (same 7 pre-existing `info`-level
  style notes as Phase 0).
- `flutter test` — 18/18 passing.
- Not yet done: real device/emulator run — still no Android emulator/iOS
  simulator available in this environment (carried over from Phase 0).

## Follow-ups / Deferred
- Real on-device verification of the auth flow and tab navigation, once an
  emulator/device is available.
- Phase 2 (Stock & Products) is next per the agreed plan.

## References
- `CRM-2026-11-02-flutter-mobile-rebuild-phase0-foundation.md`
- `Backend_and_API/CRM-2026-11-02-non-field-errors-list-rendered-as-raw-list-string.md`
  (the bug-log entry for the `non_field_errors` fix)
- `/home/shadowe/Projects/crm/mobile_flutter/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
