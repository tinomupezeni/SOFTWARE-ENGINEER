# Flutter Dashboard Full Feature-Parity Rebuild — Phases 1–4

**Date:** 2026-11-03
**Project:** HBEC (STUDENT/mobile_flutter)
**Type:** Scope Decision / Feature Build
**Status:** Completed (all 4 phases; see "Phase 3–4 addendum" below for the
part done after this report was first filed as an in-progress checkpoint)

## Summary
The Flutter mobile app's `DashboardPage` was a static placeholder (hardcoded
zero-value stats, non-data-driven quick actions, a "Get the Mobile App"
banner that made no sense inside the app itself) while the web app's
Dashboard had evolved into a feature-rich gamified experience (XP/streak,
achievements, leaderboard, a curriculum "learning trail" hero, analytics
panel). The user asked for pixel-and-feature parity. This explicitly
supersedes an earlier, separate scope note that had treated gamification as
a deferred "fast-follow" rather than v1 scope — the user chose full parity
now when presented with the real size of the gap.

## Context / Trigger
Mid-session visual/functional parity audit of the Flutter rewrite against
the web app (ongoing multi-screen audit: login already rebuilt earlier this
session). Reading web's `Dashboard.tsx` revealed the dashboard gap was not
cosmetic — three entire feature domains (gamification, analytics,
notifications) had no Flutter implementation at all. This was surfaced to
the user before any implementation began, with a scoped-options question;
the user chose full parity over a lighter placeholder-only approach.

## Scope
**Included (this report covers Phases 1–2 of a 4-phase plan):**
- Phase 1: Data layer (entities, repositories, use cases, BLoCs, DI wiring)
  for three new domains — `gamification`, `analytics`, `notifications` —
  following the existing `subscription` feature's established pattern
  (Dio direct in repository impl, no separate datasource layer, `Result<T>`
  sealed return type, use-case-per-action).
- Phase 2: Dashboard UI shell rebuilt to web's top-to-bottom structure:
  header (back button, title, NotificationBell with unread badge, UserMenu
  with Dashboard/Profile/Logout), subscription status card (reusing the
  already-wired `SubscriptionBloc`), data-driven Quick Actions grid (ported
  `pillarsFor` grade-gating logic), StreakToday, AchievementGrid +
  Leaderboard, a collapsible "Your full stats" section (stats panel +
  analytics stat tiles/lists + existing Learning Profile grid), and removal
  of the nonsensical in-app "download the app" banner.

**Explicitly excluded from Phases 1–2 (deferred to later phases, not
overlooked):**
- `LearningTrailHero` (SVG curriculum trail, avatar picker, dropout-risk
  "fog" effect) — left as a clearly labeled placeholder card. This single
  widget is roughly as complex as the rest of the dashboard combined and is
  scoped as its own Phase 3.
- Charting (`fl_chart` or similar) — no chart package exists in the Flutter
  app yet; `LearnerAnalyticsPanel` ships with stat tiles/lists only for now.
  Adding a charting dependency is a decision flagged for the user rather
  than silently added.
- `SubjectCanvas` (decorative seeded-SVG background) and `RoadSlot` (a
  React DOM-portal mechanism for a global XP strip) — judged low-value/
  infra-only; web parity does not visibly suffer by skipping a literal port
  of either.
- Per-grade pillar copy variants (`junior`/`bridge` wording) — only the
  `default` copy variant was ported; grade-specific microcopy nuance is a
  follow-up, not a blocker.
- `/notifications` full-page route and `interactive-learning` route — both
  show reasonable fallbacks (bottom-sheet-only list; "coming soon" snackbar)
  pending those routes/features existing elsewhere in the app.

## Method
Two research-then-build passes, each split into parallel/sequential forked
agents to manage context size given the scale of this screen:
1. Read web's `Dashboard.tsx` directly, then forked agents to (a) read every
   sub-component on the web side for exact layout/colors/API shapes, and
   (b) audit the current Flutter app's conventions (DI container, BLoC
   wiring, router, existing feature file-layout pattern) so new code would
   match house style rather than invent a new one.
