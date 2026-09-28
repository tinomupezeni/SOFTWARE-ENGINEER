# CanopyRx Phase 2 Mobile Scaffold (offline diagnosis vertical)

**Date:** 2026-09-28
**Project:** CANOPYRX
**Type:** Architecture Decision / Scope Decision
**Status:** Completed

## Summary
Built the offline-first mobile vertical in `apps/mobile` (Flutter, feature-first, Cubit+Drift): dual-capture UI with framing guides, Dart port of the triage matrix, repository persisting scan+prescription+sync-outbox rows, prescription card. Gates genuinely green: analyze clean, format clean, 21/21 tests, debug APK compiles.

## Context / Trigger
Phase 2 of `docs/planning/project-plan.md`. Inference is mocked behind an `InferenceSource` seam until the Phase-1 model spike lands; camera capture is simulated until device testing.

## Scope
Included: scaffold, triage Dart port, Drift schema (crops/scans/prescriptions/sync_queue), mock inference, repository, cubit, capture screen, prescription card, unit+widget+golden+leak tests, debug APK. Excluded: camera plugin, live TFLite, release-size budget, on-device latency numbers (all need a physical target device).

## Method
Guide 3 conventions (feature-first, Cubit UDF, constructor DI, Result, no codegen for models; Drift codegen accepted for tables as the guide's own recommendation). Single-source-of-truth: `assets/triage_rules.json` mirrors the Python file, and Dart tests read the Python original.

## Decisions & Findings
- Drift over raw sqflite (guide's relational pick); `NativeDatabase.memory()` keeps repo tests hermetic.
- Client UUIDs (`uuid` pkg) as sync idempotency keys per ADR-004; scan+prescription+outbox written in one transaction.
- Real bugs caught by tests, all fixed: (1) badge Row overflowed 89px on narrow widths → Flexible label (genuine small-phone robustness fix, apple-design Flexibility); (2) flow-test taps silently missed off-screen buttons → `ensureVisible` before every tap, rule added to EngineerApproach DoD; (3) alchemist renders builders unbounded → one `GoldenTestScenario` per test, not raw SizedBox/group grids.
- Import-path discipline: several wrong relative imports on first pass — analyzer caught all; agent rule restated (explicit absolute-style `package:` imports preferred).
- Debug APK builds (159MB debug fat — expected; release split-ABI sizing is a follow-up).

## Changes Made
CANOPYRX (uncommitted, per only-commit-when-asked): `apps/mobile/` full scaffold — `lib/{main,core/{result,database},features/diagnosis/{domain,data,presentation}}`, `assets/triage_rules.json`, 6 test files + 4 golden baselines, `EngineerApproach.md` DoD +1 rule.

## Verification
- `flutter analyze`: No issues found. `dart format --set-exit-if-changed`: clean.
- `flutter test`: 21/21 (9 triage-parity incl. FAW 0.2 boundary, 3 repo incl. throw-path with zero rows, 2 card widget, 2 cubit, 1 leak-tracked full flow, 4 golden variants).
- `flutter build apk --debug`: success.
- Golden baselines committed alongside code (light+dark × CI+Linux).

## Follow-ups / Deferred
- Camera plugin + live viewfinder reticle (needs device); TFLite source behind `InferenceSource`; release APK size budget + on-device latency (needs target device + Phase-1 model); backend sync API (Phase 3); commit CANOPYRX when asked.

## References
- ADR-001 (Flutter), ADR-004 (offline sync); PRD US-1/2/5/6; prior reports `CANOPYRX-2026-09-28-gate1-foundations.md`, `CANOPYRX-2026-09-28-phase1-triage-spike.md`

---

**Completed By:** OpenCode (Muse Spark)
**Duration:** ~1 session
