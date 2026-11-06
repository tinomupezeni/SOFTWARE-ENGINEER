# Mobile Home parity slice

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** UI parity implementation
**Status:** Completed

## Summary
The Flutter Home screen was brought closer to the web dashboard's behavior and
visual language without changing the shared Django backend.

## Context / Trigger
The mobile app had live Home data but still looked like a placeholder: it
lacked the web dashboard's greeting context, due metadata, progress, resume
content, teacher actions, and tactile subject tiles.

## Scope
Included Flutter Home presentation and the existing authenticated `GET /labs/`
client call needed for resume cards. Backend code, REST routes, database
schema, Login registration, navigation, Lab Detail, and LabPlayer were out of
scope.

## Method
Compared `DashboardPage.tsx`, `dashboard.css`, and shared design tokens with
the Flutter Home implementation. Reused the existing API contract and added
focused model/data loading only where the web page already consumes it.

## Decisions & Findings
- The web dashboard requires lab summaries in addition to assignments and
  attempts to render "Continue where you left off".
- Subject colours, soft backgrounds, rounded cards, borders, and progress
  treatment were mirrored from the web tokens.
- Mobile uses native Flutter controls and layout, so exact CSS pixel identity
  is not claimed until real-device screenshot comparison is completed.

## Changes Made
- Added `/labs/` loading to the mobile Home data layer.
- Added dynamic greeting and role-specific sublines.
- Added due-state labels, assignment progress, resume cards, teacher action
  affordance, and tactile subject tiles.
- Updated the parity inventory, README, and session log.

## Verification
- `cd mobile_flutter && flutter analyze`
- `cd mobile_flutter && flutter test`
- `cd mobile_flutter && flutter build web`
- `git diff --check`
- Result: all commands passed.

## Follow-ups / Deferred
- Capture web and Flutter renders at the same phone viewport.
- Complete Login signup parity, navigation shell, Subjects, Lab Detail,
  Assignments, Classes, and LabPlayer.
- Validate on Android and iOS hardware/simulators.

## References
- `frontend/src/features/dashboard/DashboardPage.tsx`
- `frontend/src/features/dashboard/dashboard.css`
- `mobile_flutter/lib/main.dart`
- `mobile_flutter/planning/screen_inventory.yaml`

---

**Completed By:** Copilot
**Duration:** One development session
