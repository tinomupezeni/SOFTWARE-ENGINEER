# Cross-board sharing required target-subject replication

**Date:** 2026-10-24
**Project:** HBEC
**Environment:** Development / design review
**Severity:** Medium
**Status:** Workaround Applied

## Summary
Cross-exam-board paper sharing was implemented as explicit `shared_with_subjects`
relationships that were replicated into the Student Backend. The intended product
behavior is a paper-level sharing permission: replicate the paper once with its
origin board and subject, then grant access locally to equivalent subjects on
other boards. The target relationship added unnecessary replication coupling and
could hide a paper when the target curriculum row was absent downstream.

## Symptoms
- Admin sharing required selecting and persisting target subject rows.
- Paper visibility depended on those target rows being present in the Student Backend.
- Subject and grade codes differ between boards, so code-based fallback could not
  reliably identify equivalent content.

## Environment Details
- **Server/Host:** Local HBEC worktree
- **Services Affected:** Admin Backend, Admin Frontend, Student Backend
- **Related Components:** Exam paper sharing API, replication payloads, student paper catalogue
- **Time First Observed:** 2026-10-24

## Investigation Steps

### 1. Initial Diagnosis
The existing implementation was traced from the admin sharing panel through the
paper replication payload and Student Backend catalogue filtering.

### 2. Root Cause Analysis
The sharing API accepted a list of target subject IDs and the replication
contract carried those IDs. Student visibility preferred those rows and only
used the paper flag for legacy code-matched sharing.

```bash
rg -n "shared_with_subjects|shared_across_boards" ADMIN/adminBackend STUDENT/hbec_backend
```

### 3. Key Findings
- Student curriculum already carries cross-board subject identity via
  `canonical_key` and subject metadata.
- A shared paper already carries its origin board and subject.
- The global sharing flag can therefore be evaluated without target-subject
  replication.

## Root Cause
The data model treated visibility scope as replicated relationship data instead
of a policy applied by the consuming catalogue. This coupled access to
asynchronous curriculum replication and could not handle differing board codes
and grade codes without manually selected targets.

## Prevention / Rule
**Guardrail:** Cross-board content visibility must be derived from the replicated
paper origin plus local curriculum identity and a paper-level permission; new
paper-sharing APIs and payload contracts must not require target-subject IDs.

This keeps the paper authoritative in its origin board, avoids a second
relationship that can drift, and makes a missing target curriculum row a visible
curriculum problem rather than a paper-sharing data-loss path.

## Solution

### Immediate Fix
- Changed the admin API and panel to save `sharedAcrossBoards: boolean`.
- Cleared target relationships on new sharing writes.
- Changed Student Backend visibility to match equivalent subjects locally using
  canonical key/name and the learner's paper band.
- Updated subject paper counts to include globally shared papers.
- Retained historical target rows as a compatibility read path.

### Long-term Fix
Run the focused cross-board sharing suites against the supported PostgreSQL
services and verify the first staging paper through the real admin-to-student
journey.

## Prevention
- [x] API no longer requires target-subject IDs for new writes
- [x] Regression test added for differing board and grade codes without target rows
- [ ] Staging smoke test with a real Cambridge/ZIMSEC paper
- [ ] Reconcile or retire historical target-row data after rollout

## Related Issues
- ProjectFlow task: `Papers aren't shared`

## References
- `ADMIN/adminBackend/apps/exam_papers/sharing.py`
- `STUDENT/hbec_backend/apps/practice/views.py`
- `STUDENT/hbec_backend/apps/curriculum/views.py`

---

**Resolved By:** Copilot
**Time to Resolution:** In progress
