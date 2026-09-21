# Staging student DB was missing 24 Subject rows admin already had

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
120 of 159 freshly seeded ZIMSEC exam papers failed to replicate from
admin to the student backend on staging with `Subject.DoesNotExist`. The
subjects those papers reference (bare syllabus codes like `4023`, `4001`,
`4003`...) existed in admin's `curriculum_subject` table but had never
reached the student backend's mirror of it — student only had the `-1`/
`-2`/`-3` paper-band suffixed variants (`4023-3`, `4001-1`, ...), not the
parent codes.

## Symptoms
```
Subject not found (id=5c4cd188-bc74-4385-bd74-43f56d9b8b7e, code=4023) for paper 5dd3852c-42ca-58cc-82fa-4f455210faee
apps.curriculum.models.Subject.DoesNotExist: subject id=5c4cd188-bc74-4385-bd74-43f56d9b8b7e code=4023
```
`Content stream consumption complete: 3 processed, 43 failed` (first
batch), then further batches, totalling 120 failures out of the 159 papers
the seed run had just created in admin.

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142)
- **Services Affected:** Student Backend replication consumer
  (`apps/replication/stream_consumer.py`), Admin curriculum (`apps.curriculum.Subject`)
- **Related Components:** `DroppedStreamMessage` (already existed for
  exactly this failure mode — see the prior `dropped stream message` fix
  documented elsewhere in this repo), `republish_canonical` management command

## Investigation Steps

### 1. Initial Diagnosis
The consumer's own `_handle_paper` already tries the subject by UUID, then
falls back to `Subject.objects.filter(code=subject_code)` — both failed, so
this wasn't a UUID-drift case, it was a genuinely absent row.

### 2. Root Cause Analysis
```bash
# admin staging
docker exec hbec-admin-backend-staging python manage.py shell -c \
  "from apps.curriculum.models import Subject; print(Subject.objects.count())"
# -> 171

# student staging
docker exec hbec-student-backend-staging python manage.py shell -c \
  "from apps.curriculum.models import Subject; print(Subject.objects.count())"
# -> 211  (more rows overall, but missing specific ones — see below)

# admin subject codes (sample)
['0887', '4001', '4001-1', '4001-2', '4001-3', '4002', '4002-1', ...]
# student subject codes (sample)
['0887', '4001-1', '4001-2', '4001-3', '4002-1', '4002-2', '4002-3', ...]
# -> student has every suffixed variant but not the bare "4001" parent code
```

### 3. Key Findings
- Not a code-scheme mismatch (unlike the seed board-code bug filed
  separately) — both sides use the same convention. Student was simply
  missing a subset of admin's rows: the bare-code entries never triggered a
  `subject_published` event that reached student, while the suffixed
  variants had.
- `republish_canonical --entities subject` (an existing, purpose-built
  command — its own docstring says it exists for exactly this: "Healing
  UUID drift between admin and student") re-saved all 171 admin `Subject`
  rows, which re-fired the replication signal for the previously-missing
  ones. Student's count went from 211 to 235 (171 admin subjects matched or
  created, plus whatever pre-existing student-only rows remain).
- Running `republish_canonical` crashed with `psycopg.errors.InvalidCursorName`
  on cleanup, but **after** every row had already been individually saved —
  filed and fixed separately: see
  `Backend_and_API/HBEC-2026-09-21-republish-canonical-pgbouncer-cursor-crash.md`.
- After the resync, `student_backend.manage.py replay_dropped_messages`
  cleared all 121 (then 8 more from a second republish wave) previously
  dropped `paper_published` messages with 0 remaining failures. Final
  student-side paper count: 744.

## Root Cause
Some admin `Subject` rows (the bare, un-suffixed syllabus codes) were
created without ever successfully publishing a `subject_published` event
that student's stream consumer processed — whether that was a one-time
gap when those specific rows were created, a consumer outage at the time,
or something else wasn't pinned down; the resync via `republish_canonical`
closes the symptom regardless of which.

## Prevention / Rule
**Guardrail:** A periodic (e.g. nightly, staging + production) reconciliation
job that compares `Subject.code` sets between admin and student and pages
or logs a warning on any admin code missing from student — turning "44 exam
papers silently unreplicated" into a same-day alert instead of something
only surfaces once a seed run happens to touch the gap.

## Solution

### Immediate Fix
```bash
docker exec hbec-admin-backend-staging python manage.py republish_canonical --entities subject
docker exec hbec-admin-backend-staging python manage.py shell -c \
  "from apps.replication.tasks import poll_stream_outbox; poll_stream_outbox()"
# wait for student's Celery Beat stream consumer (~10s poll interval)
docker exec hbec-student-backend-staging python manage.py replay_dropped_messages
```

### Long-term Fix
Add the reconciliation check described above. Consider whether
`republish_canonical` (all four entity types) should run automatically as
part of every staging/production deploy, since it's cheap, idempotent, and
exactly this drift-healing tool.

## Prevention
- [x] Resync staging via `republish_canonical --entities subject`
- [x] Replay all dropped `paper_published` messages
- [ ] Add admin/student Subject-code reconciliation check
- [ ] Decide whether to run `republish_canonical` automatically on deploy

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-seed-exam-board-code-mismatch.md` — the
  seeding work that surfaced this
- `Backend_and_API/HBEC-2026-09-21-republish-canonical-pgbouncer-cursor-crash.md`
  — the tool used to fix this, itself had a bug fixed in the same session

## References
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py`
- `ADMIN/adminBackend/apps/replication/management/commands/republish_canonical.py`

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~20 minutes from discovery to fully replayed
