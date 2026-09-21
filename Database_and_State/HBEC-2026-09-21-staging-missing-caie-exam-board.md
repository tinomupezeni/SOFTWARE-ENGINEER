# Staging admin DB has no CAIE (Cambridge) ExamBoard row at all

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Investigating

## Summary
Staging's admin database has exactly one `ExamBoard` row (`ZIM-HBCA`).
Production has two (`ZIM-HBCA` and `CAIE`). Cambridge content — 346 of the
684 files in the new `seeds/exam_papers/` corpus — cannot seed on staging at
all, board-alias fix or not, because there is nothing for `CAIE` to resolve
to on that environment.

## Symptoms
- After fixing the ZIMSEC/CAMBRIDGE alias mismatch (see
  `Backend_and_API/HBEC-2026-09-21-seed-exam-board-code-mismatch.md`),
  `seed_exam_papers --dry-run` on staging still reported all 346 `CAMBRIDGE`
  files under `no board`.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142)
- **Services Affected:** Admin Backend (`apps/exam_boards`), and everything
  downstream that depends on Cambridge content existing on staging
- **Related Components:** `apps/exam_boards/models.py`

## Investigation Steps

### 1. Initial Diagnosis
```bash
docker exec hbec-admin-backend-staging python manage.py shell -c \
  "from apps.exam_boards.models import ExamBoard; print(list(ExamBoard.objects.values_list('code','name')))"
# -> [('ZIM-HBCA', 'Heritage Based Curriculum Assistant')]

docker exec hbec-admin-backend python manage.py shell -c \
  "from apps.exam_boards.models import ExamBoard; print(list(ExamBoard.objects.values_list('code','name')))"
# (production) -> [('CAIE', 'Cambridge Assessment International Education'), ('ZIM-HBCA', 'Heritage Based Curriculum Assistant')]
```

### 2. Root Cause Analysis
Not yet determined whether staging never had the `CAIE` board created, or
whether it was created and then lost in an earlier database
reset/reseed/restore on staging specifically. `ExamBoard` rows aren't
covered by `republish_canonical` unless the *source* row already exists —
republishing can't manufacture a board admin itself doesn't have, so this
gap sits upstream of the seeding pipeline entirely.

### 3. Key Findings
- This is a staging-only gap: production has the board, staging doesn't.
- Unlike the seed alias issue, this can't be fixed inside `seed_exam_papers`
  — there's no board on staging to alias to.

## Root Cause
Unconfirmed. Candidates: staging's admin DB was seeded/reset from a snapshot
taken before `CAIE` was created on production, or the board was created
directly on production only and never intentionally propagated to staging
(exam boards are close to the top of the curriculum hierarchy and don't
appear to have their own "create on staging too" step documented anywhere).

## Prevention / Rule
**Guardrail:** none proposed yet — needs the root cause above confirmed
first. If the answer is "staging is meant to mirror production's curriculum
configuration," the fix is a documented/scripted step (or a
`republish_canonical`-style command that reads from a fixture rather than
the live table) for creating baseline `ExamBoard` rows on a fresh or reset
staging environment, so this can't silently go missing again.

## Solution

### Immediate Fix
Not applied. Two options, need a decision:
1. Manually create the `CAIE` `ExamBoard` row on staging
   (`ExamBoard.objects.create(code="CAIE", name="Cambridge Assessment
   International Education")` or via the admin UI), matching production's
   values exactly so nothing else diverges.
2. Treat this as evidence staging's DB should be re-seeded from a fresher
   baseline/production snapshot rather than patched row-by-row.

### Long-term Fix
See Prevention / Rule above.

## Prevention
- [ ] Confirm root cause (DB reset timing vs. never-propagated board)
- [ ] Create the `CAIE` board on staging (or re-seed staging's baseline)
- [ ] Re-run `seed_exam_papers --board CAMBRIDGE --dry-run` on staging to confirm
- [ ] Decide whether exam-board creation needs a repeatable fixture/command

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-seed-exam-board-code-mismatch.md` — the
  code-alias bug this was discovered alongside; that one is fully resolved,
  this one is a separate, still-open environment gap.

## References
- `ADMIN/adminBackend/apps/exam_boards/models.py`

---

**Resolved By:** (unresolved)
**Time to Resolution:** N/A
