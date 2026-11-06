# Interactive Learning on Flutter — first slice (subject-picker landing page)

**Date:** 2026-11-06
**Project:** HBEC (mobile_flutter)
**Type:** Feature Migration (web → Flutter parity)
**Status:** Completed

## Summary
Built the first Flutter slice of web's Interactive Learning pillar: the
`/interactive` subject-picker landing page, replacing the full-pillar
"coming soon" placeholder (`InteractiveLearningPlaceholderPage`) that stood
in for the whole feature. The 3D models/labs pillar behind it stays
deliberately out of scope — a separate, much larger effort — so tapping a
subject now reaches an honest per-subject placeholder instead of the real
feature, keeping the route shape (`/interactive/:subjectId`) ready for that
next pass.

## Context / Trigger
Direct task: port web's Interactive Learning landing page to Flutter,
following this repo's `migrate-web-to-flutter` skill, using a prior dry-run
translation spec as a starting point to be re-verified against current code.

## Scope
**In scope:** `/interactive` route only — subject grid (add/remove, subject
icons, per-card tap), loading state, empty state, header/level badge.

**Explicitly out of scope:** `/interactive/:subjectId` (web's
`SubjectVisualsPage`, 3D models) and `/interactive/:subjectId/lab/:labId`
(`LabPage`, hands-on lab simulations) — a much larger effort (3D rendering,
WebGL-equivalent, physics simulations) that the existing placeholder page's
own doc comment already deferred as "its own future initiative." This report
does not re-decide that scope boundary, only builds the slice it names.

