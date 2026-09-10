# Deleting or Unpublishing an ExamPaper in Admin Never Removes It From Harness or Student Backend

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Development (found during a systematic replication audit, investor-demo prep)
**Severity:** High
**Status:** Investigating

## Summary
`curriculum.Content` already has a deliberate retraction path
(`_handle_content_retraction` / `_emit_content_retraction` in
`ADMIN/adminBackend/apps/replication/signals.py`) precisely because an
earlier bug let an archived syllabus keep being served everywhere downstream.
`exam_papers.ExamPaper` — a structurally identical "admin is the source of
truth, replicates to both Harness and Student" content type — never got the
same fix. Deleting a published exam paper in admin, or moving its status
back off `published`, leaves the Harness's `Paper`/`Question`/`MarkingPoint`
rows and the Student Backend's `practice.Paper`/`PaperQuestion` rows in place
forever: still gradeable, still shown to students, still grounding AI
question generation, with no trace of it left in admin.

## Symptoms
No error. An editor deleting or unpublishing a paper in the admin UI sees it
disappear from admin's own list — with no signal that a live, gradable copy
of it is still being served to students on both other services.

## Environment Details
- **Server/Host:** N/A — found by static analysis
- **Services Affected:** `ADMIN/adminBackend/apps.exam_papers`,
  `AGENTIC_HARNESS/app.admin` (replication receiver),
  `STUDENT/hbec_backend/apps.practice`
- **Related Components:** `apps.replication.signals`,
  `apps.replication.stream_consumer` (student), `app/admin/replication_handlers.py`
  (harness)
- **Time First Observed:** 2026-09-10, systematic replication audit

## Investigation Steps

### 1. Initial Diagnosis
Enumerated every admin-side signal receiver (`grep -rn "@receiver(" apps/`).
`exam_papers.ExamPaper` has exactly one:
`on_exam_paper_save` (`ADMIN/adminBackend/apps/replication/signals.py:513`),
`post_save` only — **no `post_delete` receiver exists for this model at
all**, unlike `curriculum.Content`, which has both `post_delete`
(`on_content_delete`, line 381) and a `pre_save`/`post_save` pair that tracks
status transitions specifically to catch "was published, now isn't" (lines
392-424).

### 2. Root Cause Analysis
Confirmed both directions this can be triggered in admin, and that neither
retracts anything:
- **Delete:** `ExamPaperDetailView` (`ADMIN/adminBackend/apps/exam_papers/views.py:179`)
  is a plain `generics.RetrieveUpdateDestroyAPIView` — `destroy()` is not
  overridden, so a `DELETE /papers/{id}/` does a normal `instance.delete()`.
  Django fires `post_delete` regardless; there is simply no receiver
  listening for it on this sender.
- **Unpublish:** `ExamPaperStatusView.post()`
  (`ADMIN/adminBackend/apps/exam_papers/views.py:216-240`) sets
  `paper.status = new_status` and saves — which still fires
  `on_exam_paper_save` via `post_save`, but that handler's very first line is
  `if instance.status != "published": return`
  (`ADMIN/adminBackend/apps/replication/signals.py:515-516`), an unconditional
  early exit with no retraction branch of any kind. `_publish_paper()` in the
  same view (line 242) only handles the forward direction (`if new_status ==
  PUBLISHED and old_status != PUBLISHED`) — there is no counterpart for the
  reverse transition anywhere in this class.
- Checked both receivers for a rescue path: the harness's
  `receive_replication` only special-cases retraction for `content.*` events
  (`_RETRACTION_EVENTS` in `AGENTIC_HARNESS/app/admin/replication_handlers.py:59`);
  `paper.*` events always go to `handle_paper_replication`, which only
  upserts — it has no branch for a deletion event type at all. The student
  stream consumer's only paper-removal path is `paper_deleted`
  (`STUDENT/hbec_backend/apps/replication/stream_consumer.py:906-920`,
  `_handle_paper_delete`), which is written *only* from
  `_emit_content_retraction` for `curriculum.Content` rows in
  `_STUDENT_EXAM_TYPES` — never from anything tied to `exam_papers.ExamPaper`.
  So there is no code path, on either receiving side, that would ever remove
  an `ExamPaper`-sourced row once created.

