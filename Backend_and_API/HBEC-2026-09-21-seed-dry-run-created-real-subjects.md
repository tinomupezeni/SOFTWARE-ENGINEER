# --dry-run wrote real curriculum rows when combined with --create-missing-subjects

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
`seed_exam_papers --board CAMBRIDGE --create-missing-subjects --dry-run`
reported `DRY RUN - nothing written`, but actually created 17 real
`SubjectFamily`/`Subject` rows in staging's admin database and published
17 `subject.created` events to the replication stream. The command's one
explicit safety promise — "Resolves everything, writes nothing" — was false
for the exact flag combination its own docs warn is the risky one
(`--create-missing-subjects`: "a wrong guess puts a paper in front of
learners who do not study it").

## Symptoms
```
DRY RUN - nothing written: 684 seed files
  papers created=0 updated=299 questions=2243
```
printed alongside 17 `"Outbox queued subject.created: ..."` log lines.
Querying `Subject.objects.filter(exam_board=<CAIE>).count()` immediately
after returned 17, not 0.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142)
- **Services Affected:** Admin Backend seeding pipeline
- **Related Components:** `apps/curriculum/models.py`
  (`get_or_create_subject_family`), replication outbox

## Investigation Steps

### 1. Initial Diagnosis
Ran the dry-run specifically to preview what `--create-missing-subjects`
would author for the newly-created CAIE board, before doing it for real —
standard practice per `seeds/README.md`'s "always dry-run first." The
subject names logged during the "dry run" looked correct, which is what
prompted checking whether they'd actually landed in the database.

### 2. Root Cause Analysis
```python
subject = self._resolve_subject(
    board=board, grade=grade, family_name=family_name, create_missing=create_missing
)
...
if dry_run:
    stats["updated"] += 1
    stats["questions"] += len(seed.get("questions", []))
    continue
```
`_resolve_subject(..., create_missing=True)` runs unconditionally, before
the `if dry_run` check. It calls `get_or_create_subject_family()` and
`Subject.objects.get_or_create()` directly — real writes — regardless of
`dry_run`. Only the paper/question write further down (`_seed_paper`) was
actually gated on `dry_run`.

### 3. Key Findings
- The bug only manifests with `--create-missing-subjects` set; without it,
  `_resolve_subject` only ever reads (`Subject.objects.filter(...).first()`),
  so ordinary dry-runs (including the ZIMSEC one earlier this session) were
  genuinely dry.
- The 17 rows created were, in this instance, exactly what the operator
  intended to author — but that's circumstance, not the command behaving
  correctly. A `--dry-run` meant purely to preview would have authored
  curriculum on staging by accident.

## Root Cause
`_resolve_subject()`'s only side-effecting branch (`create_missing=True`)
wasn't threaded through the `dry_run` flag; only the later, more obviously
"the actual write" call was.

## Prevention / Rule
**Guardrail:** any management command accepting `--dry-run` should have a
test asserting `Model.objects.count()` is unchanged for every model the
command can touch, run once with each side-effecting flag combination
enabled. For this specific command, that test would have caught this
immediately since `SubjectFamily`/`Subject` counts are exactly what
changed.

## Solution

### Immediate Fix
`ADMIN/adminBackend/apps/exam_papers/management/commands/seed_exam_papers.py`:
changed the call to `create_missing=create_missing and not dry_run`, commit
`7f8c4a14`. Rebuilt and redeployed to staging's `admin-backend`/
`admin-worker`/`admin-beat`.

The 17 subjects already created by the bug were reviewed (all correctly
named, all at Form 6/A-Level as expected for Cambridge A-Level syllabus
codes) and kept — they were the intended outcome of a since-authorized real
run, just created a step earlier than they should have been.

### Long-term Fix
Add the dry-run-invariance test described in the guardrail above; consider
auditing other management commands with a `--dry-run` flag for the same
"write happens before the dry_run check" ordering bug.

## Prevention
- [x] Fix applied and deployed
- [ ] Add a dry-run-invariance test for `seed_exam_papers`
- [ ] Audit other `--dry-run`-flagged commands for the same ordering bug

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-seed-exam-board-code-mismatch.md`
- `Database_and_State/HBEC-2026-09-21-staging-missing-caie-exam-board.md`
  (the CAIE board this was discovered while populating)

## References
- `ADMIN/adminBackend/apps/exam_papers/management/commands/seed_exam_papers.py`

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~15 minutes
