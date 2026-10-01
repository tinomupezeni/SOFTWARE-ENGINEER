# Subject Duplication/Orphaning: Prevention, Pipeline Fix, and Admin Visibility (DB Cleanup Deferred)

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Investigation + code fix (cross-service: Admin Backend, Student Backend, Admin Frontend)
**Status:** Code complete and tested. Deliberately not deployed and no production data touched — see Follow-ups.

## Context / Trigger
Follow-on from the same day's "Sociology not showing" production incident
(see `Backend_and_API/HBEC-2026-10-01-topic-paper-additions-never-busted-subjects-cache.md`
and `reports/HBEC-2026-10-01-full-catchup-production-promotion.md`). User
reported a second, different symptom for a specific tester account
(mutsa.myra07@gmail.com): subjects she'd selected showed no topics/questions.
Investigation found this was **not** the same bug — a real, separate root
cause — and the user gave explicit sequencing instructions before any fix
work started: fix the code first; give admin visibility into everything
actually live on the student side; strengthen the replication pipeline;
**do DB cleanup last, as a separate step.**

## Scope
**Included:** code-level prevention, pipeline fix, and a new admin-facing
reconciliation view — all with tests, verified locally.

**Explicitly excluded (per user instruction):** no production data was read,
written, or cleaned up as part of this work. The tester's account and the
live orphaned subject rows found during diagnosis remain untouched.

## Method
Root-caused by direct production DB inspection (not assumed): compared
Admin's `subjects`/`subject_families` tables against Student's
`curriculum_subject` for the same exam board, confirming Admin's data model
is correct as designed (one family per name, one subject row per
family+grade, both DB-enforced) and that the duplication students see is
entirely student-side drift. Traced the actual mechanism via source reading
rather than guessing: two parallel Explore investigations (FK `on_delete`
behavior + existing `DroppedStreamMessage` pattern; existing admin↔student
visibility pipeline) confirmed a precise two-bug chain before any code was
written, then a plan was written and approved (`EnterPlanMode`/`ExitPlanMode`)
before implementation.

## Decisions & Findings
- **Admin's data model was never the problem.** Verified directly: exactly
  one `SubjectFamily` per name per exam board (DB-enforced case-insensitive
  unique), exactly one `Subject` per `(family, grade)` (DB-enforced unique).
  6 "History" rows for ZIM-HBCA A-Level, one per grade, zero duplication.
- **Confirmed root cause — a two-bug chain, not a typo:**
  1. `ADMIN/adminBackend/.../merge_duplicate_subjects.py` moved child
     `Topic`/`Content` rows via bulk `.update()`, which Django never fires
     `post_save` for — Student Backend was never told those rows moved.
  2. `dup.delete()` correctly fired a `subject_deleted` event, but
     `STUDENT/.../stream_consumer.py`'s `_handle_subject_delete` then hit a
     `ProtectedError` (Student's `Topic.subject`/`Paper.subject` are
     `on_delete=PROTECT`, and per bug #1 still pointed at the subject being
     deleted) — caught, logged, and **silently returned**. Worse than a
     logged failure: `process_message` then returned `True`, acking the
     message as delivered. `_record_dropped()` (the existing
     `DroppedStreamMessage` mechanism, whose own docstring already describes
     this exact bug class) was never invoked. There was no record anywhere
     that this had happened. `_handle_exam_board_delete` had the identical bug.
  3. Confirmed live: the tester's orphaned "History" Upper-6 duplicate (code
     `6006 -5`, 9 topics/1 paper) has **no corresponding row in Admin's
     `subjects` table at all** — exactly this failure mode.
