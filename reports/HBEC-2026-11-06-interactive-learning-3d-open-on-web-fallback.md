# HBEC: Interactive Learning 3D fallback resolved as an open-on-web screen

**Date:** 2026-11-06
**Project:** HBEC (STUDENT/mobile_flutter)
**Type:** Scope Decision
**Status:** Completed

## Summary
Web's Interactive Learning pillar renders 3D models and lab experiments on a
custom Three.js renderer (`VISUALS/`) with no Flutter equivalent. The Flutter
lab/visual routes previously showed an honest "coming soon" placeholder. A
research pass confirmed native 3D rendering is hard to build on Flutter and
WebView-embedding the Three.js bundle is risky on this app's low-end Android
target hardware. Owner decision: link out to the already-deployed web page in
the device's own browser rather than build native 3D or embed a WebView.
Implemented, tested, and the screen map/migration-plan docs updated to record
this as the deliberate, scoped resolution.

## Context / Trigger
A prior session surveyed native Flutter 3D options and the WebView-embed
option for the two outstanding routes (`/interactive/:subjectId/lab/:labId`,
`/interactive/:subjectId/visual/:visualId`) and reported the difficulty back
to the project owner, who gave an explicit conditional instruction: "if the
3d is difficult to build on mobile, let's have a link to the web version
then, but only if its difficult to build." This session acted on that
decision once confirmed difficult.

## Scope
**In scope:** replacing the two placeholder routes with a real "open on web"
screen: explanatory copy, an "Open on web" button, a web-base-URL constant
following the app's existing `API_BASE_URL` pattern, and URL construction
matching web's actual route shapes.

**Explicitly excluded:** a WebView embed of the renderer's JS bundle, any
offline bundling of 3D assets, and any auth handoff between the two apps
(checked — no reasonable short-lived handoff exists without new
infrastructure, so the UI copy is honest that the student may land on a
login page rather than exactly where they left off).

## Method
1. Confirmed no existing Flutter work already covered this (git status +
   grep) before starting, per the project's migration-skill guardrail against
   duplicating work on a nested/renamed path.
2. Read web's `App.tsx` to confirm the exact route shapes: lab opens its own
   route (`/interactive/:subjectId/lab/:labId`), a visual opens inline on the
   subject page via a `?v=<id>` query param (`SubjectVisualsPage.tsx`), not
   its own route.
3. Grepped the Flutter app for an existing web-base-URL convention (none
   found) and for the existing API-base-URL pattern
   (`lib/core/di/injection.dart`: `String.fromEnvironment('API_BASE_URL')`
   with a dev-loopback fallback) to mirror it, substituting a production
   web-domain fallback instead of a loopback one, since this link's whole
   point is to open something real. Cross-checked the fallback domain against
   `docker-compose.production.yml`'s `FRONTEND_URL` default
   (`https://student.hbca.tech`).
4. Checked for an existing url_launcher-mocking test pattern in the repo;
   none existed, so the widget takes an injectable `launcher` parameter
   (defaulting to `launchUrl`) rather than adding a new platform-interface
   test dependency — keeps the test simple and matches "keep it simple" from
   the task brief.

## Decisions & Findings
- **Fallback over WebView, confirmed, not re-litigated.** The research pass
  already established WebView-embedding the renderer carries bundling,
  offline-sync, and GPU-driver-crash risk on target hardware; this session
  did not re-assess that, per the owner's explicit decision.
- **External browser, not an in-app WebView wrapper.** `LaunchMode.externalApplication`
  was chosen over an in-app browser view because the owner's ask was for the
  simplest option, and an in-app webview reintroduces a sliver of the same
  WebView risk class being avoided.
- **No auth handoff.** Confirmed out of scope by design; the UI copy was
  written to avoid overpromising ("works best in a browser... you may need to
  sign in there") rather than implying continuity that doesn't exist.
- **Web-base-URL pattern mirrors `API_BASE_URL`.** Both are
  `String.fromEnvironment`-driven dart-defines with a hardcoded fallback —
  consistent with how this app already handles environment-specific URLs,
  rather than introducing a new config mechanism.

## Changes Made
- `STUDENT/mobile_flutter/lib/core/config/web_links.dart` (new): `WebLinks`
  with `baseUrl` (dart-define `WEB_BASE_URL`, fallback
  `https://student.hbca.tech`) and `labUrl`/`visualUrl` builders matching
  web's route shapes.
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/interactive_lesson_placeholder_page.dart`:
  replaced the "coming soon" copy with an "open on web" screen and an
  `ElevatedButton` wired to `url_launcher`, launcher injectable for tests.
- `STUDENT/mobile_flutter/lib/core/navigation/router.dart`: both routes now
  read `subjectId`/`labId`/`visualId` from path parameters and pass a built
  `webUrl` into the page.
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/subject_catalog_page.dart`:
  doc comment updated to describe the new behavior instead of the old
  placeholder.
- Test file rewritten/extended: copy assertions updated, plus new tests for
  both URL shapes being launched externally and a snackbar on launch failure.
- `scripts/parity/screen_map.yaml`, `planning/phases/flutter_migration_phases.md`,
  `planning/long_term_plan.md` updated to record this as "built: links out to
  web rather than rendering natively, per owner decision" — not "still
  missing," not "full native 3D parity."

Commit: `525d6ab40` on `master` ("Resolve Interactive Learning 3D fallback
with an open-on-web screen").

## Verification
- `flutter analyze`: no new errors (pre-existing info-level lints elsewhere
  untouched).
- `flutter test test/features/interactive_learning/`: 17/17 passing,
  including the new launcher-mocking tests for both lab and visual URL
  shapes and the failure-snackbar path.
- `flutter test` (full suite): no regressions attributable to this change;
  the only 2 failures are pre-existing, unrelated golden-image tests for the
  login page (CI/Linux font-rendering variants), confirmed unrelated since
  `mobile_flutter/` had zero uncommitted changes before this session started.
- `python3 scripts/parity/screen_map.py` and
  `scripts/parity/web_flutter_parity.py` re-run; the latter reports "no drift
  found."

## Follow-ups / Deferred
- `scripts/parity/screen_map.py`'s component-discovery regex has a known
  300-character lookahead limit that failed to re-detect
  `subject_catalog_page.dart` for the `/interactive/:subjectId` route on this
  run (pre-existing script limitation, unrelated to this change — the window
  simply doesn't reach the widget constructor in that multi-statement
  builder). Not fixed here; out of scope, matches the already-logged sibling
  issue `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`.
- The real 3D stage/lab runtime (Workbench experiment runtime, Three.js
  canvas) remains unbuilt on Flutter by design; this report does not change
  that scope, only closes the honest-placeholder gap with the owner-approved
  fallback.

## References
- `STUDENT/mobile_flutter/lib/core/config/web_links.dart`
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/interactive_lesson_placeholder_page.dart`
- `STUDENT/mobile_flutter/lib/core/navigation/router.dart`
- `scripts/parity/screen_map.yaml` (`interactive-subjectid-lab-labid`,
  `interactive-subjectid-visual-visualid`)
- `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`

---

**Completed By:** Claude (Sonnet 5), coordinating with project owner decision
**Duration:** ~1 session (continued after a rate-limit interruption)
