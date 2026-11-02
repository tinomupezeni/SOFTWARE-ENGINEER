# Flutter Mobile Rebuild — Phase 0 Foundation

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** Architecture Decision / New Module Scaffolding
**Status:** Completed

## Summary
Decided to rebuild the CRM's mobile app in Flutter (replacing the existing
thin Expo/React Native app) to support an upcoming SME-wide push into POS and
stock management on both iOS and Android, then scaffolded Phase 0 of a
7-phase build plan: project setup, design tokens, networking layer, and a
working authenticated session flow, verified by a green test suite and CI
gate.

## Context / Trigger
Leadership asked for a serious push on SME tooling — POS, stock management,
WhatsApp ordering, AI automation (via an external partner) — with mobile
prioritized over web. The existing `mobile/` app (Expo + React Native) only
has thin contacts/sales/tasks tabs. The user explicitly distrusts React
Native's stability and asked for a Flutter vs. native Swift/Kotlin
comparison, then chose Flutter once both iOS and Android were confirmed as
targets (native would mean maintaining two codebases for a small team).

## Scope
Included: new `mobile_flutter/` Flutter project at the repo root, Cobalt Sky
theme (light/dark), Cubit-based auth feature (login, session persistence,
JWT refresh, logout) wired against the existing Django backend's real
`/api/v1/accounts/login/` and `/api/v1/auth/token/refresh/` contracts, a
go_router app shell with auth-aware redirects, unit/widget tests, and a new
`mobile` CI job.

Excluded: feature parity with the web frontend (contacts/deals/tasks/notes/
quotations — Phase 4), POS/checkout (Phase 3), the old `mobile/` Expo app was
left in place and untouched (to be retired once parity lands, not before).

## Method
1. Consulted the SOFTWARE-ENGINEER engineering guides before making any
   architecture call, per the repo's mandatory-guides rule:
   - `Principal_Engineer/engineering-guides/3. Mobile App Agent-First
     Development Guide.md` — feature-first layered architecture, Cubit over
     Riverpod/Provider/Signals for agent-driven codebases, constructor-based
     DI (no service locator), `Result<T>`/`Failure` typed error handling,
     Dio with retry+backoff+jitter, mocktail (zero-codegen) for tests.
   - `Principal_Engineer/engineering-guides/12. HCI.md` Section 19 (Mobile
     HCI) and Section 16/17 (Forms/Error Handling) — thumb-zone placement,
     48dp touch targets, top-aligned labels, validate-on-blur, redundant
     error indicators (border + icon + text, not color alone).
   - `Frontend_and_UI/theme.md` Combination 53 ("Cobalt Sky") for the color
     direction, cross-checked against the real hex/HSL values already used
     in `reports/SWAP-O-SELL-2026-10-15-implement-cobalt-sky-theme.md`.
   - `References/apple-design-skill/references/hig/design-principles.md`
     and `color.md` — informed the "approach every platform with intention"
     and light/dark/contrast guidance baked into the theme.
2. Read the existing Django backend (`backend/apps/accounts/`) directly
   rather than assuming an API shape, to get the exact login/refresh request
   and response contracts right on the first pass.
3. Scaffolded via `flutter create`, then built the foundation layer
   (theme, network client, token storage, auth feature) following the
   guide's prescribed patterns exactly, then wrote tests before considering
   the phase done.

## Decisions & Findings
- **Flutter over native Swift+Kotlin**: both platforms are required; a small
  team maintaining two native codebases doubles bug surface and velocity
  cost for marginal benefit. Flutter compiles to native ARM (no JS bridge),
  which directly addresses the user's stability concern with the prior
  React Native app.
- **State management**: Cubit (flutter_bloc), per the guide's explicit
  comparison table — lowest hallucination risk for agent-driven codebases,
  no code-gen dependency (ruled out Riverpod for the same reason).
- **Theme**: Cobalt Sky (`#2563EB` primary / `#1D4ED8` hover / `#0F172A`
  deep navy), semantic success/warning/error colors kept deliberately
  separate from the brand color per Apple HIG's color guidance.
- **Error handling**: sealed `Failure`/`Result<T>` types at the repository
  boundary; raw `DioException`s never reach the presentation layer.
- **DI**: explicit constructor wiring in `main.dart`'s composition root, no
  GetIt/service locator — matches the guide's reasoning that service
  locators let misconfigured dependencies slip past compile-time analysis.

## Changes Made
- New project: `mobile_flutter/` (Flutter app, `lib/core/*`,
  `lib/features/{auth,home,splash}/*`).
- `lib/core/theme/` — Cobalt Sky `ColorScheme`s (light+dark), 8dp spacing
  scale, 48dp minimum touch targets, top-aligned/validate-on-blur input
  theme.
- `lib/core/network/` — `DioClientFactory`, `AuthInterceptor` (JWT attach +
  transparent refresh-on-401), `RetryInterceptor` (exponential backoff +
  jitter for 5xx/timeout).
- `lib/core/error/` — `Failure` (sealed) and `Result<T>` types.
- `lib/core/storage/token_storage.dart` — `flutter_secure_storage`-backed
  token persistence.
- `lib/features/auth/` — full data/domain/presentation layers (login,
  session check, logout, forced-logout-on-expired-session), including a
  validate-on-blur `LoginScreen`.
- `lib/core/routing/app_router.dart` — go_router with auth-state-driven
  redirects (splash → login → home).
- `.github/workflows/ci.yml` — added a `mobile` job (`flutter analyze` +
  `flutter test`), alongside the existing `backend`/`frontend` jobs.
- Tests: `test/core/error/result_test.dart`,
  `test/features/auth/auth_cubit_test.dart` (bloc_test + mocktail),
  `test/features/auth/login_screen_test.dart` (widget tests, including an
  explicit 48dp touch-target assertion).

## Verification
- `flutter analyze` — 0 errors/warnings (7 remaining `info`-level
  initializing-formal style suggestions, left as-is to keep named-parameter
  constructors readable).
- `flutter test` — 10/10 passing (Result type, AuthCubit state transitions,
  LoginScreen validation/submission/touch-target).
- Not yet done: a real device/emulator run (no Android emulator or iOS
  simulator was available in this environment — only Linux desktop and
  Chrome web targets were detected by `flutter devices`; Android SDK
  licenses are also unaccepted). This is a known gap, not a passed check.

## Follow-ups / Deferred
- Accept Android SDK licenses / set up an emulator (or physical device) and
  do a real on-device run before Phase 1 is considered verified end-to-end.
- Phase 1 (Stock & Products), Phase 2 (POS/checkout — the pilot-critical
  phase for the boss's test machine), Phase 3+ per the 7-phase plan agreed
  with the user.
- Retire `mobile/` (Expo/RN) once feature parity is reached — not before.
- Push the phased plan + KPIs into ProjectFlow once that service is back up
  (it returned `Connection refused` earlier this session).

## References
- `Principal_Engineer/engineering-guides/3. Mobile App Agent-First
  Development Guide.md`
- `Principal_Engineer/engineering-guides/12. HCI.md`
- `Frontend_and_UI/theme.md`
- `References/apple-design-skill/references/hig/design-principles.md`,
  `References/apple-design-skill/references/hig/color.md`
- `reports/SWAP-O-SELL-2026-10-15-implement-cobalt-sky-theme.md`
- `/home/shadowe/Projects/crm/mobile_flutter/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
