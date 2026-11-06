# "Restart the tour" settings card has no tour to restart on Flutter

**Date:** 2026-11-06
**Project:** HBEC
**Environment:** Development working tree (uncommitted)
**Severity:** Low — not user-facing data loss, but a dead-end control: tapping it does nothing observable
**Status:** Investigating

## Summary
`STUDENT/mobile_flutter/lib/features/auth/presentation/widgets/settings/tour_replay_card.dart`
is a direct port of web's `TourReplayCard.tsx`: it calls
`authRepository.restartTour()` (`PUT /auth/tour-restart/`, resetting the
backend's tour-completed flag) and then navigates to `/dashboard`. On web,
the dashboard then renders `TourManager.tsx`'s guided walkthrough overlay.
On Flutter, no such mechanism exists anywhere in `lib/` — `grep -rln "tour"
lib/ -i` finds the restart API call and this one settings card only. The
button restarts a tour that the app has no code to display.

## Symptoms
- A student taps "Restart the tour" in Settings → App Tour.
- The backend flag resets and the app navigates to the dashboard.
- Nothing visibly happens: no walkthrough, no tooltips, no onboarding
  overlay — the button appears broken even though its own API call succeeds.

## Environment Details
- **Services Affected:** `features/auth/presentation/widgets/settings/tour_replay_card.dart`,
  the dashboard page (missing counterpart to web's `TourManager.tsx`).
- **Related Components:** web's `src/features/onboarding/` (`TourManager.tsx`,
  `tourSteps.ts`) — this whole feature has no Flutter port at all, confirmed
  during a web→Flutter screen-map reconciliation pass; see
  `scripts/parity/screen_map.yaml`'s `feature-onboarding` node and
  `scripts/parity/parity_map.yaml`'s `onboarding` features row (HBEC repo).
- **Time First Observed:** 2026-11-06.

## Investigation Steps

### 1. Initial Diagnosis
While reconciling HBEC's web↔Flutter screen map, the `onboarding` feature was
confirmed genuinely absent on Flutter (not folded into auth/personalization
as an earlier note speculated). Finding `TourReplayCard` already ported,
seemingly implying an onboarding tour existed, prompted a closer look.

### 2. Root Cause Analysis
```bash
grep -rln "tour" lib/ -i
# features/auth/data/datasources/auth_remote_datasource.dart   (API call)
# features/auth/presentation/pages/profile_page.dart           (renders the card)
# features/auth/domain/repositories/auth_repository.dart       (interface)
# features/auth/data/repositories/auth_repository_impl.dart    (impl)
```
No `TourManager`-equivalent widget, no tour-step data, nothing that reads
the tour-completed flag to decide whether to render a walkthrough.

### 3. Key Findings
- The settings CARD was ported (it's a small, self-contained widget), but
  the actual onboarding TOUR feature it depends on was not — a partial port
  that looks complete in isolation (the card renders fine, its API call
  succeeds) but is functionally a dead end for the user.

## Root Cause
The settings page was migrated screen-by-screen without checking whether
every control on it has a real destination/effect on the Flutter side. A
card whose job is to trigger ANOTHER feature's UI is only as complete as
that other feature's port — which here doesn't exist at all.

## Prevention / Rule
**Guardrail:** When migrating a settings/control surface, every button or
toggle that is itself a trigger for a DIFFERENT feature (not a direct
mutation of its own data) must be checked against that feature's own
migration status, not assumed complete because the control itself renders
and its own API call succeeds. This is now written into the
`migrate-web-to-flutter` skill's screen-map discipline (a node's `built`
status should reflect whether using it does what it claims, not just
whether it compiles) — HBEC repo, `.claude/skills/migrate-web-to-flutter/SKILL.md`.

## Solution

### Immediate Fix
None yet — documented at point of discovery per this repo's logging rule.
Two options for whoever picks this up: (a) hide/disable the "Restart the
tour" card on Flutter until onboarding is ported, since a dead button is
worse than no button, or (b) port the onboarding tour itself (small scope:
one overlay component + step data) so the card does what it says.

### Long-term Fix
Port web's `TourManager.tsx` + `tourSteps.ts` as a Flutter onboarding
feature — tracked as the `feature-onboarding` node in
`scripts/parity/screen_map.yaml`.

## Prevention
- [ ] Hide or fix the tour-replay card (pick one of the two options above).
- [ ] Code changes required.

## Related Issues
- `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md` — same
  session's broader finding that several "missing" features were actually
  built in non-obvious locations; this is the inverse case (a control that
  looks built but points at something genuinely missing).

## References
- HBEC repo: `scripts/parity/screen_map.yaml` (`feature-onboarding`,
  `junior-juniorhome` nodes), `scripts/parity/parity_map.yaml`
  (`onboarding` features row).

---

**Resolved By:** Pending
**Time to Resolution:** Pending
