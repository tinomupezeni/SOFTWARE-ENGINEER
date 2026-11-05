# Flutter Exam Practice parity: AI Generator & My Studio, shared header, Friday/feedback as floating widgets

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter)
**Type:** Feature Build / Architecture Decision
**Status:** Completed (code-complete; live staging verification in progress at time of writing)

## Summary
Closed a cluster of parity gaps between the Flutter app's Exam Practice flow
and web's `https://student.hbca.tech/exam-practice`, reported together by
the user: a missing level ("O-Level") badge, a missing profile icon
(reported as absent "on all pages"), a missing feedback icon, an entirely
missing "AI Generator & My Studio" feature (custom AI paper generation +
private paper history), and Friday occupying a bottom-nav tab instead of
web's floating-button pattern.

## Context / Trigger
Continuation of the same-session Friday/home-screen parity work. The user
pointed at the live web page and listed concrete UI elements missing from
the Flutter equivalent, including pasting the exact web copy for "AI
Generator & My Studio" to pin down the feature by name.

## Scope
**Included:**
- `LevelBadge` — the "O-Level"/"A-Level" pill in Exam Practice's header,
  derived from the student's own `academic_level`.
- `HbecAppBar` — a shared header widget (title/subtitle/back/trailing +
  profile menu), matching web's single shared `PageHeader.tsx` component
  used across 9+ pages. Rolled out beyond the three Exam Practice screens
  it was built for, to 8 more pages that build their own `AppBar`:
  `TopicRevisionPage`, `SubjectContentPage`, `ProjectGuidePage`,
  `ProjectWorkspacePage`, `GuidedLearningPage`, `ActivityPage` (profile icon
  added via `actions:`, not a full `HbecAppBar` swap, to avoid disrupting
  each page's own custom title layout).
- `FeedbackFab` — a new globally-floating feedback button + dialog,
  mirroring web's `FeedbackWidget.tsx` (mounted once, not per-page), posting
  to the same generic `POST /telemetry/events/` endpoint web reuses.
- Friday converted from a `BottomNavigationBar` tab (bottom nav shrunk from
  5 tabs to 4: Home/Exams/Revision/Projects) to a floating button opening
  the existing chat page as a bottom sheet — matching web, where Friday has
  never been a dedicated route, only a floating launcher + sheet/window.
- **AI Generator & My Studio** — entirely net-new feature, full
  clean-architecture layers:
  - Domain: `AiPaper`, `AiPaperTopic`, `GenerationJobStatus`,
    `GenerationStart` entities; `ExamRepository` extended with
    `getMyAiPapers`, `getSubjectTopics`, `generatePaper`,
    `generateTargetedPaper`, `getGenerationStatus`.
  - Data: five new endpoints wired in `ExamRemoteDataSourceImpl` (`GET
    /practice/papers/ai/`, `GET /curriculum/topics/`, `POST
    /ai/papers/generate/`, `POST /ai/papers/generate-targeted/`, `GET
    /ai/papers/generate/{jobId}/`), none previously called from Flutter.
  - Presentation: `AiPapersCubit` (polling job state, 3s interval / 220 max
    polls — the exact interval and budget web's `generateApi.ts` uses, not
    an approximation), `GeneratePaperModal` (topic checklist with a
    free-text fallback for subjects with no topic catalogue, difficulty/
    style/count pickers), `AiPapersPage` ("Generate New Paper" / "Target My
    Weaknesses" buttons + "My Custom Papers" list with source/visibility
    badges), wired into `SelectPaperPage` as the first, full-width card
    (matching web's `PaperTypeSelector.tsx` exactly), route `/exams/
    :subjectId/ai`.

**Explicitly excluded / simplified, flagged rather than silently dropped:**
- `HbecAppBar`'s level-label lookup uses a fixed table of this platform's
  known `academic_level` codes (`zimsec_olevel` -> "O-Level", etc.) instead
  of web's live `GET /curriculum/levels/?exam_board=` call — these codes
  are a small, stable enum already documented in this repo's own root
  CLAUDE.md, not data expected to change per deployment.
- The remix-an-existing-paper capability (`POST /ai/papers/{id}/remix/`)
  that web's hook exposes is not wired into any Flutter UI yet — per the
  investigation, web's own `AiPapersPage` doesn't call it either (dead/
  future code there too), so there was no UI to replicate.
- `revision_list_page.dart` was found, during the header rollout, to be
  dead code (confirmed unreferenced by `router.dart` or anywhere else in
  `lib/`) — left untouched rather than given a profile icon for a page
  nothing can navigate to.

## Method
1. Forked research into web's `ExamPracticePage.tsx`, `PageHeader.tsx`
   (confirmed shared across 9+ pages — the reason "profile icon missing"
   was reported as an everywhere-problem, not a per-page one),
   `FeedbackWidget.tsx` (confirmed globally-mounted at the app root, same
   pattern as Friday, not header-attached), `AiPapersPage.tsx` +
   `GeneratePaperModal.tsx` + `generateApi.ts` (full endpoint/body/response
   shapes) + `useAiPaperGeneration.ts` (poll interval/budget/failure-status
   mapping), before writing any Flutter code.
2. Cross-checked Flutter's current state for each piece (confirmed: no
   shared header widget existed at all — 17 files build their own `AppBar`
   inline; Friday was a real route/tab, not an overlay; zero AI-generation
   plumbing anywhere in `lib/features/exam/`) so the plan named exactly
   what was net-new vs. reusable (e.g. `UserMenuButton` from the Nov-3
   dashboard work was directly reusable as the "profile icon," no new
   avatar-menu widget needed).
3. Built data layer first (entities -> datasource -> repository), verified
   `flutter analyze` clean, before writing any presentation-layer code —
   same phase discipline as the Nov-3 dashboard rebuild and the Settings
   rebuild earlier this session.
4. Fixed a real bug introduced mid-build: the generation-complete handler
   originally tried to pop an arbitrary number of routes with a nonsensical
   predicate; replaced with `BlocConsumer`-based dismissal scoped to the
   actual bottom-sheet context, verified by re-reading the corrected logic
   rather than assuming the fix was right.

## Decisions & Findings
- **One shared header widget, not elsewhere already existing on web's
  level of one component.** Flutter had no equivalent at all; rather than
  patch the "profile icon" into just Exam Practice (the page named in the
  report), rolled it out to every page found building its own `AppBar`
  except screens where it doesn't belong on web either (auth pages,
  onboarding, the in-progress `practice_page.dart` exam-taking screen —
  deliberately left untouched to avoid disrupting a focused test-taking
  flow with the user menu).
- **Friday and feedback are peers, not nested** — both are independent
  floating buttons mounted at the `MainTabScaffold` level (right and left
  respectively), matching web's actual DOM structure where both are
  mounted at the app root as siblings, not one inside the other or one
  inside a header.
- **Poll interval/budget copied exactly (3s / 220 polls), not
  approximated** — this number encodes a real constraint (the server's own
  600s job deadline plus margin); inventing a different value would either
  time out before the server does or poll needlessly past it.

## Changes Made
**New files:**
- `lib/shared/widgets/hbec_app_bar.dart` (`HbecAppBar`, `LevelBadge`,
  `academicLevelLabel`)
- `lib/shared/widgets/feedback_fab.dart`
- `lib/features/exam/domain/entities/ai_paper.dart`
- `lib/features/exam/presentation/bloc/ai_papers_cubit.dart`
- `lib/features/exam/presentation/widgets/generate_paper_modal.dart`
- `lib/features/exam/presentation/pages/ai_papers_page.dart`

**Modified:** `exam_repository.dart`/`_impl.dart`, `exam_remote_datasource.dart`,
`exam_practice_page.dart`, `select_paper_page.dart`, `paper_listing_page.dart`,
`main_tab_scaffold.dart` (5-tab -> 4-tab + two FABs), `router.dart` (new
`/exams/:subjectId/ai` route), plus the 6 pages given a profile-icon
`actions:` addition listed in Scope.

## Verification
- `flutter analyze`: clean (zero errors) after every phase (data layer,
  then each UI piece, then the header rollout).
- `flutter test`: same pre-existing single failure as every prior check
  this session (`login_page_golden_test.dart`, independently confirmed
  unrelated to this session's changes) — nothing newly broken.
- **Not yet done at time of writing:** live verification of the five new
  AI-generation endpoints against the real staging backend (none were ever
  called from Flutter before this change, so their exact response shapes
  are read from web's TypeScript types, not confirmed against a live
  response) — a `flutter run` against staging was in progress when this
  report was filed. This is the single biggest correctness risk in this
  change, same shape as the Nov-3 dashboard report's own flagged gap.

## Follow-ups / Deferred
- Live-verify the AI-generation flow end to end against staging (generate,
  poll, land on the new paper) once the current run confirms the app boots.
- `GeneratePaperModal`'s "My Custom Papers" empty/loading states weren't
  independently golden-tested; a visual check in the running app is the
  pending step.
- Wire `/curriculum/levels/` for an exact live level label if the fixed
  table in `academicLevelLabel` ever needs to cover a code not yet seen in
  this codebase's own documentation.
- `project_guide_page.dart`'s desktop/mobile branch (`isDesktop`) wasn't
  re-examined for whether the new `UserMenuButton` placement holds up on a
  desktop-width window — mobile-first verification was the priority given
  the target device.

## References
- Related session work: `HBEC-2026-11-05-web-flutter-parity-audit-tool.md`,
  the Friday-screen replica work, and the Settings-page replica work (same
  session, not yet separately filed as of this report).
- Key web files: `STUDENT/Frontend/src/features/exam-practice/pages/
  {ExamPracticePage,AiPapersPage}.tsx`, `.../components/{PaperTypeSelector,
  GeneratePaperModal}.tsx`, `.../api/generateApi.ts`, `STUDENT/Frontend/
  src/shared/components/PageHeader.tsx`, `STUDENT/Frontend/src/features/
  feedback/components/FeedbackWidget.tsx`.
- Key Flutter files: see Changes Made above.

---

**Completed By:** tinomupezeni (with Claude Code)
**Duration:** Same session as the Friday/home/Settings parity work
