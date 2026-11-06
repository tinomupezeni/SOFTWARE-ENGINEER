# Mobile Auth, Assignments, Classes, and Navigation Shell

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** Feature slice / Mobile parity
**Status:** Completed

## Summary
Extended the Flutter client with registration, forced password change,
assignment browsing, teacher class creation/listing, and a role-aware mobile
navigation drawer. The implementation uses the existing Django REST contracts
without changing the shared backend.

## Context / Trigger
The mobile migration had completed login, Home, Subjects, and Lab Detail, but
the remaining core learner and teacher entry points were unavailable.

## Scope
Included mobile auth completion flows, assignment list views, teacher class
listing/creation, drawer navigation, route wiring, and model contract coverage.
Excluded assignment creation/results, class detail/student management,
LabPlayer, and real-device screenshot parity because those require separate
feature work and device validation.

## Method
Inspected the web routes and API boundary, reused the documented REST
contracts, added Flutter API/controller methods, then connected screens through
the existing Riverpod and GoRouter foundations. Validation was performed with
formatting, static analysis, unit/widget tests, web compilation, and diff
checks.

## Decisions & Findings
- The Django backend remains authoritative; no backend routes, serializers,
  database schema, or marking logic were changed.
- Refresh-cookie and in-memory access-token behavior remains centralized in the
  existing API client.
- The drawer exposes Home, Assignments, Classes, Browse Labs, and password
  change destinations while preserving role-aware behavior.
- `must_change_password` is handled before normal signed-in navigation.
- The implemented slice is functional parity, not yet proof of pixel parity on
  Android/iOS devices.

## Changes Made
- Added registration, invite preview, password change, classroom create/join,
  and assignment API methods.
- Added student/teacher registration and forced-password screens.
- Added student and teacher assignment list screens.
- Added teacher class list and create-class flow.
- Added shared mobile drawer/app-bar shell and routes.
- Added auth contract coverage for role and temporary-password fields.
- Updated the mobile README, screen inventory, and session log.

## Verification
- `cd mobile_flutter && dart format lib test`
- `cd mobile_flutter && flutter analyze`
- `cd mobile_flutter && flutter test`
- `cd mobile_flutter && flutter build web`
- `git diff --check`

All commands passed.

## Follow-ups / Deferred
Implement teacher assignment creation/results, class detail and student
management, password checklist and throttle visual parity, LabPlayer, and
Android/iOS real-device journey plus same-viewport screenshot comparison.

## References
- `mobile_flutter/lib/core/auth/api_client.dart`
- `mobile_flutter/lib/features/auth/auth_completion_screens.dart`
- `mobile_flutter/lib/features/assignments/assignments_screen.dart`
- `mobile_flutter/lib/features/classrooms/classes_screen.dart`
- `mobile_flutter/lib/features/shell/app_shell.dart`
- `intelligent_memory_management/contracts/api.md`
- `intelligent_memory_management/sessions/2026-11-06_session-06.md`

---

**Completed By:** Copilot
**Duration:** One implementation session
