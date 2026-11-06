# Interactive Learning on Flutter — second slice (per-subject catalog)

**Date:** 2026-11-06
**Project:** HBEC (mobile_flutter)
**Type:** Feature Migration (web → Flutter parity)
**Status:** Completed

## Summary
Built the second Flutter slice of web's Interactive Learning pillar: the
per-subject catalog/listing page at `/interactive/:subjectId`, replacing
`InteractiveSubjectPlaceholderPage` (the first slice's honest stub). Lists
labs and 3D/motion visuals for the tapped subject as cards (icon, title,
summary, heritage badge where present). The 3D canvas / lab runtime stays
explicitly out of scope — a separate 3D-rendering architecture decision is
being made before any renderer work starts — so tapping any card now reaches
a new, honestly-labelled placeholder instead of the real content.

## Context / Trigger
Direct task: build the second slice of the Interactive Learning pillar,
following the `migrate-web-to-flutter` skill, continuing from the first
slice committed earlier the same day (`bf3efff40`).

## Scope
**In scope:** `/interactive/:subjectId` — a list of labs and 3D/motion
visuals for one subject, each as a card (title, kind label, summary,
heritage badge), loading/empty/failed states, pull-to-refresh/retry.

**Explicitly out of scope, confirmed before building:**
- The actual 3D canvas / motion-clip stage and the Workbench lab runtime —
  tapping any card opens an honest placeholder instead.
- Web's **primary** view for this route: a pgvector-backed, topic-grouped
  lesson index with a search box (`useSubjectLessons` →
  `/interactive-learning/lessons`). That index also serves a third lesson
  kind, `interactive` — a component lesson that mounts an answerable
  `WidgetBlock` straight on the page — which needs the same
  interactive-component rendering this pass defers alongside the 3D stage.
  This slice instead builds web's **fallback** view, `PlainLists` (plain Labs
  + 3D-lessons sections, always structurally present), which is exactly "a
  list of cards: title, kind, icon" as scoped, without pulling in
  component-rendering work the task explicitly deferred.

## Method
1. Read `SubjectVisualsPage.tsx` in full, plus its hooks (`useInteractive.ts`:
   `useVisuals`, `useLabs`), API layer (`interactiveApi.ts`:
   `fetchVisuals`/`fetchLabs`), transformers (`servesSubject`,
   `labServesSubject`, `mapVisualFromApi`, `mapLabFromApi`) and types. Found
   the page's actual primary rendering path is topic-grouped lesson search
   (`useSubjectLessons`), with `PlainLists` only as the fallback shown when
   that service is unreachable — and that the primary path's `interactive`
   lesson kind pulls in exactly the widget-rendering work this task named as
   out of scope. Chose the fallback shape as this slice's target rather than
   half-building the primary one.
2. Checked `App.tsx`'s routes: web has no separate route for a plain visual
   (`VisualStage` opens inline via `?v=<id>` on the same page); only
   `/interactive/:subjectId/lab/:labId` is a real route. Recorded the
   Flutter-only `/interactive/:subjectId/visual/:visualId` route as a
   deliberate mobile adaptation (go_router has no clean
   query-param-as-tab-state equivalent) rather than silently diverging.
3. Searched for pre-existing/uncommitted repository or datasource code for
   visuals/labs before writing new ones (`git status`, grep across
   `lib/features` and `lib/shared`) — found none; this pillar's only prior
   Flutter work was the first slice's static subject grid.
4. Found the established non-SSE harness JSON pattern
   (`GamificationRepositoryImpl`: origin + `/harness-stream/api/v1/...`,
   `Result<T>`, `AppLogger.error`) and reused it exactly for the new
   `InteractiveLearningRepositoryImpl`, rather than inventing a second
   pattern or misusing `HarnessStreamClient` (which wraps the SSE
   stream-token handshake, not plain GETs).
5. Built domain (`entities`, `repositories`, `usecases`) → data (`models`,
   `repositories`) → presentation (`SubjectCatalogBloc`, with `bloc_test`
   cases written before the page) → DI registration → routes, per
   `adding_a_feature.md`.
6. Ran `flutter analyze` and the full test suite; generated golden images for
   the new card widget.
7. Closed the loop: `screen_map.yaml`/`parity_map.yaml` updated by hand (the
   screen-map script's filename-convention heuristic nulled the hand-entered
   Flutter component paths on re-run — a known limitation, see
   `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md` — so
   those fields were restored by hand after each re-run), both parity
   scripts re-run clean, phase tracker and long-term plan updated.

## Decisions & Findings
- **PlainLists, not the topic-grouped lesson index.** See Scope above — the
  primary view's `interactive` lesson kind needs interactive-component
  rendering, out of scope by the same boundary as the 3D stage. Topic
  grouping and search are left for a later slice once that rendering is
  in scope.
- **All labs are shown, not filtered by renderer availability.** Web's
  `useLabs()` drops a lab the browser's experiment registry (`getExperiment`)
  can't render. Flutter renders no lab experiments at all in this slice (every
  tap goes to a placeholder), so that filter has no Flutter equivalent to
  apply — showing every harness-verified lab is the honest list, not an
  arbitrary subset.
