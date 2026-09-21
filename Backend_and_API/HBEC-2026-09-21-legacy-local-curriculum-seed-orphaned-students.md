# A legacy local curriculum seed silently orphaned students from Admin content

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging (fixed); Production (diagnosed, not yet fixed — see below)
**Severity:** High
**Status:** Resolved on staging

## Summary
A real user's account showed "Being prepared — nothing to practise yet" for
Biology, Chemistry, and Physics, and duplicate "Combined Science" tiles, even
though matching content existed in the database. Root cause: a long-forgotten
management command, `seed_zimsec_curriculum.py`, wrote its own hardcoded
`Subject` rows directly into the student backend, completely disconnected
from Admin's replication pipeline — a direct violation of this project's own
documented rule, *"Curriculum data comes EXCLUSIVELY from admin via Redis
stream — never seed the student DB directly."* Those rows sat in the
onboarding subject picker indistinguishable from the real, replicated
`Subject` for the same name+grade. Whichever one a student happened to pick
determined whether Admin-published content would ever reach them.

## Symptoms
- Student-facing: subjects showing "nothing to practise yet" despite content
  existing elsewhere in the same database for the same subject name/grade.
- A subject (Combined Science) appearing twice in the subject-selection UI.
- Discovered while investigating why exam papers seeded earlier the same
  session (see `HBEC-2026-09-21-seed-exam-board-code-mismatch.md`) weren't
  visible to a specific test account despite successfully replicating to the
  student backend.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142), staging
- **Services Affected:** Student Backend (`apps/curriculum`, `apps/accounts`)
- **Related Components:** `apps/replication/stream_consumer.py` (the real,
  intended write path), `StudentProfile.subjects`

## Investigation Steps

### 1. Initial Diagnosis
Traced a specific account's enrolled subjects (`StudentProfile.subjects`,
a JSON list of `Subject.code` strings) and found codes like `MATH_O`,
`SCI_O`, `BIOLOGY_OLEVEL` — human-readable, not ZIMSEC's real numeric
syllabus codes (`4004`, `4003`, `4025`, ...) used everywhere else.

### 2. Root Cause Analysis
```bash
grep -rln "Subject.objects.create\|Subject.objects.update_or_create\|Subject.objects.get_or_create" \
  STUDENT/hbec_backend/apps --include="*.py" | grep -v migrations | grep -v test
# -> apps/replication/services.py       (legitimate: admin webhook payload)
# -> apps/replication/stream_consumer.py (legitimate: the primary replication path)
# -> apps/curriculum/management/commands/seed_zimsec_curriculum.py  <- the offender
```
Confirmed Admin's own data model has no equivalent problem first, to rule out
the drift originating there: `SubjectFamily` has a DB-level unique constraint
per `(exam_board, name)`; `Subject` has one per `(family, grade)`. Queried a
sample family (Combined Science) directly — exactly one family, four
correctly grade-linked offerings, no duplicates, no NULL grades. Admin was
clean; the drift was 100% local to the student backend.

`seed_zimsec_curriculum.py` was never in the automated startup path (only
`seed_personalization_options` runs at container start) and nothing in the
deploy pipeline, CI, or docs referenced running it — a one-off manual
bootstrap from before the replication pipeline existed, never removed.

### 3. Key Findings
- **Scope:** staging had 47 legacy `Subject` rows (of 252 total) affecting
  3/19 student profiles with any subjects. **Production had only 4 legacy
  rows (of 399 total) but they affected 81/220 profiles (37%)** — a handful
  of rows, but the popular compulsory subjects (Mathematics, Combined
  Science, etc.), so the blast radius was disproportionate to the row count.
- This is a **different** bug from the one `fix_duplicate_subjects.py` (and
  Admin's `merge_duplicate_subjects.py`) already handles — that pair remaps
  profiles off Admin-side "-5"/"-6" stray-suffix code duplicates. Neither
  touches this legacy-vocabulary class at all; none of `fix_duplicate_subjects`'s
  remap entries resemble `MATH_O`-style codes.
- Matching legacy subjects to their real, replicated counterpart by exact
  `(name.lower(), grade_code)` — after normalizing the legacy vocabulary's
  flat `"upper-6"` to the replicated data's `"form-6-upper-6"` (the same
  spelling-equivalence problem Admin's `seed_exam_papers.py` already
  documents for `GRADE_EQUIVALENTS`) — produced 31 unambiguous matches and
  16 that genuinely need a human/product decision (Admin hasn't authored
  that subject+grade yet, or the naming doesn't map 1:1, e.g. legacy's single
  "Indigenous Language and Literature" vs Admin's separate Shona/Ndebele
  subjects).

