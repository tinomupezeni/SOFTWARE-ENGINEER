# CanopyRx Gate 1 Foundations (Vision → PRD + ADRs + Plan)

**Date:** 2026-09-28
**Project:** CANOPYRX
**Type:** Architecture Decision / Scope Decision
**Status:** Completed

## Summary
Closed SDLC Gate 1 for the CanopyRx greenfield: git init + docs skeleton, Business Case + PRD with BDD acceptance, ADR-001..004 (Flutter+Cubit+Drift; FastAPI+PostGIS; dual on-device models; offline outbox sync), EngineerApproach, 6-week project plan, risk register, and a Day-1 tooling gate run.

## Context / Trigger
Repo held only `Vision.md`, no git, no PRD/ADRs. User chose "Foundations first", Flutter, FastAPI+PostGIS after structured scoping per WORKING-PROCESS + feature_request_to_delivery Phase 1.

## Scope
Included: Gate 1 exit docs + repo skeleton + toolchain proof. Excluded: any model/mobile/backend code, OpenAPI sync schema, SDD (all Phase 1–3 work, deliberately deferred).

## Method
SDLC lightweight (Gate 1) + MANIFEST rewiring (guides 1, 3, 6, 10, 15 as pulled parts, not whole-guide copies) + apple-design/planning constraints noted for later phases + WORKING-PROCESS classify→research→align→implement→verify.

## Decisions & Findings
- Flutter over RN-Expo: agent-parseable structure, Cubit UDF, Drift offline story (ADR-001).
- FastAPI+PostGIS over Django: async batch ingest, ML-native, small-team ops fit (ADR-002).
- YOLOv8n int8 + MobileNetV4-Small dual-model with versioned deterministic fusion; no single-photo prescriptions (ADR-003).
- Drift/SQLite outbox client-side, idempotent UUID batch POST, HTTPS-only v1 (ADR-004).
- Tooling catch: system python3 has no pip/ruff/mypy; ruff 0.16.9 + mypy 2.3.1 installed via pipx. Backend scaffold must use project venv — recorded in `docs/testing/tooling-gate.md`.

## Changes Made
CANOPYRX (uncommitted, per only-commit-when-asked): `README.md`, `.gitignore`, `docs/discovery/vision.md + business-case.md`, `docs/requirements/PRD.md`, `docs/architecture/adr/ADR-001..004`, `EngineerApproach.md`, `docs/planning/project-plan.md + risk-register.md`, `docs/testing/tooling-gate.md`.

## Verification
- `flutter --version` (3.47.5), `dart` (3.13.4), `pytest` (9.0.2), `docker` (29.8.0), pipx `ruff`/`mypy` all executed this session.
- No code yet so lint/type/test gates have nothing to enforce — re-run mandated at first triage-spike and mobile-scaffold commits.

## Follow-ups / Deferred
- Phase 1 triage spike (`triage_rules.json` + Python + pytest, US-3/US-4) — next.
- SDD + OpenAPI sync schema before Phase 3; apple-design review of capture/prescription UI in Phase 2; commit CANOPYRX when user asks.

## References
- CANOPYRX `Vision.md`, `docs/requirements/PRD.md`, `docs/architecture/adr/`, `EngineerApproach.md`
- Guides: `1. SDLC.md`, `3. Mobile App Agent-First`, `MANIFEST.md`, `WORKING-PROCESS.md`, `Lessons/planning/procedural/{feature_request_to_delivery,pre_deploy_verification}.md`

---

**Completed By:** OpenCode (Muse Spark)
**Duration:** ~1 session
