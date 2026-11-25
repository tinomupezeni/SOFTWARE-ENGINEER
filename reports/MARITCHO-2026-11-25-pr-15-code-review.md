# MARITCHO: PR #15 Code Review - Shareable Job Links (WEB-024) & Follow-ups

**Date:** 2026-11-25
**Project:** MARITCHO
**Type:** Code Review
**Status:** Completed

## Summary
Comprehensive code review of Pull Request #15 ("feat: shareable job links (WEB-024), plus pricing modes & job editing (WEB-023) and PR #14 follow-up fixes") against the Engineering Code Review Standard (`24. Code Review.md`) and project conventions in `AGENTS.md`.

The PR consists of 25 changed files (+908, -11 lines) across backend and frontend implementing public job share links (`/j/[jobId]`), link preview image generation (`1200x630` PNG OpenGraph cards), safe client-side redirection with open redirect protections (`?next=`), and accompanying integration tests.

## Context / Trigger
User requested an engineering review of PR #15 on repository `Rest-creator/MARITCHO` using the Principal Engineer code review framework (`24. Code Review.md`).

## Scope
- Base branch: `main` (commit `56e0a4f`)
- Head branch: `origin/experimental` (commit `d7cfa0c`)
- Evaluated components:
  - Backend: `GET /jobs/{job_id}/share`, domain entity `JobShareSummary`, `GetJobShareSummaryUseCase`, telemetry spans and JSON logging.
  - Frontend: `/j/[jobId]/page.tsx`, `/j/[jobId]/opengraph-image.tsx`, `job-share.ts`, `ShareJobButton.tsx`, `SharedJobScreen.tsx`, and open-redirect sanitization in `next-path.ts`.
  - Contracts & Architecture: `docs/architecture/openapi.yaml`, privacy safeguards under ADR-004.
  - Quality verification: unit tests, Next.js production build (`next build`), ESLint, Ruff linting/formatting.

## Method
Evaluated changes across the standard 12 review vectors defined in `24. Code Review.md`:
1. Intent & Alignment
2. Correctness & Invariants
3. Security & Boundary Defense (specifically Open Redirect and Data Leakage)
4. Data & Persistence Impact
5. Architecture & Clean Boundaries
6. Observability & Telemetry
7. Performance & Resource Bounds
8. Error Handling & Edge Cases
9. Contract Integrity & Documentation
10. Testing & Evidence
11. Usability & Accessibility
12. Operational Safety & Rollback

## Decisions & Findings

### Strengths & Commendable Implementations
1. **Privacy-First Data Teaser (ADR-004 Compliance):**
   - The backend endpoint `GET /jobs/{job_id}/share` deliberately emits a strictly stripped `JobShareSummary` (`job_id`, `trade`, `suburb`, `needed_by`, `pricing_mode`, `is_open`, `created_at`).
   - Private attributes (buyer ID, exact address, landmarks, GPS coordinates, problem description, photos, budget amounts) are never serialized.
   - Negative assertions in `backend/tests/test_job_share.py` explicitly verify that sensitive buyer info and descriptions do not leak in the response body.
2. **Defensive Open Redirect Sanitization:**
   - `safeNextPath` in `frontend/src/core/session/next-path.ts` rigorously validates `?next=` parameters, rejecting non-slash paths, protocol-relative URLs (`//`), Windows backslashes (`\`), non-printable control characters, and excessively long inputs (>512 chars).
3. **Optimized Metadata & Social Sharing:**
   - Uses `react.cache` on `getJobShare` in Next.js Server Components so that `generateMetadata`, the landing page, and `opengraph-image.tsx` share a single cached upstream request per render.
   - Canonical URL generation cleanly resolves forwarded proxy headers (`x-forwarded-host`, `x-forwarded-proto`) falling back to `MARICHO_PUBLIC_URL`.
4. **Graceful Native vs. Web Share Sheet Handling:**
   - `ShareJobButton.tsx` handles mobile `navigator.share` gracefully, catching `AbortError` when users cancel the share sheet, and cleanly falls back to a sheet dialog with direct sharing links (WhatsApp, Facebook, LinkedIn, X, and clipboard copy).

### Findings & Actionable Recommendations

1. **[Medium / Non-blocking] API Contract Drift (`docs/architecture/openapi.yaml`):**
   - The new route `GET /jobs/{job_id}/share` was added to `backend/app/apps/jobs/interface_adapters/router.py`, but `docs/architecture/openapi.yaml` was not updated with the path or the `JobShareOut` schema. Logged as `Architecture_and_Design/MARITCHO-2026-11-25-unregistered-share-endpoint-in-openapi.md`.
2. **[Low / Observability] Log Parameter Typing:**
   - In `get_job_share_summary`, logging is formatted via f-string (`logger.info(f"Job share summary served job_id={job_id} is_open={summary.is_open}")`). While OTel span attributes correctly capture structured fields (`job.id`, `job.share.is_open`), passing structured `extra` dicts or key-value parameters to the logger improves JSON log aggregation consistency.
3. **[Low / Non-blocking] Vitest Test Isolation in `AccountScreen.test.tsx`:**
   - Full Vitest suite run in jsdom mode occasionally hits the 5000ms default test timeout when all 33 suites execute in parallel on busy CPU environments. Individual runs pass in ~2.0s. Recommended setting `testTimeout: 10000` in `vitest.config.ts` or splitting `AccountScreen.test.tsx`.

## Changes Made
- Authored bug/drift entry: `Architecture_and_Design/MARITCHO-2026-11-25-unregistered-share-endpoint-in-openapi.md`.
- Authored code review report: `reports/MARITCHO-2026-11-25-pr-15-code-review.md`.

## Verification
- Frontend build: `npm run build` succeeded cleanly with Turbo engine.
- Frontend linting: `eslint .` passed with 0 errors.
- Frontend unit tests: `vitest run` on `job-share.test.ts` and `next-path.test.ts` passed 16/16 tests.
- Backend linting: `ruff check app tests` passed cleanly.
- Backend formatting: `tests/test_job_share.py` is fully formatted.

## Follow-ups / Deferred
- PR author or follow-up commit should document `GET /jobs/{job_id}/share` in `docs/architecture/openapi.yaml`.

---

**Completed By:** Antigravity (Principal Engineer Review)
**Duration:** ~10 minutes