- **No automatic staggered retry.** Web retries an empty visuals response up
  to 6 times over ~57s (`VISUALS_RETRY_DELAYS_MS`), tuned to the harness's
  cold-start time, before calling it failed. This slice does a single fetch
  and shows a manual "Try again" affordance instead — simpler, and the retry
  timing constant is itself tied to backend behavior best verified against a
  live deploy rather than guessed at in this pass.
- **An empty visuals catalogue is a failure state, not "no lessons."** Ported
  web's invariant exactly (`useVisuals().failed`): the harness's visuals
  catalogue is never genuinely empty, so an empty answer means the request
  failed. Labs fail silently to `[]`, matching web (no "Try again" there
  either).
- **Mobile-only visual route.** `/interactive/:subjectId/visual/:visualId`
  has no web counterpart (web uses `?v=` inline); recorded explicitly in
  `screen_map.yaml`/`parity_map.yaml` as a mobile adaptation, not a
  parity gap.
- **No topic grouping, no search.** Deliberately deferred with the lesson
  index (see Scope).

## Changes Made
- `STUDENT/mobile_flutter/lib/features/interactive_learning/domain/entities/interactive_catalog.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/domain/repositories/interactive_learning_repository.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/domain/usecases/interactive_learning_usecases.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/data/models/interactive_catalog_model.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/data/repositories/interactive_learning_repository_impl.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/bloc/subject_catalog_bloc.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/subject_catalog_page.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/interactive_lesson_placeholder_page.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/widgets/interactive_lesson_card.dart` (new)
- `STUDENT/mobile_flutter/lib/features/interactive_learning/presentation/pages/interactive_subject_placeholder_page.dart` (deleted — superseded, no remaining references)
- `STUDENT/mobile_flutter/lib/core/di/injection.dart` (registered `InteractiveLearningRepository` + usecases)
- `STUDENT/mobile_flutter/lib/core/navigation/router.dart` (wired `SubjectCatalogPage` + two placeholder routes)
- `STUDENT/mobile_flutter/test/features/interactive_learning/data/models/interactive_catalog_model_test.dart` (new)
- `STUDENT/mobile_flutter/test/features/interactive_learning/presentation/bloc/subject_catalog_bloc_test.dart` (new)
- `STUDENT/mobile_flutter/test/features/interactive_learning/presentation/pages/interactive_lesson_placeholder_page_test.dart` (new)
- `STUDENT/mobile_flutter/test/features/interactive_learning/presentation/pages/interactive_subject_placeholder_page_test.dart` (deleted — tested the removed page)
- `STUDENT/mobile_flutter/test/golden_tests/interactive_lesson_card_golden_test.dart` (new)
- `scripts/parity/screen_map.yaml`, `scripts/parity/parity_map.yaml` (status/notes updated)
- `STUDENT/mobile_flutter/planning/phases/flutter_migration_phases.md`, `STUDENT/mobile_flutter/planning/long_term_plan.md`, `STUDENT/mobile_flutter/planning/semantic/screen_map_report.md` (phase tracker + evolution history)

## Verification
- `flutter analyze` (whole project) — 0 errors; only pre-existing lint infos
  unrelated to this change.
- `flutter test` on the new/changed files — 21 tests pass: 8 model-mapping
  unit tests, 4 `bloc_test` cases (including a case-/space-insensitive
  subject-match case and a failed-request-degrades-gracefully case), 2
  placeholder-page widget tests, 1 golden scenario (2 variants) + 1
  interaction test for `InteractiveLessonCard`, plus the pre-existing
  first-slice subject-card golden suite re-verified unaffected (5 tests).
- `python3 scripts/parity/screen_map.py` and
  `python3 scripts/parity/web_flutter_parity.py` both re-run clean after the
  manual YAML fix-ups — "Parity map matches live code on both sides. No
  drift found."

## Follow-ups / Deferred
- The pgvector-backed, topic-grouped lesson index with search
  (`useSubjectLessons` → `/interactive-learning/lessons`) — a later slice
  once interactive-component rendering is in scope.
- The actual 3D canvas (`VisualStage`) and the Workbench lab runtime behind
  `LabPage` — a separate, much larger pass gated on a 3D-rendering
  architecture decision not yet made.
- No live-device/emulator screenshot comparison was captured this pass (no
  running dev backend/harness in this environment to populate real data);
  visual comparison was done via close reading of web's Tailwind classes and
  component structure, converting spacing 1:1 per the skill's cheat sheet,
  same approach the first slice used. A future pass should capture a real
  side-by-side screenshot once a live backend is available.

## References
- `HBEC-2026-11-06-interactive-learning-flutter-first-slice.md` (this
  directory — the first slice this one continues from)
- `HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`
  (`Mobile_Apps/` — the screen-map heuristic limitation hit again here)
- `STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`
- `STUDENT/Frontend/src/features/interactive-learning/pages/SubjectVisualsPage.tsx`
  (web source ported)
- `STUDENT/mobile_flutter/lib/features/gamification/data/repositories/gamification_repository_impl.dart`
  (structural precedent reused for the harness-stream repository pattern)

---
**Completed By:** Claude Sonnet 5 (agent session)
**Duration:** Single session
