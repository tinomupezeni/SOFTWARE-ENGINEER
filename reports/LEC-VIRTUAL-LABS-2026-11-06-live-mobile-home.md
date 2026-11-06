# Live mobile Home data slice

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** Mobile feature implementation
**Status:** Completed

## Summary
The Flutter app's Home screen now consumes the Django API for subjects,
assignments, classrooms, and student attempts, replacing placeholder content
with role-aware learner and teacher states.

## Context / Trigger
The initial Flutter vertical slice had authentication and a static Home shell.
The next user-flow milestone was to make Home reflect the existing web
dashboard data while preserving the backend as the source of truth.

## Scope
Included authenticated list requests, one-shot access-token refresh on expired
requests, response models, Riverpod Home state, loading/error/empty states, and
student/teacher cards. Lab detail, registration, forced password change,
navigation, and simulation playback were explicitly excluded.

## Method
Compared the mobile client calls with the REST contract, Django URL routes, and
serializers; implemented the smallest feature-first data layer; then ran the
Flutter analyzer and tests plus parser contract tests.

## Decisions & Findings
- The mobile client uses `/subjects/`, `/assignments/`, `/classrooms/`, and
  `/attempts/mine/` exactly as defined by the backend.
- Access tokens remain in memory; a failed authenticated request gets one
  refresh-and-retry attempt using the secure refresh cookie.
- Student and teacher Home data intentionally share the API boundary but render
  different cards and empty-state copy.

## Changes Made
- Added `core/labs/models.dart` for backend summary payloads.
- Added `features/home/home_controller.dart`.
- Extended `core/auth/api_client.dart` with authenticated Home data methods.
- Replaced the Home placeholder UI in `lib/main.dart`.
- Added `test/home_models_test.dart`.
- Updated the screen inventory, mobile README, and session log.

## Verification
- `cd mobile_flutter && flutter analyze`
- `cd mobile_flutter && flutter test`
- Result: analysis clean; all widget and model contract tests passed.
- Backend routes and serializers were inspected for bidirectional path and
  response-shape alignment.

## Follow-ups / Deferred
- Add single-flight refresh protection for concurrent requests.
- Implement registration and forced password-change routing.
- Build Subjects, Lab Detail, Assignments, Classes, and LabPlayer.
- Decide and verify the mobile simulation strategy on Android and iOS devices.

## References
- `intelligent_memory_management/contracts/api.md`
- `mobile_flutter/planning/screen_inventory.yaml`
- `mobile_flutter/README.md`

---

**Completed By:** Copilot
**Duration:** One development session
