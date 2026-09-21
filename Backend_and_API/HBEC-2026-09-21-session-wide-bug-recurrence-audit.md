# Session-wide audit: do today's bug classes recur elsewhere?

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved

## Summary
After fixing several distinct bugs during one long session (seed board-code
mismatch, `--dry-run` writing real data, `republish_canonical`'s pgbouncer
cursor crash, a legacy local curriculum seed, `replay_dropped_messages`
never actually replaying, and `ExamPaper` never propagating unpublish/delete),
audited the rest of both codebases for the same *classes* of bug rather than
assuming each was a one-off. Two more real instances found; two patterns
checked and confirmed clean.

## Findings

### 1. `.iterator()` + pgbouncer transaction pooling — one more instance
`STUDENT/hbec_backend/apps/accounts/management/commands/fix_profile_levels.py`
had the identical bug already found and fixed in `republish_canonical.py`
(Admin) earlier the same day: `.iterator()` opens a server-side cursor;
pgbouncer's transaction pooling can hand the next statement a different
backend connection before Django closes it, raising `InvalidCursorName`
after the real work already completed. Fixed the same way (dropped
`.iterator()`; `StudentProfile` counts are in the hundreds, not millions,
so no benefit was being bought anyway).

Checked the two other `.iterator()` call sites in both backends — both
inside Django data migrations (`0016_backfill_family_and_institution.py`,
`0017_backfill_mcq_correct_answer.py`). Confirmed (not assumed) they're
immune: Django wraps `RunPython` in a single atomic transaction by default,
and neither migration sets `atomic = False`, so the whole thing runs on one
backend connection throughout — the exact condition this bug needs to not
be present.

### 2. Local curriculum seed bypassing replication — a third instance
Found a *third* independent occurrence of "a management command writes
`curriculum.Subject`/`Grade`/`ExamBoard`/`Topic` directly into the student
database," each previously discovered and fixed in isolation with no shared
guardrail:
- `seed_grades.py` (Grade) — already deleted before this session, commit
  `2af0114f`; `fix_duplicate_grades.py` is its cleanup
- `seed_zimsec_curriculum.py` (Subject) — found and deleted earlier this
  session; `merge_legacy_subjects.py` is its cleanup
- **`bootstrap_exam_boards.py` (ExamBoard) — found and deleted now.** Never
  called from anywhere automated (grepped scripts/docs/CI, same as the
  other two). Also used the code `"CAMBRIDGE"` for its Cambridge board,
  which matches no real board anywhere — the exact code-mismatch class of
  bug already found and fixed in `seed_exam_papers.py` the same session.

Generalized the isolation-test guardrail
(`test_subject_write_isolation.py` → `test_curriculum_write_isolation.py`)
from covering just `Subject` to covering all four models this pattern has
now hit: `ExamBoard`, `Grade`, `Subject`, `Topic`. Verified it catches an
offending write for each of the four individually, not just the one case it
happened to be written against. Deliberately excludes `Paper`
(`apps.practice.models.Paper`): unlike these four, a `Paper` legitimately
has a second, sanctioned source (AI generation pushed from the harness via
`apps/internal/views.py`, tagged `source_type=STUDENT_GENERATED`) — folding
it into the same blanket rule would be a false positive against real,
intended functionality, confirmed by checking that call site tags its
source correctly rather than impersonating admin-replicated content.

## Patterns checked and confirmed clean

### `--dry-run` writing real data before the check
Checked every other management command with a `--dry-run` flag in both
backends (`sync_to_student.py`, `reconcile_student.py`,
`fix_duplicate_grades.py`, `check_subscriptions.py`,
`send_renewal_reminders.py`) for the same "write happens before the
dry_run check" ordering bug found in `seed_exam_papers.py`. None have it.
`fix_duplicate_grades.py` is worth calling out as the better-defended
version of this pattern: every write is gated *and* the whole `handle()` is
wrapped in `@transaction.atomic` with an explicit `transaction.set_rollback(True)`
on dry-run as a second safety net — belt-and-suspenders, where
`seed_exam_papers.py` had neither before today's fix.

### The byte-vs-str dict key mismatch
Checked for any other Redis client configured with `decode_responses=False`
(the precondition for the `replay_dropped_messages` bug) and for any other
`b"..."` dict-key literal pattern anywhere in either backend or the harness.
Found none — this bug class is fully confined to the one file already
fixed (`stream_consumer.py`).

## Prevention / Rule
**Guardrail:** the generalized `test_curriculum_write_isolation.py` is the
concrete artifact — three independent discoveries of the same architectural
violation, for three different models, is the signal that a per-incident
fix isn't enough; the fourth model this could hit next (were it not for
this test) is already covered.

## Prevention
- [x] `fix_profile_levels.py` `.iterator()` fix applied
- [x] Confirmed migrations' `.iterator()` calls are safe (atomic by default)
- [x] `bootstrap_exam_boards.py` deleted (third instance)
- [x] Isolation test generalized to all four affected models, verified against each
- [x] `--dry-run` audit: no other instance found
- [x] byte/str key audit: no other instance found

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-legacy-local-curriculum-seed-orphaned-students.md`
- `Backend_and_API/HBEC-2026-09-21-replay-dropped-messages-never-replayed-anything.md`
- `Backend_and_API/HBEC-2026-09-21-republish-canonical-pgbouncer-cursor-crash.md`
- `Backend_and_API/HBEC-2026-09-21-seed-dry-run-created-real-subjects.md`

## References
- `STUDENT/hbec_backend/apps/curriculum/tests/test_curriculum_write_isolation.py`
- `STUDENT/hbec_backend/apps/accounts/management/commands/fix_profile_levels.py`

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~35 minutes
