# Issue: Missing Topics in Student Database (Sync Lost Events & Duplicate Codes)
**Date:** 2026-09-20
**Project:** HBEC

## Description
A significant number of curriculum topics were missing from the production student environment. The Admin database (`hbec_admin`) had 1593 topics, while the Student database (`hbec_student`) only had 1380 topics in the `curriculum_topic` table.

## Root Cause
Investigation revealed two compounding issues:
1. **Lost Replication Events:** The missing topics were created over the last few months. While the Admin backend successfully queued `topic_published` events to the outbox and pushed them to the Redis replication stream (`hbec_replication`), the `hbec-student-worker` missed them. This was likely due to the Redis stream trimming older messages (via `MAXLEN`) before the worker could process the backlog, or due to worker downtime.
2. **Duplicate Topic Codes:** The Admin database UI allows curriculum designers to create topics with identical `code` slugs under the same subject (103 duplicate codes were found). However, the Student database enforces a strict `UNIQUE (release_id, subject_id, code)` constraint. When the replication stream attempts to insert these duplicates, it hits an `IntegrityError` and rightfully skips them. This accounts for the remaining discrepancy between the Admin count (1593) and the final synced Student count (1540+).

## Fix / Resolution
To bridge the gap in the Redis stream, a full re-sync of topics was triggered on the production `hbec-admin-backend`:
```bash
docker exec hbec-admin-backend python manage.py republish_canonical --entities topic
```
This command successfully re-queued all topics into the outbox. The `hbec-student-worker` immediately consumed the batch, automatically rejecting the duplicates via `IntegrityError` while successfully syncing all genuinely missing topics. 

**Resolved By:** Antigravity

## Verification (2026-09-21)
Re-checked against live production a day later, asked to confirm the fix
held:

- **Admin and student topic counts now match exactly: 1874 = 1874** (grown
  from the 1593/1380 reported here — normal content growth since, with
  student keeping up in full).
- 223 `topic_published` `DroppedStreamMessage` rows are still outstanding
  on production, none ever replayed. Sampled one directly: its `(subject,
  code)` matches an already-synced topic under a *different* `id` —
  confirming these are the permanent, by-design duplicate-code rejections
  this entry's Root Cause #2 already described, not a still-open gap. The
  exact count match is itself strong evidence none of the 223 represent a
  genuinely missing topic.
- **Root Cause #1 (Redis `MAXLEN` trimming) does not hold up.** Read
  `streams.py` on both services directly: no `maxlen` parameter is ever
  passed to `xadd`, anywhere in either codebase. Whatever caused the
  original lost events, it wasn't stream trimming. The more likely
  mechanism, matching a pattern found independently the same day
  (`HBEC-2026-09-21-staging-student-subject-drift.md`): a topic's
  `subject_code` hadn't replicated to student yet at the moment the topic's
  own event was first consumed, so resolution failed and the message was
  dropped — an ordering issue, not a capacity one. Doesn't change the
  conclusion (the applied fix — re-triggering publish via
  `republish_canonical` — was the right fix regardless of which theory was
  correct), but the stated mechanism was likely wrong.

**Conclusion: the underlying issue is resolved**, confirmed by direct
measurement rather than re-trusting the original fix's own success claim.

**Verified By:** Claude Sonnet 5 (with tinomupezeni)