### 3. Key Findings
- `curriculum.Content` and `exam_papers.ExamPaper` are both "admin publishes,
  Harness + Student both keep durable copies" content types, and only one of
  them has ever had its retraction path built.
- The gap is symmetric: neither the admin-side signal nor either downstream
  receiver has any deletion/retraction handling for this content type.
- This matches the exact failure mode `_handle_content_retraction`'s own
  docstring describes fixing for `Content` ("the harness kept its copy... the
  tutor went on quoting a document the admin had removed") — just never
  ported to `ExamPaper`.

## Root Cause
The `Content` retraction fix (delete/archive → notify both downstream
services, remove vectors, cascade derived rows) was scoped to `Content` only.
`ExamPaper` was not audited at the same time despite sharing the same
dual-replication shape, so it never got a `post_delete` receiver or an
unpublish branch.

## Solution

### Immediate Fix
None applied — read-only audit, no code changed.

### Long-term Fix
Needs, mirroring the `Content` pattern:
1. A `post_delete` receiver on `exam_papers.ExamPaper` that emits a
   `paper.deleted`-shaped event to both the harness (so
   `handle_paper_replication` — or a new retraction branch — removes the
   `Paper`/`Question`/`MarkingPoint` rows and, per the `Content` precedent,
   any Qdrant vectors) and a `paper_deleted` `StreamOutbox` row for the
   student backend (already-existing consumer handler, just never fed for
   this sender).
2. An unpublish branch in `on_exam_paper_save` (or a dedicated status-change
   receiver) that fires the same retraction when a paper transitions off
   `published`, mirroring `_handle_content_retraction`'s
   previous-status-tracking approach (`remember_content_status`).
3. A retraction branch added to `handle_paper_replication` on the harness
   side (currently upsert-only) and confirmation that the student stream
   consumer's existing `_handle_paper_delete` is reachable from this new
   event.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — an alert on "ExamPaper deleted in admin but
      still present in Harness/Student `Paper` tables N minutes later" would
      have caught this without needing a manual audit
- [ ] Documentation to update — note in `CLAUDE.md`'s marking-engine section
      that `ExamPaper` retraction is unimplemented, so it isn't assumed to
      work like `Content`'s
- [ ] Code changes required — scoped above, deferred; not exercised in
      production today only because no admin UI action currently triggers a
      real unpublish-after-publish or delete-after-publish in practice, but
      the endpoints exist and are reachable

## Related Issues
- Same systematic audit that (re-)confirmed
  `2026-09-10-project-guide-no-templates-broken-admin-to-student-replication.md`
  and found
  `2026-09-10-learning-guide-authored-content-never-consumed-anywhere.md`.
  This is the third distinct gap the same audit surfaced, but a different
  shape from the other two: those are "never wired in the first place," this
  one is "the forward path works, the fix for the identical problem on a
  sibling content type was never ported over."

## References
- `ADMIN/adminBackend/apps/replication/signals.py:381-424` (`Content`'s
  working retraction pattern, for comparison)
- `ADMIN/adminBackend/apps/replication/signals.py:513-517`
  (`on_exam_paper_save`, no retraction branch, no `post_delete` sibling)
- `ADMIN/adminBackend/apps/exam_papers/views.py:179` (`ExamPaperDetailView`,
  unguarded `DELETE`)
- `ADMIN/adminBackend/apps/exam_papers/views.py:211-240`
  (`ExamPaperStatusView`, publish-only handling)
- `AGENTIC_HARNESS/app/admin/replication_handlers.py:59` (`_RETRACTION_EVENTS`,
  scoped to `content.*` only), `:436` (`handle_paper_replication`, upsert-only)
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py:906-920`
  (`_handle_paper_delete`, real but never fed for this sender)

---

**Resolved By:** Claude (Sonnet 5), read-only audit — not yet fixed
**Time to Resolution:** N/A (identified only)
