# LEC Virtual Labs Codebase Orientation

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Type:** Audit / Documentation Alignment
**Status:** Completed

## Summary
Read the LEC Virtual Labs codebase and its living engineering documentation to establish an accurate
architecture handoff. The review traced the user roles, React routes, Django APIs and models, server-side
marking, iframe simulation bridge, authentication lifecycle, and local runtime workflow.

## Context / Trigger
The user asked for the codebase to be read and understood before future engineering work.

## Scope
Included project memory and contracts, engineering inspiration, backend apps and settings, frontend routing and
API infrastructure, LabPlayer and bridge behavior, and the lab catalog layout. Excluded runtime changes,
production deployment, and manual browser validation.

## Method
Read the authoritative project memory index first, then the architecture/contracts, followed by the corresponding
backend and frontend implementation files. Cross-checked the documented lab inventory against the backend catalog.

## Decisions & Findings
- Django + DRF + Postgres is the source-of-truth backend for users, schools, classrooms, assignments, attempts,
  manifests, answers, progress and scores.
- React + Vite + TypeScript provides role-aware shells for students, teachers, school admins and platform admins.
- Simulations are static, self-contained iframe applications. They communicate only through the origin-checked
  `postMessage` Lab Bridge; they do not call the backend directly.
- Lab manifests are authoritative. Answers and marking rules remain server-side; the public manifest is stripped
  before delivery to the browser.
- Attempts are resumable and row-locked for writes. Autosaved simulation state, drafts, current step and
  server-evaluated completion events support resume and teacher review.
- Authentication uses in-memory access tokens, an httpOnly rotating refresh cookie, throttling, lockout,
  audit events and role/school gates.
- The repository currently contains 28 non-example backend lab manifests.
- The root README had a stale 20-lab summary and was corrected; the issue is logged separately.

## Changes Made
- Updated `README.md` to state 28 labs.
- Added school/platform-admin role notes to `intelligent_memory_management/architecture/overview.md`.
- Added the orientation session log at `intelligent_memory_management/sessions/2026-11-06_session-05.md`.
- Added the corresponding documentation issue log in the shared engineering repository.

## Verification
- Read the relevant architecture, contract, backend, frontend and engineering-guideline documents.
- Counted 28 non-example JSON manifests under `backend/labs/catalog`.
- Confirmed the project worktree was clean before documentation edits.
- Runtime tests were not run because this was a read-only orientation and documentation-alignment task.

## Follow-ups / Deferred
- Run the documented backend tests and manifest validation before the next behavioral change.
- Perform the documented manual browser/screen-reader pass when UI behavior is next modified.
- Add automated documentation/catalog count parity if release tooling is expanded.

## References
- `intelligent_memory_management/architecture/overview.md`
- `intelligent_memory_management/architecture/repo-layout.md`
- `intelligent_memory_management/contracts/api.md`
- `intelligent_memory_management/contracts/lab-manifest.md`
- `intelligent_memory_management/contracts/lab-bridge.md`
- `backend/labs/marking.py`
- `frontend/src/features/labs/LabPlayerPage.tsx`
- `frontend/src/features/labs/useLabBridge.ts`

---

**Completed By:** Copilot
**Duration:** Same session