2. Implemented Phase 1 (data layer only, no UI) as an isolated, verifiable
   unit; confirmed `flutter analyze` clean and file scope contained to the
   three new feature folders plus minimal DI/`main.dart` wiring before
   starting Phase 2.
3. Implemented Phase 2 (UI) on top of the verified Phase 1 data layer,
   re-reading the actual web component source (not just the earlier text
   summary) before building each Flutter counterpart, to avoid compounding
   approximation error across two passes.
4. After each phase, verified file-scope containment via `git status`/`git
   diff --stat` before treating the phase as done — this caught nothing
   wrong, but is the check that would have caught scope creep if the agent
   had touched unrelated files.

## Decisions & Findings
- **Full feature parity, not a staged placeholder approach** — user's
  explicit choice when shown the real gap (three missing domains, not just
  a styling mismatch).
- **Backend endpoint paths are unverified assumptions, not confirmed
  contracts.** The web app's gamification/analytics endpoints
  (`/v1/analytics/gamification/{dashboard,visit,achievements,subjects,
  leaderboard}`, `/ai/analytics/{report,velocity,spaced-repetition,
  next-actions}/`, `/v1/notifications...`) were inferred from frontend
  TypeScript usage, not read directly from backend serializers/routers (out
  of scope — "strictly don't change anything on the backend" also meant not
  spending the session reading backend code in depth). Every Flutter model
  parses defensively (null-safe, snake_case/camelCase fallback) so a wrong
  field degrades to an empty/zero value instead of crashing, but **displayed
  gamification/analytics values should be treated as unverified until
  checked against real staging API responses.** This needs either a
  dedicated verification pass with a real staging login, or backend-side
  confirmation of exact serializer field names and base path.
- **`paymentsDisabled` has no Flutter equivalent yet** — the subscription
  card always renders in Flutter; web conditionally hides it. Minor,
  flagged rather than silently diverging without a note.
- Reused `AppColors` token mapping (already confirmed to match web's
  HSL-based Tailwind tokens from earlier in this session) rather than
  reverse-engineering colors again; added two new tokens
  (`interactiveBase`/`interactiveLight`) converted the same way.

## Changes Made
**Phase 1 — new files (18), `lib/features/{gamification,analytics,
notifications}/{domain/{entities,repositories,usecases},data/{models,
repositories},presentation/bloc}/*.dart`; modified:** `lib/core/di/
injection.dart` (+63 lines: 3 repos, 14 use cases, app-lifetime
`gamificationBloc` singleton matching the existing `subscriptionBloc`
pattern), `lib/main.dart` (+8 lines: new BLoCs added to the app-wide
`MultiBlocProvider`).

