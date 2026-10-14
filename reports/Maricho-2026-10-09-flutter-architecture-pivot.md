# Maricho Architecture Pivot: React Native to Flutter

**Date:** 2026-10-09
**Project:** Maricho
**Type:** Architecture Decision
**Status:** Completed

## Summary
The mobile frontend tech stack for Maricho was updated from React Native (Expo) to Flutter based on a direct user command. The project's ADR 001, Engineering Standards, and Backlog were updated to reflect this change, and a new Flutter app was scaffolded.

## Context / Trigger
The original project architecture (ADR 001) and engineering standards mandated the use of React Native with Expo and TypeScript for the mobile application. However, during the start of Sprint 3 (Mobile Development), the user explicitly directed: "no we use flutter not native".

## Scope
- Aborted the in-progress Expo scaffolding.
- Scaffolded a new Flutter application in the `/mobile` directory.
- Updated `docs/architecture/adr/001-core-tech-stack.md` to specify Flutter, replacing references to SQLite/AsyncStorage with SQLite/SharedPreferences.
- Updated `docs/engineering_standards.md` to reflect Flutter/Dart analyzer linting instead of ESLint/TypeScript.
- Updated `docs/backlog.md` task `APP-001`.

## Method
Reverted the React Native directory initialization and utilized the `flutter create` CLI tool to align with the new standard. Adhered to the `SOFTWARE-ENGINEER` repo rules by documenting this user-approved deviation in this formal report.

## Decisions & Findings
The user approved this deviation inherently by giving the directive. Flutter is well-suited for the constraints of Maricho (low-end devices, offline-first) due to its compiled nature and consistent UI rendering, which may offer better performance on the target market's older Android devices than React Native's JS bridge. 

## Changes Made
- `docs/architecture/adr/001-core-tech-stack.md`
- `docs/engineering_standards.md`
- `docs/backlog.md`
- Created `/mobile` directory using `flutter create mobile`.

## Verification
- Confirmed Flutter is correctly installed (`v3.47.5`) on the system.
- Confirmed the Flutter project scaffold was successfully created.

## Follow-ups / Deferred
Task APP-001 will now proceed with Flutter-specific dependencies for SQLite and offline storage (e.g., `sqflite` and `shared_preferences`).

## References
- Maricho ADR 001 (`docs/architecture/adr/001-core-tech-stack.md`)

---

**Completed By:** Antigravity
**Duration:** 5 mins
