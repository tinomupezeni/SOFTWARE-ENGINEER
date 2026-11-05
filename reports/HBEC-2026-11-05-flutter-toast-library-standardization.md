# Standardized on `toastification` for Flutter notification toasts, matching Club Zero

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Type:** Architecture Decision
**Status:** Completed

## Summary
Replaced ad hoc `ScaffoldMessenger.of(context).showSnackBar(...)` calls
scattered across the Flutter app with a single `AppToast` helper built on
the `toastification` package — the same package the org's other Flutter
app (`SharedHQ/club_zero_mobile`) already uses, per the user's explicit
instruction to check that app and reuse what it uses rather than pick a
new library independently.

## Context / Trigger
While fixing a live "could not generate papers right now" bug (see
`HBEC-2026-11-05-flutter-ai-paper-generation-uuid-mismatch.md`), the user
separately asked for "a proper notifications toast" and pointed at Club
Zero as the reference for which library to standardize on, rather than
leaving each HBEC screen to invent its own error-display pattern.

## Scope
**Included:**
- Added `toastification: ^3.2.0` to `pubspec.yaml` (confirmed via
  `club_zero_mobile/pubspec.yaml`, same version already proven there).
- Built `lib/shared/widgets/app_toast.dart` (`AppToast.success/error/info`)
  wrapping `toastification.show(...)` with HBEC's own `AppColors` palette
  instead of Club Zero's hardcoded colors — the two apps share a library,
  not a visual theme.
- Migrated every existing `ScaffoldMessenger.showSnackBar` call used for an
  app-wide notice (error or informational toast) to `AppToast`: the new AI
  Generator's error path, Friday's stream-failure message, Add Subject's
  save failure, personalization save failure, registration failure and
  password-mismatch validation, two Project Guide notices (no templates
  available, project-creation failure), and the "Google sign-in is coming
  soon" notice on login.

**Explicitly excluded:**
- `SnackBar`s that aren't app-wide notices were left alone — none were
  found in this pass (every remaining `ScaffoldMessenger` usage in the
  codebase was a candidate and got migrated; confirmed by re-grepping
  after the change — only `app_toast.dart`'s own doc comment mentions
  `ScaffoldMessenger` now, as the pattern it replaces).
- Club Zero's own toast usage (icons, exact copy, `ThinkingOrb` branding)
  was not copied — only the library choice and call shape transfer; the
  visual language stays HBEC's own.

## Method
1. Located Club Zero at `/home/shadowe/Projects/SharedHQ/club_zero_mobile`
   (the user named it informally as "club zero"; found by filesystem
   search since it wasn't in a path the session had touched before).
2. Read its `pubspec.yaml` for the exact dependency and version, and
   several call sites (`feedback_screen.dart` et al.) for the actual
   `toastification.show(...)` call shape and confirmed no app-level
   `ToastificationWrapper` was needed for that usage pattern.
3. Built one shared helper rather than calling `toastification.show`
   inline at each site, so HBEC's toast look (colors, duration, style) is
   defined once and both apps independently own their own visual choices
   on top of the same underlying library.
4. Grepped the whole `lib/` tree for `ScaffoldMessenger` before and after
   the migration to confirm every app-wide-notice call site was actually
   converted, not just the one the bug report named.

## Decisions & Findings
- **Share the library, not the theme.** Club Zero's toasts use its own
  hardcoded brand colors (`#0A3C30`) and a `ThinkingOrb` mascot icon;
  `AppToast` uses HBEC's `AppColors` (`success`/`destructive`/`primary`)
  and no custom icon — the user asked for the same library, not the same
  look, and conflating the two would have imported a visual identity that
  doesn't belong to this app.
- **One helper, not inline calls.** Every call site now reads
  `AppToast.error(context, message)` rather than repeating
  `toastification.show(...)` boilerplate — if the toast's look needs to
  change later (duration, position, style), there is one place to change
  it instead of N.

## Changes Made
**New file:** `lib/shared/widgets/app_toast.dart`
**Modified:** `pubspec.yaml` (+1 dependency); 8 files converted from
`ScaffoldMessenger`/`SnackBar` to `AppToast`: `ai_papers_page.dart`,
`friday_chat_page.dart`, `add_subject_sheet.dart`, `personalization_page.dart`,
`register_page.dart` (2 call sites), `project_guide_page.dart` (2 call
sites), `login_page.dart`.

## Verification
- `flutter analyze`: clean (zero errors).
- `flutter test`: same pre-existing single failure as every check this
  session (`login_page_golden_test.dart`, independently confirmed
  unrelated) — nothing newly broken.
- Re-grepped `ScaffoldMessenger` across `lib/` after the change: zero
  remaining call sites outside `app_toast.dart`'s own doc comment.
- **Not yet done:** visual confirmation of the toast's actual on-device
  appearance (position, color contrast, auto-dismiss timing) — pending the
  live staging run already in progress for the UUID-mismatch fix in the
  same session.

## Follow-ups / Deferred
- If Club Zero's toast visual pattern (icon style, exact durations) is
  ever meant to be a shared design-system decision across the org's
  Flutter apps rather than each app choosing its own look on a shared
  library, that would be a separate, explicit decision — not assumed here.

## References
- `/home/shadowe/Projects/SharedHQ/club_zero_mobile/pubspec.yaml` (source
  of the version pin)
- `/home/shadowe/Projects/SharedHQ/club_zero_mobile/lib/screens/
  feedback_screen.dart` (reference call shape)
- `STUDENT/mobile_flutter/lib/shared/widgets/app_toast.dart`
- Related: `HBEC-2026-11-05-flutter-ai-paper-generation-uuid-mismatch.md`

---

**Completed By:** tinomupezeni (with Claude Code)
**Duration:** Same session as the AI-generation UUID fix
