# HBEC Code Review & Promotion Batch (PRs #160 and #162)

**Date:** 2026-11-20
**Project:** HBEC
**Type:** Code Review / Refactor / Reliability Audit
**Status:** Completed

## Summary
Conducted formal code reviews for open HBEC pull requests #160 and #162 using Principal Engineer Guide #24 ("Code Review"). Identified a blocking merge conflict and missing telemetry instrumentation on #160 (requested changes). On #162, identified and fixed an unhandled check-then-act concurrency race condition in the ingestion review queue, validated with new regression tests, ran full suite verification across harness, admin backend, and frontend against isolated Postgres, and promoted #162 commits to `master` (`5ab7b34b5`).

## Context / Trigger
User requested systematic code review of open PRs (#165, #164, #163, #162, #160) against Guide #24 to evaluate readiness for merge, resolving fixable bugs in-flight and returning architectural decisions to authors.

## Scope
- PR #160 (`fix/paper-figures`)
- PR #162 (`refactor/explicit-state-machines`)
- Excluded (deferred to next stages): PR #163, #164, #165.

## Method
1. Read Guide #24's Master Checklist, Change Risk Score (CRS), and defect taxonomy.
2. Inspected diffs, git commit trees, and previous review comments.
3. Spun up temporary throwaway PostgreSQL test instance (`pr-test-pg`) on port 57034.
4. Ran deterministic test suites across Python/Django, FastAPI/LangGraph, and TypeScript/Vitest.
5. Applied in-flight bug fixes for code-level defects (concurrency races) while leaving architectural concerns for authors.
6. Promoted clean, verified commits to `master`.

## Decisions & Findings
- **PR #160:** Blocked due to merge conflict in `research/long_term_memory.md`, lack of CI test evidence, and telemetry violations against `AGENTS.md` (missing trace context propagation and JSON log schemas in `refresh_paper_figures`). Requested changes on GitHub.
- **PR #162:** Evaluated implicit state machine refactoring. The core design was verified sound. Discovered check-then-act race in `ReviewQueueItemView.post` where concurrent approvals/rejections could bypass review guards. Implemented atomic `_claim` update returning HTTP 409 on loss of race. Verified claim-token picture store DB tests (13/13 pass), admin gate tests (10/10 pass), and student frontend vitest suite (363/363 pass).
- Promoted #162 to `master` as 8 cherry-picked commits culminating in `5ab7b34b5`.

## Changes Made
- Created bug dev-log `Backend_and_API/HBEC-2026-11-20-review-queue-concurrent-approval-race.md`.
- Updated `Project_Memory/HBEC/MAIN.md` with master commit `5ab7b34b5`.
- Updated PR #162 branch with atomic claim commit `4d7ce4fe8`.
- Promoted verified commits to HBEC `master`.

## Verification
- `tests/shared/test_picture_store.py`: 13 passed in isolated Postgres.
- `apps/exam_papers/tests/test_review_queue_publish_gate.py`: 7 passed.
- Student Frontend vitest: 57 test files, 363 tests passed.

## Follow-ups / Deferred
- Review and evaluate PR #163 (`feat/friday-web-research`).
- Await PR #160 author resolution of telemetry standards and merge conflicts.

---

**Completed By:** Antigravity
**Duration:** ~1.5 hours
