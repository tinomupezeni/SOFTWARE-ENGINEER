# Specimen Papers With No Year Can Never Replicate to Student Backend — NOT NULL Mismatch

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Staging + Production
**Severity:** Medium
**Status:** Investigating

## Summary
Found while verifying a staging-to-production content migration. Admin's
`ExamPaper.year` is nullable and legitimately `None` for specimen papers
(they aren't tied to a real exam sitting). Student Backend's mirror,
`practice.Paper.year`, is `NOT NULL`. Any specimen paper with no year fails
replication permanently — the stream consumer's `Paper.objects.update_or_create`
raises `IntegrityError` and the event is ACKed and dropped (per the
consumer's "always ACKs, no retry" design), so the paper never becomes
visible to students on any environment, silently.

## Symptoms
```
django.db.utils.IntegrityError: null value in column "year" of relation
"practice_paper" violates not-null constraint
DETAIL: Failing row contains (..., "Indigenous Language (Ndebele) Grade 7
Specimen Paper 1", null, specimen, 1, 40, published, ...).
```
No user-facing error — the paper just never appears for students, with
nothing in admin indicating why.

## Environment Details
- **Server/Host:** hbca-vps (confirmed on both staging and production)
- **Services Affected:** Student Backend (`apps/replication/stream_consumer.py`, `_handle_paper`)
- **Related Components:** Admin `ExamPaper.year` (nullable), Student `practice.Paper.year` (not null)
- **Time First Observed:** 2026-09-10, surfaced while draining a backlog of
  StreamOutbox messages that had been stuck behind an unrelated missing-subject
  issue (see companion entry) — this bug predates that work and is unrelated
  to it.

## Investigation Steps

### 1. Initial Diagnosis
After fixing a separate subject-replication gap and re-triggering a batch of
paper replications, 3 of 366 papers still failed with an `IntegrityError`
instead of the earlier `Subject.DoesNotExist`.

### 2. Root Cause Analysis
Checked the 3 failing papers directly on admin: all three are
`type=specimen`, `status=published`, `year=None`. Confirmed
`practice.Paper.year` has no `null=True` on the Student Backend model,
so any insert with a null year is rejected at the database level, inside
the consumer's per-message try/except, which then ACKs and drops the
message per its documented "always ACKs, no retry" behavior.

### 3. Key Findings
- Confirmed this is **not** introduced by today's migration: the same 3
  paper IDs are also absent from staging's own Student Backend, which has
  never received them either, since staging first created them.
- This means **any** specimen paper ever created without a year is silently
  invisible to students, indefinitely, on every environment — a systemic
  gap, not a one-off.

## Root Cause
Schema mismatch: Admin's `ExamPaper.year` correctly models "may not have a
year" (specimen papers), but Student Backend's mirrored `Paper.year` doesn't
allow that, and the replication consumer has no handling for the mismatch
beyond letting the insert fail and dropping the event.

## Solution

### Immediate Fix
None applied this session — only 3 papers affected, left as-is pending a
decision on the right fix (see options below), documented here so the
next time someone add specimen papers without a year, this file explains why
they never showed up on the student side.

### Long-term Fix
Two reasonable options, worth a real decision rather than a guess:
1. Make `practice.Paper.year` nullable to match `ExamPaper.year`'s real
   semantics (the more correct fix — a specimen paper genuinely has no year).
2. Have the stream consumer default a missing year to something sensible
   (e.g. current year, or `0` with UI handling) if the schema can't change.

## Prevention
- [ ] Decide and implement one of the two fixes above
- [ ] Consider surfacing consumer-side drop events (ACKed failures) somewhere
      visible to admins, since right now a permanently-dropped message leaves
      no trace beyond a log line — this bug was only found by chance while
      verifying an unrelated migration

## Related Issues
- Found in the same session as
  `2026-09-10-staging-and-production-share-the-latest-image-tag.md` and the
  Track B staging→production content migration this entry's investigation
  was part of verifying

## References
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py` (`_handle_paper`)
- `STUDENT/hbec_backend/apps/practice/models.py` (`Paper.year`)
- `ADMIN/adminBackend/apps/exam_papers/models.py` (`ExamPaper.year`)

---

**Resolved By:** Not yet — documented, decision pending
**Time to Resolution:** N/A
