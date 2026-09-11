# Production's Student Backend Was Missing 22 Subjects From Its Own Curriculum Mirror

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Found mid-migration while replicating newly-added exam papers to production's
Student Backend: roughly half the papers failed with `Subject.DoesNotExist`.
Production's Student Backend had 168 subjects mirrored, while Admin had 190 —
a 22-subject gap that predates this session's work entirely, silently
blocking any content tied to those subjects from ever reaching students.

## Symptoms
```
apps.curriculum.models.Subject.DoesNotExist: subject id=01b95686-7b0f-4403-
aa65-ff2ee8c4b17b code=6042 - 5
```
Raised inside the stream consumer's `_handle_paper`, which then ACKs and
drops the message (no retry) — so affected papers simply never appeared for
students, with nothing surfacing the gap until something tried to reference
one of the missing subjects.

## Environment Details
- **Server/Host:** hbca-vps, production
- **Services Affected:** Student Backend (`apps/replication/stream_consumer.py`)
- **Related Components:** Admin `curriculum.Subject`, replication `StreamOutbox`
- **Time First Observed:** 2026-09-10, during a staging→production content
  migration (Track B), when newly-replicated ExamPapers referenced subjects
  Student Backend had never received

## Investigation Steps

### 1. Initial Diagnosis
After queuing 366 published ExamPapers for replication, Student Backend's
`Paper` count stalled at 183 (roughly half) despite the `StreamOutbox` fully
draining with zero `failed` rows — the messages were being consumed and
erroring, not stuck.

### 2. Root Cause Analysis
Worker logs showed repeated `Subject.DoesNotExist` for a small set of
distinct subject IDs. Comparing subject counts directly: Admin had 190
active subjects, Student Backend had only 168 — a real, pre-existing 22-row
gap in the mirror, unrelated to anything created this session (confirmed via
`created_at` on one affected subject: 2026-07-09, long before today).

### 3. Key Findings
- The existing `republish_canonical` management command (built specifically
  for "bootstrapping the student backend's mirror" and "healing UUID drift")
  was the correct, already-available fix — no custom code needed.
- After running it, Student Backend's subject count reached 192 (188 admin
  + the drift-tolerant consumer realigning a couple of ambiguous rows), and
  the paper backlog resumed draining, though the previously-ACKed failures
  needed a manual re-save (see Prevention) since the consumer doesn't retry
  automatically.

## Root Cause
An unknown historical gap in production's replication history left 22
subjects never mirrored to Student Backend. Cause not identified precisely
(no error trail from whenever it happened), but the effect was silent and
indefinite — nothing surfaces a missing subject until content references it.

## Solution

### Immediate Fix
Ran `python manage.py republish_canonical` on production's admin-backend,
re-triggering replication signals for every exam board/grade/subject/topic.
Backfilled all 22 missing subjects. Then manually re-saved the specific
ExamPaper rows whose replication had already been ACKed-and-dropped during
the gap (identified by diffing the expected published-paper ID set against
what actually landed in Student Backend's `Paper` table).

### Long-term Fix
None yet — the underlying cause of the original drift is unknown, so there's
no code change identified to prevent recurrence beyond the existing
`republish_canonical` escape hatch already being the right tool when it does.

## Prevention
- [ ] Consider a periodic (or pre-deploy) automated check comparing Admin's
      and Student Backend's canonical-entity counts, so a drift like this
      surfaces immediately instead of silently, only found by chance when
      new content happens to reference a missing subject
- [ ] Consider making the stream consumer retry failed messages a bounded
      number of times before dropping them, so a transient dependency gap
      (like this one) self-heals once the missing row arrives, instead of
      requiring a manual re-save

## Related Issues
- Found during the same Track B content migration as
  `2026-09-10-null-year-specimen-papers-never-replicate-to-student.md`

## References
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py`
- `ADMIN/adminBackend/apps/replication/management/commands/republish_canonical.py`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
