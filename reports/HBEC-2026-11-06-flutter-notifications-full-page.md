# Build the Flutter /notifications full-page route

**Date:** 2026-11-06
**Project:** HBEC (STUDENT/mobile_flutter)
**Type:** Feature migration (web-to-Flutter parity)
**Status:** Completed

## Summary
Built web's `/notifications` full-history page as a real Flutter screen,
closing a gap `scripts/parity/screen_map.yaml` had marked `missing`. The
Flutter feature package already had its data/domain/bloc layers; the only
missing piece was the page, the route, and wiring from the existing
dashboard-bell bottom sheet, which is kept rather than replaced.

## Context / Trigger
`scripts/parity/screen_map.yaml` / `screen_map_report.md` flagged
`/notifications` as ❌ missing, noting "Flutter has a notifications
feature/bloc but no full-page route yet (bottom-sheet-only per the
2026-11-03 dashboard parity report)." Asked to use the project's
`migrate-web-to-flutter` skill to build it for real.

## Scope
Included: the full-page route, its screen, wiring from the bell's bottom
sheet, bloc test coverage (previously zero), golden tests, and the parity
tracker updates (`screen_map.yaml`, `parity_map.yaml`).

Excluded, deliberately: no changes to the notifications data/domain layers
or the `NotificationsBloc` itself — they were already correct and complete,
confirmed by reading them before writing any new code. No sync-queue work:
this feature's writes (mark-read/dismiss/clear-all) go straight to the
NOTIFICATIONS service on both web and Flutter; there is no offline-mutation
path on either side to extend.

## Method
Followed the `migrate-web-to-flutter` skill's six-step workflow: confirmed
the target against the live Flutter tree (not just the map) to rule out
duplicate work; read the full web source (`NotificationsPage.tsx`,
`NotificationBell.tsx`, `useNotifications.ts`, `notificationsApi.ts`) before
writing any Dart; read the existing Flutter data/domain/bloc layers to
confirm no new bloc/repository was needed; wrote the page against a
translation spec (AppColors tokens, native dismiss-button idiom in place of
web's hover-reveal); built with BLoC tests first where none existed; and
closed the loop by re-running both parity scripts and diffing screenshots
of the rendered golden tests against the web page's actual structure.

## Decisions & Findings
- **Web keeps both surfaces, not one.** `NotificationBell.tsx`'s popover
  already does list/mark-read/dismiss/unread-count/polling; its footer's
  "View all" button navigates to `/notifications` for the full scrollable
  history. The right Flutter shape was therefore the same split — keep the
  existing bottom sheet for quick access, add a "View all" footer that
  pushes the new route — not replacing the sheet with the page or merging
  the two.
- **Touch has no hover state.** Web's dismiss button is
  `opacity-0 group-hover:opacity-100`; Flutter's equivalent `IconButton` is
  always visible. Recorded as a deliberate, documented deviation per the
  skill's fidelity bar, not a silent gap.
- **No sync-queue gap to flag.** Checked explicitly since the skill calls
  this out for any screen that mutates data: both web and Flutter call the
  NOTIFICATIONS service directly for mark-read/dismiss/clear-all, with no
  offline-queued write path on either side, so nothing was inherited broken
  here.

## Changes Made
- `STUDENT/mobile_flutter/lib/features/notifications/presentation/pages/notifications_page.dart` (new)
- `STUDENT/mobile_flutter/lib/core/navigation/router.dart` — top-level
  `GoRoute(path: '/notifications', ...)`, outside the subscription-gated
  `ShellRoute`, matching web's own placement next to `/` and `/dashboard`.
- `STUDENT/mobile_flutter/lib/features/home/presentation/widgets/dashboard_header.dart` —
  added a "View all" footer to the existing `_NotificationsSheet` that pops
  the sheet and pushes `/notifications`.
- `STUDENT/mobile_flutter/test/features/notifications/presentation/bloc/notifications_bloc_test.dart` (new) —
  first-ever coverage for `NotificationsBloc`.
- `STUDENT/mobile_flutter/test/golden_tests/notifications_page_golden_test.dart` (new) —
  populated + empty-state goldens.
- `scripts/parity/screen_map.yaml`, `scripts/parity/parity_map.yaml` —
  `/notifications` moved to `built`/`matched`.
- `STUDENT/mobile_flutter/planning/episodes/2026-11-06_notifications_full_page.md` (new).
- Commit `9e94b4ee9` on `master`.

## Verification
- `flutter test test/features/notifications/...` — 5/5 new bloc tests pass
  (load success, load failure, mark-read, dismiss, clear-all).
- `flutter test test/golden_tests/notifications_page_golden_test.dart` —
  both golden scenarios render and pass; rendered PNGs visually checked
  against the web page's structure (header row, unread-tinted row, dismiss
  icon, relative timestamps, empty state).
- `flutter analyze` — zero new errors/warnings (only pre-existing
  `withOpacity`-deprecation infos already present elsewhere in the codebase).
- `python3 scripts/parity/screen_map.py` and
  `python3 scripts/parity/web_flutter_parity.py` (HBEC repo root) re-run
  after the parity-map edits — "Parity map matches live code on both sides.
  No drift found."

## Follow-ups / Deferred
None opened — the gap closed cleanly with no new backend work, no
uncovered sync-queue issue, and no outstanding visual discrepancy beyond
the one documented touch-vs-hover deviation above.

## References
- `scripts/parity/screen_map.yaml` / `screen_map_report.md`
- `scripts/parity/parity_map.yaml`
- `STUDENT/mobile_flutter/planning/episodes/2026-11-06_notifications_full_page.md`

---

**Completed By:** Claude Sonnet 5 (agent session)
**Duration:** Single session
