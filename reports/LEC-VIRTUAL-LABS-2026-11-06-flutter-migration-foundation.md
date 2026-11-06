# LEC Virtual Labs Flutter Migration Foundation

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** Architecture Decision / Migration Foundation
**Status:** Completed

## Summary
Established the Flutter mobile migration foundation for LEC Virtual Labs. The
mobile track follows the existing web user journey from login to home and
later lab playback, using Riverpod and GoRouter while preserving the Django
API and lab contracts as authoritative.

## Context / Trigger
The product direction changed from web-only to a mobile app that mirrors the
web experience. The repository had no mobile client, parity inventory, or
mobile architecture.

## Scope
Included Flutter project creation, state/navigation dependency selection,
initial Login and Home visual shells, the parity screen inventory, and
translation notes. Excluded live authentication, API integration, all
registration variants, role-specific data, lab playback, and production
mobile release configuration.

## Method
Read the live React Login and Dashboard implementations and their design
tokens/styles, then translated the first user-flow screens into a minimal
Flutter shell. Added explicit inventory statuses instead of treating absent
features as complete.

## Decisions & Findings
- Target Android and iOS.
- Use Riverpod for state and GoRouter for navigation.
- Build by user flow: login → home → subjects → lab detail → lab player.
- Use visual/UX parity with deliberate native mobile adaptations, not literal
  DOM or pixel copying.
- The web application currently has no mobile implementation to reuse.
- LabPlayer is a significant future boundary because web simulations use an
  iframe/postMessage bridge; mobile implementation must preserve resume,
  events, and server-side marking.

## Changes Made
- Added `mobile_flutter/` Flutter app scaffold.
- Added Riverpod and GoRouter dependencies.
- Added visual Login and Home shells.
- Added `mobile_flutter/planning/screen_inventory.yaml`.
- Added `mobile_flutter/planning/translation-login-home.md`.
- Added a startup widget test.
- Linked mobile documentation from project memory.

## Verification
- `flutter pub get` passed.
- `flutter analyze` passed with no issues.
- `flutter test` passed with one widget test.

## Follow-ups / Deferred
- Implement secure authentication and session restoration against the existing
  Django endpoints.
- Add signup, role routing, live Home data, and loading/error states.
- Capture web and Flutter phone-width renders and compare them explicitly.
- Decide the mobile simulation host strategy before LabPlayer implementation.

## References
- `frontend/src/features/auth/LoginPage.tsx`
- `frontend/src/features/dashboard/DashboardPage.tsx`
- `frontend/src/features/auth/login.css`
- `frontend/src/features/dashboard/dashboard.css`
- `intelligent_memory_management/contracts/api.md`
- `intelligent_memory_management/contracts/lab-bridge.md`
- `mobile_flutter/planning/screen_inventory.yaml`

---

**Completed By:** Copilot
**Duration:** Same session