## Method
1. Re-read the live web source in full
   (`STUDENT/Frontend/src/features/interactive-learning/{pages,hooks,api,data}`)
   rather than trusting the prior dry-run spec at face value — confirmed most
   of it still held, but found the spec's assumption that the landing grid
   needs no visuals/labs fetching was wrong (web's grid *does* show a live
   per-subject lesson count and a cross-subject "More subjects" list, both
   sourced from the harness's visuals+labs catalogue).
2. Checked for an existing structural analogue on the Flutter side before
   designing anything new: `ExamPracticePage` is exactly this shape (a
   subject grid reading `AuthBloc.user.subjects`, resolving names via
   `CurriculumRepository` + `PersonalizationCubit`, add-only via
   `AddSubjectSheet`) and was reused wholesale rather than re-derived.
3. Verified, rather than assumed, whether the reusable add/remove-subject
   write path already satisfied the offline-first sync-queue rule — it does
   not; filed as its own bug-log entry rather than silently inherited or
   silently fixed inside this PR (see References).
4. Built the page, an extracted presentational card widget (for golden
   testing in isolation, since the real page is wired to `AuthBloc` + DI
   singletons that golden tests shouldn't need to mock), and a per-subject
   placeholder destination.
5. Compared against web screenshots mentally via source reading (no browser
   screenshot was captured for this pass; visual comparison was done via
   close reading of web's Tailwind classes and `SubjectGrid.tsx`/
   `AddSubjectModal.tsx`, converting spacing 1:1 per the skill's cheat sheet)
   and against `ExamPracticePage`'s already-shipped equivalent grid.
6. Ran `flutter analyze`, the new tests (`flutter test --update-goldens` for
   first-run golden images), and the full suite to confirm no regression.
7. Closed the loop: `screen_map.yaml`/`parity_map.yaml` updated by hand,
   both parity scripts re-run clean, phase tracker and long-term plan
   updated.

## Decisions & Findings
- **No dynamic per-subject lesson count / "More subjects with interactive
  lessons" list.** Both read the harness's visuals+labs catalogue, which
  belongs entirely to the out-of-scope 3D/labs pillar — wiring that fetch now
  would pull in-scope-adjacent work ahead of the pass that actually needs it,
  for a number nothing downstream yet uses (the destination is a
  placeholder). Every card gets one static description instead
  ("Interactive lessons and 3D models"), matching the precedent
  `ExamPracticePage` already set for its own grid ("Practice past exam
  papers", static).
- **No `hasContent`-dimmed card.** Flutter's `user.subjects` (plain subject
  codes from `AuthBloc`) carries no such flag — same simplification
  `ExamPracticePage` already made; not re-litigated here.
- **No per-card remove button.** Web's is a hover-reveal `X` with an
  `AlertDialog` confirmation; mobile has no hover. Rather than invent a new,
  page-specific remove affordance (persistent icon vs. long-press — both
  considered), this follows `ExamPracticePage`'s existing pattern: add *and*
  remove both happen in the one shared `AddSubjectSheet` (checkbox list),
  keeping one mental model across every subject-grid page instead of a
  second one just for this screen.
- **Loading state upgraded to a `ShimmerCard` skeleton**, not
  `ExamPracticePage`'s bare `CircularProgressIndicator`. The translation spec
  called this out explicitly (web shows three shaped pulsing cards, not a
  spinner) and `ShimmerCard` already existed in `shared/widgets/` completely
  unused anywhere in the app — this is the first page to use it, and is
  closer to web than the existing precedent it otherwise follows.
- **Tap destination**: pushes to `/interactive/:subjectId`, landing on a new
  `InteractiveSubjectPlaceholderPage` (subject-named "coming soon"), not a
  no-op and not a route dead-ended at nothing — keeps the URL shape the next
  migration pass will replace wholesale.
- **Found and flagged, not fixed:** the shared add/remove-subject write path
  (`PersonalizationCubit` → `AuthRepositoryImpl.savePersonalization` → remote
  API directly) does not go through `SyncQueueService`, violating this
  project's offline-first rule. Pre-existing (shared by `ExamPracticePage`
  and `TopicRevisionPage` already), not introduced by this slice — logged
  separately per this repo's bug-log convention rather than folded into this
  report or silently fixed as a drive-by inside an unrelated feature PR.

## Changes Made
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/interactive_learning_page.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/interactive_subject_placeholder_page.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/widgets/interactive_subject_card.dart` (new)
- `STUDENT/mobile_flutter/lib/features/home/presentation/pages/interactive_learning_placeholder_page.dart` (deleted — superseded, no remaining references)
- `STUDENT/mobile_flutter/lib/core/navigation/router.dart` (wired the real page + the new per-subject placeholder route)
- `STUDENT/mobile_flutter/lib/shared/curriculum/pillars.dart` (doc comment updated — no longer refers to the deleted placeholder class)
- `STUDENT/mobile_flutter/test/golden_tests/interactive_subject_card_golden_test.dart` (new — golden + interaction tests)
- `STUDENT/mobile_flutter/test/features/interactive_learning/presentation/pages/interactive_subject_placeholder_page_test.dart` (new)
- `scripts/parity/screen_map.yaml`, `scripts/parity/parity_map.yaml` (status/notes updated)
- `STUDENT/mobile_flutter/planning/phases/flutter_migration_phases.md`, `STUDENT/mobile_flutter/planning/long_term_plan.md` (phase tracker + evolution history)

## Verification
- `flutter analyze` — no issues in changed/new files; full-project analyze
  shows only pre-existing lint infos (`withOpacity` deprecation etc.)
  unrelated to this change.
- `flutter test` (full suite) — 90 passed, 1 skipped (pre-existing, requires
  a live dev backend), 2 failed — both in `login_page_golden_test.dart`,
  unrelated to this change (pre-existing golden-image mismatch, not touched
  by this PR).
- New tests: `interactive_subject_card_golden_test.dart` (2 golden scenarios
  — populated grid, `ShimmerCard` loading grid — + 1 tap-interaction test)
  and `interactive_subject_placeholder_page_test.dart` (2 tests covering the
  named and fallback titles) all pass.
- `python3 scripts/parity/screen_map.py` and
  `python3 scripts/parity/web_flutter_parity.py` both re-run clean after the
  manual YAML edits — "Parity map matches live code on both sides. No drift
  found."

## Follow-ups / Deferred
- The 3D models/labs pillar (`SubjectVisualsPage`, `LabPage`) — its own,
  much larger migration pass; not started.
- Dynamic per-subject lesson counts and the "More subjects with interactive
  lessons" cross-list — deferred until the visuals+labs catalogue fetch is
  built for the next pass, at which point this landing page should be
  revisited to wire them in (currently static descriptions).
- The offline sync-queue gap in `AuthRepositoryImpl.savePersonalization` —
  see `Mobile_Apps/HBEC-2026-11-06-personalization-write-bypasses-sync-queue.md`.
- No live-device/emulator screenshot comparison was captured this pass
  (reasoning was done from source + Tailwind class reading instead); a future
  pass revisiting this page for the counts work should also capture a real
  side-by-side screenshot per the skill's step 2/5.

## References
- `HBEC-2026-11-06-personalization-write-bypasses-sync-queue.md` (bug log,
  this directory tree's `Mobile_Apps/`)
- `STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`
- `STUDENT/Frontend/src/features/interactive-learning/pages/InteractiveLearningPage.tsx`
  (web source ported)
- `STUDENT/mobile_flutter/lib/features/exam/presentation/pages/exam_practice_page.dart`
  (structural precedent reused)

---
**Completed By:** Claude Sonnet 5 (agent session)
**Duration:** Single session
