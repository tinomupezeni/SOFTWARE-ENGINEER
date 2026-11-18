# Two alembic migrations both claimed revision 047, blocking deploy-color

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Production (caught by `deploy-color` building the inactive
color on the VPS; live traffic was never affected)
**Severity:** High (would have blocked every future deploy until fixed;
caught before cutover)
**Status:** Resolved

## Summary
Two independent feature branches (#156/#158's verified-pictures work and
#157's Whiteboard pillar) each added an Alembic migration numbered `047`,
chained off two different prior heads (`045` and `046` respectively). Once
both branches were merged into `experimental` and then `master`, the harness
had two migration heads. `alembic upgrade head` refuses to run in that state
("Multiple head revisions are present for given argument 'head'"), so the
harness container never started and failed its healthcheck.

## Symptoms
- Running the manual `deploy-color` runbook script on the VPS to build and
  start the inactive color (`green`) from the fresh `master` push: every
  other service (student-backend, admin-backend, frontend, payments,
  schools, code-runner) came up healthy; `hbec-harness-green` stayed
  `unhealthy` and the compose `up --wait` step failed.
- `docker logs hbec-harness-green` showed:
  ```
  UserWarning: Revision 047 is present more than once
  ERROR [alembic.util.messaging] Multiple head revisions are present for
  given argument 'head'; please specify a specific target revision,
  '<branchname>@head' to narrow to a specific head, or 'heads' for all heads
  FAILED: Multiple head revisions are present for given argument 'head'...
  ```
- The live `blue` color was never touched — `deploy-color` only builds and
  starts the inactive color, so this was caught with zero production impact.

## Environment Details
- **Server/Host:** VPS (`/opt/hbec`, blue-green deploy)
- **Services Affected:** `harness-green` only (never reached live traffic)
- **Related Components:** `AGENTIC_HARNESS/alembic/versions/`
- **Time First Observed:** 2026-11-18, during a manual `deploy-color` run
  right after merging 9 stacked PRs (#149, #151-158) into `master`.

## Investigation Steps

### 1. Initial Diagnosis
`deploy-color`'s own log named the failing container
(`hbec-harness-green is unhealthy`); `docker logs` on it showed the alembic
error directly, no further digging needed to find the symptom.

### 2. Root Cause Analysis
```bash
grep -rl "revision = ['\"]047" AGENTIC_HARNESS/alembic/versions/
# AGENTIC_HARNESS/alembic/versions/047_add_verified_pictures.py
# AGENTIC_HARNESS/alembic/versions/047_whiteboard_lesson_rating.py
```
Both files declared `revision = "047"`. `047_add_verified_pictures.py`'s
own docstring had actually anticipated this exact collision ("Numbered 047
because an unmerged migration on another branch already takes 046 ...
Whichever of the two merges second re-chains its `down_revision` onto the
other") — but neither branch's merge actually did that re-chaining, since
each was merged independently without the author checking the other
branch's eventual migration number.

### 3. Key Findings
- `047_add_verified_pictures.py`: `down_revision = "045"` (written before
  `046_add_whiteboard_lessons` existed on its own branch).
- `047_whiteboard_lesson_rating.py`: `down_revision = "046"` (correctly
  chained onto `046_add_whiteboard_lessons`, both from PR #157).
- PR #157 (whiteboard) merged into `experimental` after PR #156
  (verified-pictures), so the correct resolution is to re-chain
  verified-pictures onto the true head left after #157's merge, not the
  other way round.
- Verified the fix by parsing every migration file's `revision`/
  `down_revision` pair and confirming exactly one head remained.

## Root Cause
Two feature branches each added one new Alembic migration, authored in
parallel against the same base, each choosing the next sequential revision
number available on their *own* branch at the time. Alembic revision
numbers are a global, serial constraint across the whole migration history;
nothing in the repo enforces that at merge time, so merging both branches
produced a valid-looking but broken migration graph (two heads) that only
surfaces when something actually tries to run `alembic upgrade head` -
which first happens when a container boots, not at merge/review time.

## Prevention / Rule
**Guardrail:** add a CI check (alongside `scripts/deploy/check-migrations.py`,
which already runs on every deploy for the expand-only rule) that fails a
PR/merge whenever `alembic` reports more than one head on the merged branch -
e.g. a `scripts/deploy/check-migration-heads.py` that shells out to (or
reimplements, dependency-free, as this investigation did) a walk of
`alembic/versions/*.py`'s `revision`/`down_revision` pairs and asserts
exactly one head.

This closes the gap because it catches the exact failure mode at PR/CI time -
before a deploy ever boots a container against the database - rather than
relying on two branch authors' docstrings to remember to check each other's
migration numbers by hand.

## Solution

### Immediate Fix
Renumbered `047_add_verified_pictures.py` to `048_add_verified_pictures.py`
and re-chained its `down_revision` from `045` to `047` (the true head left
by PR #157's merge), restoring a single migration head.

```bash
git mv AGENTIC_HARNESS/alembic/versions/047_add_verified_pictures.py \
       AGENTIC_HARNESS/alembic/versions/048_add_verified_pictures.py
# edit revision = "048", down_revision = "047"
```

Verified with a dependency-free script walking every migration file's
`revision`/`down_revision` pair (the venv on this box doesn't have `alembic`
installed as a console script, only as a library import inside the app):
```python
# parses revision= / down_revision= out of every alembic/versions/*.py,
# builds the set of revisions that are never any other file's down_revision
```
confirmed exactly one head (`048`) afterward.

### Long-term Fix
Add the CI guardrail described above so this is caught automatically on the
next PR that introduces a colliding migration number, rather than only at
deploy time.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done)

## Related Issues
- Surfaced while finishing a 9-PR code-review-and-fix pass (#149-#158) on
  HBEC, during the manual `deploy-color` run that followed merging all 9
  into `master`.

## References
- `AGENTIC_HARNESS/alembic/versions/048_add_verified_pictures.py`
- `AGENTIC_HARNESS/alembic/versions/047_whiteboard_lesson_rating.py`
- `scripts/deploy/manual-deploy-color.sh` (the runbook script that caught
  this, by design, before it could reach live traffic)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Under 15 minutes (caught by deploy-color's health
check, diagnosed from container logs, fixed, verified, pushed)
