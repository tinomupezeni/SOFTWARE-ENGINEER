# Global paper-level cross-board sharing

**Date:** 2026-10-24
**Project:** HBEC
**Type:** Architecture Decision / Refactor
**Status:** Completed

## Summary
Reworked cross-exam-board paper sharing so access is controlled by a paper-level
permission rather than replicated target-subject relationships. Papers retain
their origin board and subject, while the Student Backend resolves equivalent
local subjects when presenting shared content.

## Context / Trigger
The “Papers aren't shared” task exposed that target-subject replication coupled
visibility to downstream curriculum rows and could not reliably handle different
board subject and grade codes.

## Scope
Included Admin Backend/API and replication payload behavior, Admin Frontend
sharing controls, Student Backend catalogue visibility and paper counts, and
focused regression tests. Database-backed tests and staging verification were
excluded because PostgreSQL was unavailable locally and no staging promotion was
requested.

## Method
Traced the admin sharing request through persistence, replication payloads,
student catalogue filtering, and frontend consumers. Replaced target selection
with a boolean paper-level contract, preserved historical target rows for
compatibility, and added regression coverage for differing board and grade
codes without target rows.

## Decisions & Findings
- Cross-board sharing is a visibility policy, not a replicated curriculum
  relationship.
- New sharing writes clear obsolete target relationships.
- Student visibility matches local curriculum identity and paper bands.
- The paper remains tagged and marked according to its origin board.

## Changes Made
- Updated Admin Backend sharing serializers, helpers, views, and payload tests.
- Replaced the Admin Frontend target-subject picker with a global toggle.
- Updated Student Backend paper visibility and subject paper counts.
- Added focused Admin and Student regression coverage.

## Verification
- Admin and Student backend lint and compilation checks passed.
- Admin Frontend typecheck passed.
- Admin Frontend sharing tests passed: 8 tests.
- Diff integrity checks passed.
- PostgreSQL-backed backend tests remain unverified because PostgreSQL was
  unavailable on the expected local ports.

## Follow-ups / Deferred
- Run backend database suites with supported PostgreSQL services.
- Verify a real Cambridge/ZIMSEC sharing journey in staging.
- Reconcile or retire historical target-subject rows after rollout.

## References
- `Architecture_and_Design/HBEC-2026-10-24-cross-board-sharing-required-target-replication.md`
- `ADMIN/adminBackend/apps/exam_papers/sharing.py`
- `STUDENT/hbec_backend/apps/practice/views.py`

---

**Completed By:** Copilot
