# New Topics/Papers On An Existing Subject Never Invalidated The Cached Subjects List

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
A student-reported production incident ("admin added Sociology topics and
papers yesterday but they aren't showing up on student side") traced to a
cache-invalidation gap, not a replication failure: the student subjects-list
endpoint caches `paperCount`/`topicCount` per subject, and the stream
consumer that applies admin-side topic/paper creates never bumped that
cache's version key. A subject already visible to students kept reporting
its pre-existing counts for up to the cache's full TTL after new content was
added to it.

## Symptoms
- Admin added new topics and papers to the Sociology subject; students
  reported the new content "shared nothing," as if nothing had been added.
- No errors anywhere — replication succeeded, the rows existed correctly in
  the student database, and the admin side showed no failure.

## Environment Details
- **Server/Host:** Production VPS (`/opt/hbec`)
- **Services Affected:** Student Backend (`apps/curriculum/views.py`,
  `apps/replication/stream_consumer.py`), consumed via Redis-cached subjects
  list
- **Related Components:** `apps/curriculum/cache_utils.py`
  (`get_curriculum_version`/`bump_curriculum_version`), `SubjectSerializer`
- **Time First Observed:** Reported 2026-10-01, content added 2026-09-30

## Investigation Steps

### 1. Initial Diagnosis
Suspected replication first, given the service map's one-way
admin→student sync. Compared topic/paper row IDs directly between admin and
student databases for the reported subject.

### 2. Root Cause Analysis
Direct ID-level comparison proved the rows existed correctly on the student
side — replication was not the problem. Read the subjects-list view
(`apps/curriculum/views.py`) and found it cached on a versioned key:
`curriculum:subjects:profile:v{version}:{level}:{exam_board_id}:{grade}`,
`version = get_curriculum_version("subjects")`, TTL
`CURRICULUM_CACHE_TTL_SECONDS` (1h, 6h in Exam Mode). Read
`apps/replication/stream_consumer.py` and found the subject create/update/
delete handlers call `bump_curriculum_version("subjects")`, but the topic
and paper handlers (`_handle_topic`, `_handle_paper`) do not — `_handle_paper`
has no bump call at all.

### 3. Key Findings
- Cache versioning exists and works correctly for subject-level changes.
- Topic/paper additions to an *existing* subject are invisible to that
  version key, so the cached list entry is never invalidated by them.
- The fix for this exact gap (`afab7930`) was already written and merged to
  `master`/staging but had never reached production — production was 14
  commits behind at the time of the report.

```bash
# ID-level comparison that ruled out replication
docker exec hbec-postgres psql -U hbec -d hbec_student -c "
SELECT s.name, s.id, COUNT(t.id) AS topic_count
FROM curriculum_subject s LEFT JOIN curriculum_topic t ON t.subject_id = s.id
WHERE s.name ILIKE '%sociology%' GROUP BY s.id;"
```

## Root Cause
`stream_consumer.py`'s topic and paper event handlers never called
`bump_curriculum_version("subjects")`, so adding content to an existing
subject left the subjects-list cache entry — which embeds
`paperCount`/`topicCount` — serving stale counts until its TTL expired
naturally, with nothing that signaled the staleness to anyone.

## Prevention / Rule
**Guardrail:** Every stream-consumer handler that creates or updates a model
read by a cached list endpoint must bump that cache's version key in the
same code path as the handler that already does so for the parent model —
enforced going forward by `afab7930`'s fix adding the missing
`bump_curriculum_version` calls to `_handle_topic` and `_handle_paper`, and
by treating "which cache does this event affect" as a required question in
review for any new stream-consumer handler, not an afterthought.

This closes the specific gap because the versioning mechanism itself was
already correct — the bug was an incomplete set of callers, not a flawed
design, so the fix is completing that set rather than changing the pattern.

## Solution

### Immediate Fix
None needed beyond the already-written `afab7930` reaching production — see
the companion promotion report
(`reports/HBEC-2026-10-01-full-catchup-production-promotion.md`) for the
full promotion. No stale cache entries were found on production at
verification time (the TTL window had already elapsed since the reported
content addition), and real topic/paper counts were confirmed directly
against the database.

### Long-term Fix
`afab7930` (already in `master`, now in production) adds the missing
`bump_curriculum_version("subjects")` calls to the topic and paper stream
handlers.

## Prevention
- [x] Code changes required — done in `afab7930`, promoted to production
      2026-10-01.
- [ ] Consider a lint/review checklist note for `stream_consumer.py`: every
      new handler must state which cache namespaces it invalidates.
- [ ] Monitoring/alerts to add: none added — this class of staleness has no
      error signature, so alerting would need a freshness probe, not an
      error-rate one; flagged as a possible follow-up, not built.

## Related Issues
- Promotion that shipped this fix to production:
  `reports/HBEC-2026-10-01-full-catchup-production-promotion.md`

## References
- `STUDENT/hbec_backend/apps/curriculum/views.py`
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py`
- `STUDENT/hbec_backend/apps/curriculum/cache_utils.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Diagnosed and promoted same day (2026-10-01); fix had existed unmerged-to-production since an earlier session.
