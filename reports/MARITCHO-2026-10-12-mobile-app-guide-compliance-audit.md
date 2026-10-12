# MARITCHO Flutter Mobile App — Compliance Audit Against the Mobile App Agent-First Development Guide

**Date:** 2026-10-12
**Project:** MARITCHO
**Type:** Audit
**Status:** Completed

## Summary
Audited the full `mobile/` Flutter app (foundation, Accounts, Employer flow, Worker flow — everything built across this project's mobile phases, plus the pre-existing offline-sync scaffold) against `Principal_Engineer/engineering-guides/3. Mobile App Agent-First Development Guide.md`'s Appendix B checklist. The app is strongly compliant on architecture, state management, DI, null-safety, and async-gap discipline. It has six real gaps, all additive (nothing needs to be torn out): no mobile CI pipeline, no network retry/circuit-breaker layer, no crash-reporting/telemetry layer, no golden tests, no `RestorationMixin` usage, and — the most consequential one given this project's own "offline-first" architectural mandate (`AGENTS.md`) — the new feature screens (Accounts, Employer flow, Worker flow) call the API directly with no local cache, unlike the pre-existing check-in/photo flow which already has a working offline-sync engine they don't reuse.

## Context / Trigger
User request: "look in software engineer repo, and check for a mobile app development guide, we want to use it to check if the full mobile app is guide compliant." Guide 3 (`3. Mobile App Agent-First Development Guide.md`) was the match — confirmed via the MANIFEST. MARITCHO was not yet listed in that guide's `applies_to` mapping table at audit time.

## Scope
**Included:** every file under `mobile/lib/` and `mobile/test/`, `pubspec.yaml`, `analysis_options.yaml`, and `.github/workflows/` (repo-wide, to check for a mobile CI job). Covers both code built this session (networking/DI foundation, Accounts, Employer flow, Worker flow) and the pre-existing scaffold it builds on (`sync_service.dart`, `database_helper.dart`, `check_in_repository.dart`, `photo_repository.dart`, `job_execution_*`, theming).

**Excluded:** actually implementing the fixes — this pass is audit/report only, per the user's framing ("check if ... guide compliant"). Fixes are listed under Follow-ups for the user to prioritize. Also excluded: the second, stack-agnostic accessibility-focused guide spotted near the MANIFEST's accessibility section — out of scope for "mobile development guide" specifically; worth a separate pass if the user wants WCAG compliance checked too.

## Method
Read the guide in full, then worked through its Appendix B checklist (8 sections) against the actual codebase using targeted greps and reads rather than a file-by-file narrative: directory structure, state-management shape, DI pattern, `late`/`!` usage, dispose/mounted discipline, Dio client internals, `analysis_options.yaml`, test file mocking approach, and `.github/workflows/` presence.

## Decisions & Findings

**Checklist §1 Architectural Foundations — Compliant.** Feature-first layout (`features/<name>/data|domain|presentation`) throughout; every screen uses a Cubit/State pair with immutable states; every repository and cubit takes its dependencies via constructor arguments — no `GetIt` or any service locator anywhere in `lib/` or `pubspec.yaml`.

**§2 Data Flow and State Integrity — Partially compliant, one real gap.** The `Result<T, Failure>` pattern (pre-existing, `core/error/`) is functionally equivalent to the guide's sealed-class pattern (an `abstract class` with `is`-checks and a `.fold()`/`.match()` API, rather than a `sealed class` with `switch` — a reasonable, already-working equivalent, not worth changing). `RestorationMixin` is not used anywhere — no screen survives process death with its in-progress form state. **The substantive gap:** none of this session's new screens (Post Job, Applicants, Job Tracking, Worker Skills, My Work, Job Detail) go through the local database at all — they call `JobsRepository`/`WorkersRepository`/`AuthRepository` straight over Dio with no cache-first read or optimistic-update/rollback. Only the pre-existing check-in/photo feature (`check_in_repository.dart`, `photo_repository.dart`, via `SyncService`/`DatabaseHelper`) is offline-first. This matters more here than the guide's generic treatment, because `AGENTS.md`'s own General Architectural Rules state "Prioritize offline-first constraints (WhatsApp integration, PWA)" and "Assume inexpensive Android devices and small data bundles" as standing, unconditional rules for this project — not just a nice-to-have from the guide.

**§3 Core Software Engineering — Compliant.** No unguarded `!` anywhere (the two uses found, in `applicants_page.dart` and `job_detail_page.dart`, are both inside a preceding `!= null`/`if (... != null)` check — safe, not the anti-pattern). The two `late` uses in `worker_skills_page.dart`/`post_job_page.dart` are `late final Future<...>` initialized exactly once in `initState`, the legitimate use case, not the risky kind the guide warns about. The one `late` use in the pre-existing, already-flagged `apple_surface.dart` (animation controller) predates this session and was out of scope each time it came up before. `Failure`/`Result` are used consistently; no raw exceptions leak to the presentation layer. **Gap:** `analysis_options.yaml` does not set `strict-casts`/`strict-inference` (checklist item: "Code passes analysis checks with strict-casts and strict-inference set to true") — it only includes the stock `flutter_lints` package with no `language:` analyzer section.

**§4 Stability Engineering — Two real gaps.** Dispose/mounted discipline is excellent: every new screen with a controller has a matching `dispose()`, and every post-`await` context use in a State class is guarded by an explicit `if (!mounted) return;` (several carry a `// Engineering Standard: Async Gap Safety` comment, suggesting this was already a deliberate convention, not accidental). **Gaps:** (1) `core/network/api_client.dart`'s `buildApiDio` has no retry interceptor and no circuit breaker — a single `InterceptorsWrapper` that only injects the bearer token. Every API call is one-shot; a dropped connection on a flaky network (the exact condition `AGENTS.md` names as a design target) surfaces as a raw failure with no retry. (2) No crash-reporting/telemetry layer exists anywhere in `mobile/` — no Crashlytics (or equivalent) integration, so there's nothing to apply the guide's PII-scrubbing requirement to yet; this is a missing capability, not a leak of unscrubbed data.

**§5 Testing Methodology — Compliant in spirit, one literal deviation, one real gap.** Cubit tests assert on final `cubit.state` after `await`ing the action (this session's own established, deliberate pattern — see the dev-log precedent on stream-assertion flakiness) rather than asserting on a captured stream sequence; this satisfies AAA structure and the "testable, low-overhead" spirit of the guide's BLoC recommendation. Mocking uses hand-written fake subclasses (e.g. `_FakeJobsRepository extends JobsRepository`) rather than the guide's specifically recommended `mocktail` package — functionally zero-codegen either way, so not a problem worth fixing, but a literal checklist mismatch worth naming. **Gap:** no golden tests exist anywhere (`alchemist` isn't a dependency) — nothing verifies layout across themes/breakpoints; given `AppTheme` currently only has a light theme, dark-theme golden coverage isn't applicable yet, but light-theme layout goldens for the now-sizeable screen set are entirely absent.

**§6 Debugging Methodology — Not assessable from static audit** (DevTools/platform-channel workflows are runtime practices, not something a code read can confirm or deny); no anti-patterns found (no heavy compute inside `build()` methods in any audited file).

**§7 CI/CD and Release Stability — One real gap.** `.github/workflows/` contains only `backend-ci.yml` — there is no mobile verification pipeline (`flutter analyze` / `dart format --set-exit-if-changed` / `flutter test` / build) anywhere in the repo, so the guide's recommended "Mobile Verification" GitHub Actions job (lint/format/test/build on every PR) does not exist yet for this project.

**§8 Working with AI Coding Agents — Compliant.** No barrel/`index.dart` files anywhere in `lib/`; imports are direct and explicit. Page files occasionally contain 2–6 widget classes, but the extras are small private helpers (e.g. `_MetaColumn`) alongside the one real page widget, not multiple unrelated major widgets sharing a file — consistent with the checklist's intent ("one widget per file" as in "one feature-owning widget," not a ban on tiny private helper widgets). `AGENTS.md` already exists at the project root and already contains, verbatim, the guide's own "Agent Configuration Reference" block (Core System Conventions / Structural Rules / Verification Protocol) — this project adopted that section of the guide before this audit, which is why the architectural findings above came back as clean as they did.

## Changes Made
None — this pass is audit/report only, per scope above.

## Verification
Findings were derived directly from the current repository state (greps and reads run against `mobile/` at commit `b2f7008`), not from memory of what was built — e.g. the `late`/`!` greps were manually inspected line-by-line to rule out false positives (both `!` hits and all four `late` hits were confirmed benign on inspection, not just counted).

## Follow-ups / Deferred
In rough priority order, none started yet — the user has not yet said whether to fix these now or backlog them:
1. **Offline-first for the new screens** — the most significant gap relative to this project's own standing architectural rule. Would mean extending `SyncService`/`DatabaseHelper` (or a lighter cache-first read pattern) to `JobsRepository`/`WorkersRepository`/`AuthRepository`, likely sizable given six new screens.
2. **Network retry + circuit breaker** in `buildApiDio` — small, mechanical, matches the guide's own worked example almost directly.
3. **Mobile CI workflow** — small, mechanical, can mirror `backend-ci.yml`'s structure with the guide's own worked YAML.
4. **`strict-casts`/`strict-inference`** in `analysis_options.yaml` — small, but will likely surface new `flutter analyze` findings to clean up once enabled.
5. **Golden tests** (`alchemist`) for the now-substantial screen set — medium effort, new dev dependency.
6. **Crash-reporting/telemetry layer** — not yet started at all; likely the largest of the "missing capability" gaps besides offline-first, since it requires picking and wiring a provider (Crashlytics or equivalent) from scratch.
7. Consider adding MARITCHO to Guide 3's `applies_to` mapping table in the MANIFEST, now that it has formally absorbed this guide.

## References
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/3. Mobile App Agent-First Development Guide.md`
- `/home/shadowe/Projects/MARITCHO/AGENTS.md` (already contains the guide's Agent Configuration Reference block, plus the project's own offline-first/inexpensive-device rules this audit weighed the findings against)
- `/home/shadowe/Projects/MARITCHO/mobile/` (audited in full)

---

**Completed By:** Claude Code (mobile guide-compliance audit session)
**Duration:** ~20 minutes
