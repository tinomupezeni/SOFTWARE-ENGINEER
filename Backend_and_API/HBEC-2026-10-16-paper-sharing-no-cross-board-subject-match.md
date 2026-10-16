# Cross-board paper sharing has no production subject match

**Date:** 2026-10-16
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
The active blue Student Backend contains the paper-sharing field, migration, and
cross-board filtering code, but the live curriculum has no subject code shared
between ZIMSEC and Cambridge for any published paper tagged
`shared_across_boards=True`. As a result, the cross-board branch cannot return a
paper to a student on the other board, so the student-facing feature could not
be proven in production.

## Symptoms
- Admin exposes published papers with `sharedAcrossBoards: true`.
- The active Student Backend (`sha-1a3b4ec`) has the field and migration applied.
- A read-only production audit found no shared subject code across the two exam
  boards for a published shared paper.
- The student cross-board visibility test therefore had no valid production
  fixture and could not demonstrate the promised behavior.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Student Backend paper catalogue; Admin-to-Student
  curriculum replication/data curation
- **Related Components:** `apps.practice.views`, `apps.practice.models`,
  `apps.curriculum.models`, replicated subject and paper data
- **Time First Observed:** 2026-10-16

## Investigation Steps

### 1. Initial Diagnosis
The direct uncolored `hbec-student-backend` container was first inspected and
was found to be an obsolete `prod-promote-6a151782` image without the sharing
field. The color-specific active container was then inspected to avoid treating
that legacy container as the routed deployment.

### 2. Root Cause Analysis
The active blue container was verified as `sha-1a3b4ec`, with
`shared_across_boards` present in the model and migration `0021` applied. A
read-only query then compared active subjects across exam boards and checked
published shared papers. The query returned no subject code that both crossed
boards and had a published shared paper.

The Student Backend implementation widens cross-board visibility only when the
other-board subject has the learner subject's exact `Subject.code` and a
matching paper-band grade code. It does not use subject-name or board-specific
syllabus mapping. Live examples show different codes for the same named subject,
such as ZIMSEC Agriculture `4001` and Cambridge Agriculture `0600`.

```bash
docker exec hbec-student-backend-blue python manage.py showmigrations practice
docker exec hbec-student-backend-blue python manage.py shell -c \
  'query active subjects and published shared papers by board and subject code'
```

### 3. Key Findings
- The active color is not missing the code or migration; blue is healthy and
  has the sharing implementation.
- The uncolored `hbec-student-backend` is stale and must not be used as the
  production student-path verifier.
- `shared_across_boards=True` alone is insufficient: the subject-code and
  paper-band match must also exist.
- Production currently has no valid cross-board data fixture for the feature.

## Root Cause
The feature contract assumes that equivalent subjects on different exam boards
share the same `Subject.code`, but the live ZIMSEC and Cambridge curriculum
records use board-specific syllabus codes. No explicit cross-board subject
mapping or production fixture bridges those codes, so the intended sharing path
filters every candidate out before the sharing flag can take effect.

## Prevention / Rule
**Guardrail:** Add a CI and deployment data audit that requires at least one
published `shared_across_boards` paper to resolve to a subject on another
configured exam board through the production matching rule, and fails with the
unmatched subject codes.

This catches both data curation gaps and matching-rule drift before a feature is
declared live. The audit must run against the same replicated subject/paper
shape used by the Student Backend, not only the Admin API.

## Solution

### Immediate Fix
No production data was mutated. The active blue deployment and database were
left unchanged because there is no safe basis for inventing a Cambridge-to-
ZIMSEC subject mapping or creating a synthetic student fixture in production.

### Long-term Fix
Choose and implement one explicit contract:

1. Replicate a governed cross-board subject equivalence key and match on it; or
2. Maintain an admin-managed cross-board subject mapping; or
3. Require board-specific subject records to use a shared canonical code.

Then seed and verify at least one published shared paper for each supported
board pair and run an authenticated student catalogue smoke test.

## Prevention
- [ ] Define the canonical cross-board subject identity.
- [ ] Add a replicated-data contract test for board-specific subject codes.
- [ ] Add a production smoke test for shared and unshared cross-board papers.
- [ ] Add monitoring or an admin warning for shared papers with no resolvable
      cross-board subject.
- [ ] Update the paper-sharing report after the student journey passes.

## Related Issues
- `SOFTWARE-ENGINEER/reports/HBEC-2026-10-16-paper-sharing-verification.md`

## References
- `STUDENT/hbec_backend/apps/practice/views.py`
- `STUDENT/hbec_backend/apps/practice/tests/test_paper_bands.py`
- `STUDENT/hbec_backend/apps/practice/models.py`
- Production active revision: `sha-1a3b4ec`

---

**Resolved By:** Pending
**Time to Resolution:** Pending