- **A full admin↔student reconciliation pipeline already existed** —
  `SyncInventoryView`/`student_client`/`StudentSyncStatusView`/
  `StudentSyncStatusSection.tsx` — just missing the reverse direction (it
  only ever diffed "admin has it, is student missing it," never "student has
  it, does admin know"). Extended it rather than building a new mechanism.
- **Comparing by code, not id, would have reintroduced a false-positive
  risk.** Admin legitimately reuses the same code across two grades (e.g.
  the same A-Level code published for Lower-6 and Upper-6). The new reverse
  diff compares by `id` (replicated rows share Admin's UUID as their PK)
  specifically to avoid this — tested directly (`test_same_code_reused_
  across_two_grades_does_not_false_positive`).
- A narrower, independent bug found in the same investigation: Admin's
  manual "Add Subject" form did zero `code` normalization, letting
  whitespace-variant codes (`"6006"` vs `"6006 -5"`) become distinct rows.

## Changes Made
- **Admin Backend**: `apps/curriculum/serializers.py` (`SubjectWriteSerializer.
  validate_code` strips whitespace); `apps/curriculum/management/commands/
  merge_duplicate_subjects.py` (bulk `.update()` → per-instance `.save()` for
  Topic/Content/cascade models, so the move actually replicates);
  `apps/replication/views.py` (`StudentSyncStatusView` gets a new
  `orphaned_on_student` reverse diff, compared by id).
- **Student Backend**: `apps/curriculum/views.py` (`TopicListView.get()` now
  catches `Subject.MultipleObjectsReturned` → 400, not an uncaught 500);
  `apps/replication/stream_consumer.py` (`_handle_subject_delete` and
  `_handle_exam_board_delete`: on `ProtectedError`, deactivate the row in its
  own committed transaction, then re-raise so the existing
  `DroppedStreamMessage`/`replay_dropped_messages` machinery picks it up —
  instead of silently swallowing); `apps/replication/views.py`
  (`SyncInventoryView` now returns `subjects_detail`: id/code/name/grade/
  level/is_active/topic_count/paper_count per subject).
- **Admin Frontend**: `features/system-settings/api/replicationApi.ts`
  (`OrphanedSubject` type, `orphaned_on_student` field);
  `features/system-settings/components/StudentSyncStatusSection.tsx` (new
  "Content Admin Can't See" stat card + table, same shape as the existing
  "Missing on Student"/"Dropped Stream Messages" sections — deliberately
  read-only, no delete action from this panel).

## Verification
- Admin Backend: 209 tests in `apps/curriculum/` + `apps/replication/` pass,
  including 3 new tests for the serializer normalization, merge-command
  signal-firing fix (asserting a real `StreamOutbox` row with the correct
  moved `subject_id`, not just DB state), and the reverse-diff view (3 cases:
  flagged, not-flagged, same-code-two-grades false-positive guard).
- Student Backend: 183 tests pass (1 unrelated pre-existing failure in
  `test_guest_cache_hardening.py`, confirmed via `git stash` to fail
  identically on unmodified `master` — not caused by this work), including 6
  new tests across subject/exam-board delete handling (deactivates instead
  of vanishing, reports failure instead of silent success, unblocked deletes
  still work normally) and the `TopicListView` ambiguous-code guard.
- Admin Frontend: `tsc -b --noEmit` clean; 2 new component tests pass.
- No production or staging environment was touched — this is local
  code+tests only, per the user's explicit sequencing instruction.

## Follow-ups / Deferred
- **Not deployed.** This needs to go through the normal staging→production
  promotion path before it takes effect anywhere.
- **DB cleanup deliberately deferred**, per explicit user instruction, to a
  separate follow-up step: once this ships, the new "Content Admin Can't
  See" panel will surface the tester's orphan (and any others) for review,
  then the already-existing `merge_legacy_subjects.py`/
  `fix_duplicate_subjects.py` commands can be run informed by that view.
- Not built: hardening `cd.yml`'s image-tagging (unrelated, flagged in a
  separate entry today) and a CI check for the `code` normalization — the
  serializer fix closes the immediate gap but a dedicated field-level test
  suite for near-duplicate detection was judged out of scope here.

## References
- `Backend_and_API/HBEC-2026-10-01-topic-paper-additions-never-busted-subjects-cache.md`
- `reports/HBEC-2026-10-01-full-catchup-production-promotion.md`
- Plan file: `/home/shadowe/.claude/plans/binary-wibbling-ladybug.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session
