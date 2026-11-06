# Mobile Attempt and Teacher Management Flows

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** Feature slice / Mobile parity
**Status:** Completed

## Summary
Completed the remaining functional mobile slice for teacher assignments and
classes plus the learner LabPlayer lifecycle. The Flutter client now consumes
the existing assignment, classroom, attempt, and lab-bridge contracts without
changing the Django backend.

## Context / Trigger
The mobile client had assignment and class list screens but lacked teacher
creation/results, class detail management, and lab playback. These blocked the
end-to-end learner and teacher journeys.

## Scope
Included assignment creation/results, classroom detail and student removal,
attempt start/resume/autosave/events/answers/submit, question rendering,
simulation hosting, route wiring, and model contract tests. Excluded backend
changes, school/platform consoles, password checklist parity, and real
Android/iOS screenshot comparison.

## Method
Compared the React pages and API client against the authoritative REST and lab
bridge contracts. Extended the Flutter API boundary and models first, then
implemented feature screens and route wiring. The existing iframe simulation
architecture was preserved by hosting the web simulation inside a WebView HTML
wrapper and forwarding the unchanged bridge messages through a JavaScript
channel.

## Decisions & Findings
- Django remains the only source of truth for attempts, marking, scores,
  classroom membership, and assignment results.
- The mobile LabPlayer does not reimplement simulations; it reuses the existing
  offline simulation entry and `lec-bridge.js`.
- The wrapper validates the iframe source and origin before forwarding bridge
  messages to Flutter.
- Functional client coverage is complete for this slice, but visual/device
  parity is not proven without Android/iOS targets.

## Changes Made
- Added assignment creation form and teacher results/review navigation.
- Added classroom detail, copy-code, learner listing, and remove-learner flow.
- Added API methods for attempt start, detail, progress, events, answers,
  submission, assignment results, and student removal.
- Added richer classroom, assignment, attempt, event, answer, and result models.
- Added WebView-based LabPlayer with responsive simulation/step layout,
  question answering, autosave, event completion, review, and submission.
- Applied the shared drawer to Subjects and Lab Detail.
- Added contract regression coverage and updated the mobile inventory,
  README, and session log.
- Added `webview_flutter` for Android/iOS simulation hosting.

## Verification
- `cd mobile_flutter && dart format lib test`
- `cd mobile_flutter && flutter analyze`
- `cd mobile_flutter && flutter test`
- `cd mobile_flutter && flutter build web`
- `git diff --check`

All commands passed. `flutter devices` found Linux desktop and Chrome only;
Android/iOS real-device proof was unavailable in this environment.

## Follow-ups / Deferred
Run the LabPlayer on Android and iOS with a reachable
`--dart-define=LAB_BASE_URL=...`, capture same-viewport screenshots against the
web app, and refine remaining password/lockout and visual parity details.

## References
- `mobile_flutter/lib/features/labs/lab_player_screen.dart`
- `mobile_flutter/lib/features/assignments/assignments_screen.dart`
- `mobile_flutter/lib/features/classrooms/classes_screen.dart`
- `mobile_flutter/lib/core/auth/api_client.dart`
- `intelligent_memory_management/contracts/api.md`
- `intelligent_memory_management/contracts/lab-bridge.md`
- `intelligent_memory_management/decisions/ADR-001-lab-architecture.md`
- `intelligent_memory_management/sessions/2026-11-06_session-06.md`

---

**Completed By:** Copilot
**Duration:** One implementation session