**Phase 2 — new files:** `lib/features/home/presentation/widgets/
dashboard_header.dart`, `dashboard_pillars.dart`, `streak_today_card.dart`,
`achievement_grid.dart`, `leaderboard_card.dart`, `progress_stats_panel.dart`,
`learner_analytics_panel.dart`, `learning_trail_placeholder.dart`.
**Modified:** `lib/features/home/presentation/pages/dashboard_page.dart`
(full rebuild to web's section order), `lib/core/theme/app_colors.dart`
(+4 lines, two new color tokens).

No backend code touched, per the standing project constraint.

## Verification
- `flutter analyze`: clean after both phases (zero errors; only pre-existing
  `info`-level style suggestions already present elsewhere in the codebase).
- `flutter test`: all existing tests pass (11 passed, 1 pre-existing skip
  that requires a live dev backend).
- File-scope containment verified via `git status`/`git diff --stat` after
  each phase — changes limited to the new feature folders plus the minimal
  DI/router/theme touch points named above.
- **Not yet done:** live visual verification against the real staging
  backend (no test-account credentials with completed onboarding were
  available in this environment to click through the rendered dashboard),
  and no confirmation of the gamification/analytics endpoint paths/field
  names against actual backend code or live responses.

## Follow-ups / Deferred
- Phase 3: `LearningTrailHero` (SVG trail, avatar picker, topic-mastery
  nodes from real progress data, exam-readiness fog).
- Phase 4: achievement rarity/badge-carousel polish, charts (requires an
  `fl_chart`-or-equivalent dependency decision), notification popover
  interactions, golden tests for the new dashboard.
- Verify gamification/analytics/notifications endpoint paths and response
  field names against actual backend serializers or a live staging login —
  flagged above as the single biggest correctness risk in this work.
- Surface `personalization.studyPlan.dailyGoal` on Flutter's `User`/
  `PersonalizationCubit` so `StreakToday`'s goal isn't hardcoded to 3.
- Decide whether/how to expose `paymentsDisabled` equivalently in Flutter's
  subscription state.
- Per-grade pillar copy variants (`junior`/`bridge`) if full microcopy
  parity is wanted later.

## References
- Related: login page rebuild (same session, same screen-by-screen parity
  audit, not yet separately logged).
- Key files: `STUDENT/Frontend/src/pages/Dashboard.tsx` and its
  `src/features/gamification/components/*` (web reference);
  `STUDENT/mobile_flutter/lib/features/{gamification,analytics,
  notifications,home}/` (Flutter implementation).

## Phase 3–4 addendum (same session, filed after this report's initial commit)

**Phase 3 — `LearningTrailHero`:** Implemented as a `CustomPainter`-based
trail (same 1160×320 viewBox, margins, amplitude and sine node placement as
web's SVG, reimplemented rather than approximated with a generic curve),
with mastered/current/ahead node states, the exam-readiness fog overlay
(opacity 0.85/0.45/0.06 by dropout-risk level, matching web), subject
picker, neglected-subject nudge, all four empty/edge states, and the footer
CTA. Two minimal, flagged additions on top of Phase 1: `LearnerReport.
examReadiness` (nullable, parsed defensively) and wiring Phase 1's
already-defined-but-never-loaded `GetSubjectProgressUseCase` into
`GamificationBloc`. Reasonable adaptations where Flutter has no backing
feature yet: a local 8-icon avatar picker (persisted via secure storage)
instead of web's synced avatar system, and subject-level (not topic-level)
CTA routing since the revision feature has no topic-id route param.

**Phase 4 — polish:** Achievement rarity colors/family labels corrected to
match web's actual values (legendary `#FBBF24`, epic `#C084FC`, rare
`#60A5FA`); a real subject-mastery bar visualization and peak-study-hours
chips added to the analytics panel. **Deliberately did not add `fl_chart`**
— hand-rolled bar/progress visuals already deliver genuine chart-shaped
parity from real data with zero new dependency risk, which mattered given
how much Linux-toolchain pain (`clang`/`ninja`/`libsecret`/CMake-cache
issues) this session already absorbed getting the Flutter Linux build
working in the first place. Notification tap-to-read/dismiss/clear-all
turned out to already be fully wired from Phase 2 — verified by reading the
bloc, not assumed. Added golden tests for the three new pure-props widgets
(`AchievementGrid`, `StreakTodayCard`, `ProgressStatsPanel`); a full-page
`DashboardPage` golden was judged impractical since the page reads the
`getIt` DI singleton directly rather than via an injectable `BlocProvider`,
and no `getIt`-stubbing test harness exists yet in this codebase — a
reasonable follow-up if page-level goldens are wanted later.

**Final verification (all 4 phases):** `flutter analyze` clean (zero
errors, only pre-existing-style `info`s). `flutter test`: 17 passed, 1
pre-existing skip requiring a live backend — nothing newly broken across
any phase. File-scope checked after every phase via `git status`/`git diff
--stat`; all changes stayed within the new feature folders plus the same
small set of wiring/theme touch points named above.

**The one thing that did NOT get done, by explicit user choice mid-session:**
live verification against a real staging login. The user was asked whether
to pause and verify live before Phase 4, or keep building; they chose to
keep building. This means the single biggest correctness risk flagged
throughout this report — unverified gamification/analytics endpoint paths
and field names — is still unverified as of this report's completion. A
live-data pass against staging is the clear next action before this feature
set should be considered production-ready, not merely "code complete."

---

**Completed By:** tinomupezeni (with Claude Code)
**Duration:** ~1 session (research + four implementation phases)
