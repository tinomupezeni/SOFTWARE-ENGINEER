# Staging's `admin-backend`/`admin-worker`/`admin-beat` Ran Stale Code Against an Already-Migrated `Subject` Schema — Every Paper Extraction Crash-Looped

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging
**Severity:** Critical
**Status:** Fixed, deployed to staging

## Summary
Earlier this session (before this window), `Subject` was restructured to
split identity (`name`/`description`, now on a new `SubjectFamily` model)
from per-grade offering — migration `0011_subject_family_required`
(`RemoveField` on `Subject.name`/`.description`/`.name_sn`/`.name_nd`) was
applied to staging's database. But the running `admin-backend`,
`admin-worker`, and `admin-beat` containers (all three built from the same
`hbec-admin-backend` image) were never rebuilt/redeployed with the
matching code afterward — they kept serving a `Subject` Django model that
still declared `name`/`description` as real fields.

Found while testing the newly-added "Upload Paper" admin UI (this
session's other fix,
`2026-09-11-new-paper-upload-fully-built-but-unreachable-in-admin-ui.md`):
the user uploaded a real paper and it sat at `status=draft`,
`questions_count=0` forever, with no visible error in the UI (just "No
questions found. Extract questions from the paper first.").

## Symptoms
- Paper created successfully (file stored, metadata correct).
- `Questions: 0/0`, status stuck at `draft`.
- No error surfaced to the admin UI at all — the ingestion pipeline is
  fire-and-forget from the create view's perspective.

## Investigation Steps
1. Queried the admin backend for the paper directly — `metadata={}`,
   `questions_count=0`, file present. No trace of a completed or failed
   extraction attempt recorded on the model itself.
2. Checked `admin-backend` logs around upload time: found
   `"Ingestion pipeline dispatched for paper <id>"` — confirms
   `launch_ingestion_pipeline` (called from every paper-creation path, see
   `apps/exam_papers/tasks.py`) fired correctly.
3. Checked `admin-worker` (Celery) logs for the same window: found the
   real error, retried three times with exponential backoff (60s, 120s,
   ...) before presumably exhausting retries silently:
   ```
   django.db.utils.ProgrammingError: column subjects.name does not exist
   LINE 1: ...subjects"."exam_board_id", "subjects"."grade_id", "subjects"...
   ```
   Raised from `apps/exam_papers/tasks.py:48`,
   `paper.subject.grade_levels` — a lazy FK fetch on `Subject`, which
   Django generates a `SELECT` for using every field the *model class*
   declares, not what the database actually has.
4. Confirmed the DB-side migration state: `showmigrations curriculum`
   showed `0011_subject_family_required` applied — the columns really are
   gone from the table.
5. Confirmed the code/DB mismatch directly by asking the *running*
   `admin-worker` container what its own `Subject` model class looked
   like:
   ```python
   from apps.curriculum.models import Subject
   sorted(f.name for f in Subject._meta.get_fields())
   # -> includes 'name', 'description', 'name_sn', 'name_nd' — the OLD shape
   ```
   while the checked-out git repo (`master`, current HEAD) already has the
   correct property-based `Subject.name`/`.description` (delegating to
   `self.family`), confirming the running containers were simply behind,
   not that the code itself was wrong.

## Root Cause
The `SubjectFamily` restructuring's migration and its application code
change should always ship together (the plan for this work explicitly
scoped migration 0011 as the same deploy as the ORM call-site fixes for
exactly this reason). At some point staging's database picked up
migration 0011 (most likely via the automatic `migrate --noinput` on
*some* container's entrypoint, at a point when other services were being
rebuilt/redeployed individually during this session's piecemeal staging
deploys), but `admin-backend`/`admin-worker`/`admin-beat` themselves were
never rebuilt and redeployed in that same pass — so the database moved
forward while three of the services consuming it did not. Because the
ingestion pipeline runs asynchronously via Celery with no user-visible
error surface, this was invisible until someone actually tried to extract
a paper.

## Prevention / Rule
**Guardrail:** A pre-flight deploy check that compares every running
container's build/git-sha label against the migration state of the
database it connects to, and refuses to consider a deploy complete if any
service sharing that database is still running code from before the
migration's introducing commit.

This directly closes the gap: a piecemeal deploy that migrates the schema
without rebuilding every consumer of that schema would fail the check
immediately instead of surfacing as a silent Celery retry-loop nobody sees
until a user notices a stuck draft.

## Solution

### Immediate Fix
Rebuilt and redeployed `admin-backend`, `admin-worker`, `admin-beat`
(`docker compose -f docker-compose.staging.yml build admin-backend` then
`up -d --no-deps admin-backend admin-worker admin-beat`) — confirmed via
the same live model-introspection check that the new containers' `Subject`
model matches the current code (`name`/`description` gone, `family`
present).

The user's original paper had already exhausted whatever retries Celery
gives `extract_questions_via_harness` and was stuck at `draft`. Manually
re-dispatched `extract_questions_via_harness.delay(paper_id)`, which
succeeded (70 questions extracted), then `finalise_paper_ingestion.delay(paper_id)`
(idempotent by design, safe to call directly) to complete the
publish-both-sides step. Confirmed the paper reached the student backend
via a live sync (`practice.Paper` row created with 14 top-level questions,
matching the fixed PR #42 structure).

### Long-term Fix
Not implemented here — flagged for follow-up: this class of bug (DB
migration lands, but not every image consuming that schema gets
redeployed in the same pass) is a deploy-process gap, not a code bug.
Worth considering either (a) a pre-flight check in CI/CD that fails a
deploy if any service sharing a database is more than N commits behind
the migration state, or (b) simply being stricter this session about
always rebuilding every service that shares a model with whatever was
just migrated, not just the service that was the direct target of the
current task.

## Prevention
- [ ] Monitoring/alerts to add — Celery task failure rate / retry-loop
      detection would have caught this within a minute of the first
      attempt, rather than requiring a user to notice a stuck draft
- [ ] Documentation to update — note in `CLAUDE.md` or the deploy runbook
      that a schema-changing migration and every service reading that
      model must be redeployed together, even if only one service was the
      original target of the change
- [ ] Code changes required — none; this was a deploy-state gap, not a
      code defect

## Related Issues
- Same underlying restructuring as
  `2026-09-11-new-paper-upload-fully-built-but-unreachable-in-admin-ui.md`
  (found immediately after fixing that gap, while actually testing the
  newly-reachable upload flow) and the original
  `SubjectFamily`/`Subject` split work from earlier this session
  (`30f19a69`, `ab04c5e8`, `949d1308`).

## References
- `ADMIN/adminBackend/apps/curriculum/migrations/0011_subject_family_required.py`
  (drops `name`/`description`/`name_sn`/`name_nd`)
- `ADMIN/adminBackend/apps/curriculum/models.py` (current, correct
  property-based `Subject.name`/`.description`)
- `ADMIN/adminBackend/apps/exam_papers/tasks.py:48`
  (`extract_questions_via_harness`, where the crash surfaced),
  `:471` (`launch_ingestion_pipeline`), `:373` (`finalise_paper_ingestion`)
- `docker-compose.staging.yml` — `admin-backend`/`admin-worker`/
  `admin-beat` all share `hbec-admin-backend:${TAG:-latest}`

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery, ~10 minutes from
symptom report to confirmed fix on staging