## Root Cause
A local curriculum-seeding command that predates the Admin → replication
architecture was never removed once that architecture became the actual
source of truth, and nothing enforced that it couldn't be run (or that its
past output couldn't linger silently) alongside the real pipeline.

## Prevention / Rule
**Guardrail:** `apps/curriculum/tests/test_subject_write_isolation.py` —
statically scans every non-test file under `apps/` for a
`Subject.objects.create/update_or_create/get_or_create/bulk_create` call
outside the two legitimate replication paths, failing CI if a new one
appears. Same static-analysis-gate pattern the Agentic Harness's
`test_isolation.py` already uses to enforce "only these two modules may
import litellm" — proven precedent in this codebase for exactly this shape
of problem. Verified it actually catches the bug class: planted a fake
offending file, confirmed the test failed, removed it, confirmed it passed.

## Solution

### Immediate Fix
1. Deleted `seed_zimsec_curriculum.py` entirely (commit `fca9934f`) —
   confirmed nothing referenced running it.
2. Added `merge_legacy_subjects.py` (dry-run by default, mirrors Admin's
   `merge_duplicate_subjects.py` pattern exactly): re-points every
   `Topic`/`Paper` FK and `StudentProfile.subjects` entry from a legacy code
   to its real replicated counterpart, for the 30 hand-verified pairs (one
   pair, `SCI_O`, was later found to also need `COMBINED_SCI_OLEVEL` merged
   into the same canonical target, bringing the applied total to 30).
3. Ran dry-run then `--apply` on staging: **30 legacy subjects merged, 91
   topics + 84 papers re-pointed, 11 student profiles remapped**, zero
   errors.
4. **Caught and fixed a bug in the fix itself** during verification: two
   legacy codes can share one canonical target (`MATH_O` and `MATH_OLEVEL`
   both → `"4004"`), so a profile that had picked both ended up with the
   canonical code listed twice — exactly reproducing the duplicate-tile
   symptom this was meant to fix. Added de-duplication
   (`list(dict.fromkeys(...))`, preserving pick order) to the command
   (commit `7fa59c5d`), and one-off deduped the 3 already-affected profiles
   on staging by hand before the fix was deployed.
5. Added the isolation-test guardrail described above.

### Long-term Fix
Production still has the same 4 legacy rows affecting 81/220 profiles —
**deliberately not touched this session** per explicit instruction to
validate on staging first. Re-run the same dry-run → review → `--apply`
sequence on production once staging's fix has been observed working for
real traffic.

## Prevention
- [x] Delete the source of the drift (`seed_zimsec_curriculum.py`)
- [x] Remediate staging's existing drift (30 subjects, 91 topics, 84 papers, 11 profiles)
- [x] Add regression guardrail (`test_subject_write_isolation.py`)
- [x] Fix the dedup bug found during the fix's own verification
- [ ] Run the same remediation on production (explicitly deferred)
- [ ] Decide what to do with the 16 legacy subjects that had no clean match
      (author the missing Admin content, or a product decision on which
      canonical subject a merged naming difference should resolve to)

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-seed-exam-board-code-mismatch.md` — the
  seeding work during which this was discovered
- `Database_and_State/HBEC-2026-09-21-staging-student-subject-drift.md` — a
  related but distinct admin/student sync gap found earlier the same session

## References
- `STUDENT/hbec_backend/apps/curriculum/management/commands/merge_legacy_subjects.py`
- `STUDENT/hbec_backend/apps/curriculum/tests/test_subject_write_isolation.py`
- `STUDENT/hbec_backend/apps/accounts/management/commands/fix_duplicate_subjects.py` (the existing, unrelated precedent)
- `ADMIN/adminBackend/apps/curriculum/management/commands/merge_duplicate_subjects.py` (the pattern this mirrors)

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~50 minutes from discovery to deployed, verified fix (staging only)
